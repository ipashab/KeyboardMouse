import Foundation
import AppKit
import CoreGraphics

/// Обёртки над CGEvent: перемещение, клики, перетаскивание, прокрутка.
final class MouseActions {
    private let source = CGEventSource(stateID: .combinedSessionState)
    /// Кэш объединённого прямоугольника экранов (в CG-координатах).
    private var screenBounds: CGRect = .null

    init() {
        refreshScreenBounds()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screensChanged() {
        refreshScreenBounds()
    }

    /// Объединение рамок всех активных дисплеев в глобальных CG-координатах.
    func refreshScreenBounds() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        var rect = CGRect.null
        if CGGetActiveDisplayList(16, &ids, &count) == .success, count > 0 {
            for id in ids.prefix(Int(count)) {
                rect = rect.union(CGDisplayBounds(id))
            }
        }
        if rect.width > 0 {
            screenBounds = rect
        }
    }

    /// Текущая позиция курсора в CG-координатах (начало — левый верхний угол).
    var location: CGPoint {
        if let event = CGEvent(source: source) {
            return event.location
        }
        // Запасной путь через NSEvent с переводом системы координат.
        let ns = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSPointInRect(ns, $0.frame) })
                ?? NSScreen.main else { return .zero }
        let mainBounds = CGDisplayBounds(CGMainDisplayID())
        return CGPoint(
            x: mainBounds.minX + (ns.x - screen.frame.minX),
            y: mainBounds.minY + (screen.frame.maxY - ns.y)
        )
    }

    /// Ограничить точку видимой областью экранов.
    private func clamp(_ point: CGPoint) -> CGPoint {
        guard screenBounds.width > 0 else { return point }
        let x = min(max(point.x, screenBounds.minX), screenBounds.maxX - 1)
        let y = min(max(point.y, screenBounds.minY), screenBounds.maxY - 1)
        return CGPoint(x: x, y: y)
    }

    /// Сдвинуть курсор на (dx, dy). При активном перетаскивании генерирует leftMouseDragged.
    func moveBy(dx: Double, dy: Double, dragging: Bool) {
        let current = location
        let target = clamp(CGPoint(x: current.x + dx, y: current.y + dy))
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: dragging ? .leftMouseDragged : .mouseMoved,
            mouseCursorPosition: target,
            mouseButton: .left
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    /// Клик указанной кнопкой в текущей позиции курсора.
    func click(button: MouseButton, clickState: Int = 1) {
        let point = location
        let down = makeMouseEvent(button: button, isDown: true, at: point, clickState: clickState)
        let up = makeMouseEvent(button: button, isDown: false, at: point, clickState: clickState)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Двойной клик: две пары событий, как при реальном нажатии.
    func doubleClick() {
        click(button: .left, clickState: 1)
        usleep(40_000)
        click(button: .left, clickState: 2)
    }

    /// Начать перетаскивание: зажать левую кнопку в текущей позиции.
    func dragStart() {
        let event = makeMouseEvent(button: .left, isDown: true, at: location, clickState: 1)
        event?.post(tap: .cghidEventTap)
    }

    /// Завершить перетаскивание: отпустить левую кнопку.
    func dragEnd() {
        let event = makeMouseEvent(button: .left, isDown: false, at: location, clickState: 1)
        event?.post(tap: .cghidEventTap)
    }

    /// Вертикальная прокрутка. Положительное `pixels` — вверх.
    func scroll(pixels: Double) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(pixels),
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.post(tap: .cghidEventTap)
    }

    /// Создать событие нажатия/отпускания кнопки мыши.
    private func makeMouseEvent(
        button: MouseButton, isDown: Bool, at point: CGPoint, clickState: Int
    ) -> CGEvent? {
        // CGMouseEventType не содержит «other», поэтому для средней кнопки
        // создаём событие через left и переопределяем тип + номер кнопки.
        let factoryType: CGEventType = {
            switch (button, isDown) {
            case (.left, true), (.other, true): return .leftMouseDown
            case (.left, false), (.other, false): return .leftMouseUp
            case (.right, true): return .rightMouseDown
            case (.right, false): return .rightMouseUp
            }
        }()

        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: factoryType,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return nil }

        if button == .other {
            event.type = isDown ? .otherMouseDown : .otherMouseUp
            event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        }
        if clickState != 1 {
            event.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
        }
        return event
    }
}

/// Кнопки мыши.
public enum MouseButton {
    case left, right, other
}
