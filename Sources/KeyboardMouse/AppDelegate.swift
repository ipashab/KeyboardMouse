import Foundation
import AppKit
import SwiftUI
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = SettingsStore()
    private var controller: ModeController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var overlay: ModeOverlayPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = ModeController(settings: store.settings)
        controller.onModeChange = { [weak self] on in
            self?.handleModeChange(on)
        }
        store.onChange = { [weak self] settings in
            self?.controller.updateSettings(settings)
            if self?.controller.isOn == true {
                self?.overlay?.updateLegend(settings)
            }
        }

        buildStatusItem()
        overlay = ModeOverlayPanel()

        if !controller.start() {
            // Разрешение ещё не выдано: показать системный запрос и окно настроек
            // с баннером-инструкцией; тап установим, как только разрешат.
            promptAccessibility()
            showSettings()
            startTrustPolling()
        }
    }

    // MARK: - Статус-элемент

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshStatusIcon()
    }

    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        // Различие состояний через цвет: надёжнее, чем редкие варианты символов.
        let on = controller?.isOn == true
        button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        button.contentTintColor = on
            ? NSColor.controlAccentColor
            : NSColor.secondaryLabelColor
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let running = controller.isRunning

        let toggleTitle = controller.isOn
            ? "Выключить режим управления"
            : "Включить режим управления"
        let hotkey = store.settings.toggleHotkey
        let toggle = NSMenuItem(
            title: "\(toggleTitle) — \(hotkeyLabel(keyCode: hotkey.keyCode, modifiers: Int(hotkey.modifiers)))",
            action: #selector(toggleModeFromMenu),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.isEnabled = running
        if !running {
            toggle.title = "Режим недоступен — нет разрешения"
        }
        menu.addItem(toggle)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Настройки…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        if !running {
            if AXIsProcessTrusted() {
                // Права выданы, но текущий процесс их не подхватит — нужен перезапуск.
                let hint = NSMenuItem(
                    title: "Разрешение получено — перезапустите приложение",
                    action: nil, keyEquivalent: ""
                )
                hint.isEnabled = false
                menu.addItem(hint)
            } else {
                let access = NSMenuItem(
                    title: "Открыть системные настройки доступа…",
                    action: #selector(openAccessibility),
                    keyEquivalent: ""
                )
                access.target = self
                menu.addItem(access)
            }
            let restart = NSMenuItem(
                title: "Перезапустить приложение",
                action: #selector(relaunch),
                keyEquivalent: ""
            )
            restart.target = self
            menu.addItem(restart)
            menu.addItem(.separator())
        }

        let quit = NSMenuItem(
            title: "Выход", action: #selector(quit), keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Действия

    @objc private func toggleModeFromMenu() {
        controller.toggleFromMenu()
    }

    @objc private func showSettings() {
        // При открытии настроек выходим из режима, чтобы рекордер клавиш ловил нажатия.
        if controller != nil, controller.isOn {
            controller.toggleFromMenu()
        }

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 700),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Клавиатурная мышь — настройки"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentView = NSHostingView(
                rootView: SettingsView(
                    store: store,
                    openAccessibility: { [weak self] in self?.openAccessibility() },
                    relaunch: { [weak self] in self?.relaunch() },
                    isRunning: { [weak self] in
                        guard let self else { return false }
                        return self.controller.isRunning
                    }
                )
            )
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAccessibility() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Перезапуск приложения: разрешения TCC активируются только для нового
    /// процесса, поэтому после выдачи прав нужен relaunch.
    @objc private func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            // Запуск «голым» бинарём из .build — просто перезапускаем процесс.
            NSApp.terminate(nil)
            return
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "/bin/sleep 0.8; /usr/bin/open '\(bundleURL.path)'"]
        try? task.run()
        NSApp.terminate(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Смена состояния режима

    private func handleModeChange(_ on: Bool) {
        refreshStatusIcon()
        if on {
            overlay?.show(settings: store.settings)
        } else {
            overlay?.hide()
        }
    }

    // MARK: - Ожидание разрешения

    private func promptAccessibility() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true,
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private var trustTimer: Timer?

    private func startTrustPolling() {
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, !self.controller.isRunning else { return }
            let trusted = AXIsProcessTrusted()
            NSLog("KeyboardMouse: опрос доверия AXIsProcessTrusted=\(trusted)")
            if self.controller.start() {
                NSLog("KeyboardMouse: event tap установлен, режим активен")
                self.trustTimer?.invalidate()
                self.trustTimer = nil
                self.refreshStatusIcon()
            }
        }
    }
}
