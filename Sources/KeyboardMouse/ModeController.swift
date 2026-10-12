import Foundation
import AppKit
import CoreGraphics
import QuartzCore

/// Диспетчер режима управления курсором: event tap, интерпретация клавиш,
/// тиковый таймер движения/прокрутки.
final class ModeController {
    private(set) var isOn = false
    private(set) var isRunning = false

    /// Уведомление об изменении состояния режима.
    var onModeChange: ((Bool) -> Void)?

    private var settings: StoredSettings
    private let mouse = MouseActions()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tickTimer: DispatchSourceTimer?

    // Состояние удержания клавиш.
    private var heldDirs: Set<Direction> = []
    private var dirStarted: [Direction: Double] = [:]
    private var scrollDirs: Set<Direction> = []
    private var scrollStarted: Double = 0
    private var currentFlags: CGEventFlags = []
    private var dragging = false
    /// Живые (зажатые) клавиши режима — фильтр автоповтора.
    private var heldKeys: Set<Int> = []
    /// Поглощённые keyDown, чьи keyUp тоже нужно проглотить (даже после выхода из режима).
    private var swallowKeys: Set<Int> = []

    init(settings: StoredSettings) {
        self.settings = settings
    }

    /// Обновить настройки из хранилища.
    func updateSettings(_ newSettings: StoredSettings) {
        settings = newSettings
    }

    /// Запустить перехват событий (после выдачи разрешения Accessibility).
    /// Возвращает false, если разрешение ещё не выдано или tap не создался.
    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard AXIsProcessTrusted() else { return false }
        guard installTap() else { return false }
        startTimer()
        isRunning = true
        return true
    }

    func stop() {
        setMode(false)
        uninstallTap()
        tickTimer?.cancel()
        tickTimer = nil
        isRunning = false
    }

    /// Переключить режим из меню (аккуратнее с фокусом — без overlay-анимации лагов нет).
    func toggleFromMenu() {
        guard isRunning else { return }
        setMode(!isOn)
    }

    private func setMode(_ on: Bool) {
        guard isOn != on else { return }
        isOn = on
        releaseAllHoldings()
        onModeChange?(on)
    }

    /// Сбросить удержания: остановить движение, отпустить drag, забыть зажатые клавиши.
    private func releaseAllHoldings() {
        if dragging {
            mouse.dragEnd()
            dragging = false
        }
        heldDirs.removeAll()
        dirStarted.removeAll()
        heldKeys.removeAll()
        scrollDirs.removeAll()
        // swallowKeys НЕ очищаем: keyUp зажатой до выхода клавиши должен быть проглочен.
    }

    // MARK: - Тиковый таймер (60 Гц)

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(8))
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        tickTimer = timer
    }

    private func tick() {
        guard isOn else { return }
        let now = CACurrentMediaTime()
        let fast = settings.fastModifierActive(currentFlags)

        if !heldDirs.isEmpty {
            var dx = 0.0
            var dy = 0.0
            for dir in heldDirs {
                let held = now - (dirStarted[dir] ?? now)
                let speed = settings.movementSpeed(held: held, fast: fast)
                switch dir {
                case .left: dx -= speed
                case .right: dx += speed
                case .up: dy -= speed
                case .down: dy += speed
                }
            }
            if dx != 0 || dy != 0 {
                mouse.moveBy(dx: dx, dy: dy, dragging: dragging)
            }
        }

        if !scrollDirs.isEmpty {
            let held = now - scrollStarted
            var delta = settings.scrollSpeed(held: held)
            if invertScrollGiven() { delta = -delta }
            // Вниз — отрицательная ось колеса, вверх — положительная.
            if scrollDirs.contains(.down) { delta = -delta }
            if scrollDirs.contains(.up) && scrollDirs.contains(.down) {
                // Обе клавиши — нейтрализация.
            } else {
                mouse.scroll(pixels: delta)
            }
        }
    }

    private func invertScrollGiven() -> Bool {
        settings.invertScroll
    }

    // MARK: - Установка event tap

    private func installTap() -> Bool {
        let mask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<ModeController>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            switch type {
            case .tapDisabledByTimeout, .tapDisabledByUserInput:
                if let tap = controller.tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            case .flagsChanged:
                controller.currentFlags = flags
                return Unmanaged.passUnretained(event)
            case .keyDown:
                return controller.handleKeyDown(keyCode: keyCode, flags: flags)
                    ? nil
                    : Unmanaged.passUnretained(event)
            case .keyUp:
                return controller.handleKeyUp(keyCode: keyCode)
                    ? nil
                    : Unmanaged.passUnretained(event)
            default:
                return Unmanaged.passUnretained(event)
            }
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("KeyboardMouse: не удалось создать event tap")
            return false
        }

        tap = newTap
        runLoopSource = CFMachPortCreateRunLoopSource(nil, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        return true
    }

    private func uninstallTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    // MARK: - Обработка клавиш (вызываются из колбэка тапа)

    /// true — событие поглощено.
    private func handleKeyDown(keyCode: Int, flags: CGEventFlags) -> Bool {
        currentFlags = flags

        // Пока открыто наше окно (настройки) — полный сквозной проход,
        // чтобы рекордер клавиш мог поймать и сам хоткей переключения.
        if NSApp.keyWindow != nil { return false }

        // Хоткей переключения работает всегда, при любом состоянии режима.
        if settings.isToggle(keyCode, flags) {
            setMode(!isOn)
            swallowKeys.insert(keyCode)
            return true
        }

        guard isOn else { return false }

        // Esc всегда завершает режим.
        if keyCode == VK.escape {
            setMode(false)
            swallowKeys.insert(keyCode)
            return true
        }

        guard settings.isControlKey(keyCode) else { return false }

        // Проглотить keyUp заранее, даже если между нажатием и отпусканием режим выключат.
        swallowKeys.insert(keyCode)

        // Фильтр автоповтора: зажатая клавиша уже обработана.
        guard !heldKeys.contains(keyCode) else { return true }
        heldKeys.insert(keyCode)

        if let dir = settings.moveDir(keyCode) {
            heldDirs.insert(dir)
            dirStarted[dir] = CACurrentMediaTime()
        } else if let sdir = settings.scrollDir(keyCode) {
            if scrollDirs.isEmpty {
                scrollStarted = CACurrentMediaTime()
            }
            scrollDirs.insert(sdir)
        } else if let action = settings.oneShotAction(keyCode) {
            perform(action)
        }
        return true
    }

    /// true — событие поглощено.
    private func handleKeyUp(keyCode: Int) -> Bool {
        heldKeys.remove(keyCode)
        if let dir = settings.moveDir(keyCode) {
            heldDirs.remove(dir)
            dirStarted[dir] = nil
        }
        if let sdir = settings.scrollDir(keyCode) {
            scrollDirs.remove(sdir)
        }
        return swallowKeys.remove(keyCode) != nil
    }

    private func perform(_ action: OneShotAction) {
        switch action {
        case .leftClick:
            mouse.click(button: .left)
        case .rightClick:
            mouse.click(button: .right)
        case .middleClick:
            mouse.click(button: .other)
        case .doubleClick:
            mouse.doubleClick()
        case .dragToggle:
            if dragging {
                mouse.dragEnd()
                dragging = false
            } else {
                mouse.dragStart()
                dragging = true
            }
        }
    }
}
