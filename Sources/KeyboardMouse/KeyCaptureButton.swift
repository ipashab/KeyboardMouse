import Foundation
import AppKit
import SwiftUI

/// Кнопка-рекордер: при клике переходит в режим захвата следующей клавиши.
struct KeyCaptureButton: NSViewRepresentable {
    /// Заголовок (имя текущей клавиши или подсказка).
    let title: String
    /// Режим захвата: обычная клавиша или хоткей с модификаторами.
    let capturesHotkey: Bool
    /// Вызывается при захвате клавиши: (keyCode, маска модификаторов).
    let onCapture: (Int, Int64) -> Void
    /// Вызывается при переходе в/из режима захвата.
    let onArmedChange: (Bool) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.title = title
        view.capturesHotkey = capturesHotkey
        view.onCapture = onCapture
        view.onArmedChange = onArmedChange
        return view
    }

    func updateNSView(_ view: KeyCaptureView, context: Context) {
        view.title = title
    }
}

/// NSView, перехватывающий keyDown после получения фокуса.
final class KeyCaptureView: NSView {
    var title: String = "" {
        didSet { needsDisplay = true }
    }
    var capturesHotkey = false
    var onCapture: ((Int, Int64) -> Void)?
    var onArmedChange: ((Bool) -> Void)?

    private var armed = false {
        didSet {
            if oldValue != armed {
                applyAppearance()
                onArmedChange?(armed)
            }
            needsDisplay = true
        }
    }

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        label.alignment = .center
        label.isBordered = false
        label.isEditable = false
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        addSubview(label)
        applyAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) не используется") }

    override var acceptsFirstResponder: Bool { true }

    private func applyAppearance() {
        layer?.backgroundColor = armed
            ? NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.35).cgColor
        layer?.borderColor = armed
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor
        label.stringValue = armed ? "Нажмите клавишу…" : title
        label.textColor = armed ? .controlAccentColor : .labelColor
    }

    override func layout() {
        super.layout()
        label.frame = bounds.insetBy(dx: 6, dy: 2)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        armed = true
    }

    override func resignFirstResponder() -> Bool {
        armed = false
        return super.resignFirstResponder()
    }

    private func disarm() {
        armed = false
        if window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = Int(event.keyCode)

        // Esc — отмена захвата, без назначения.
        if keyCode == VK.escape {
            disarm()
            return
        }

        // Игнорировать нажатие чистых модификаторов.
        if VK.modifierCodes.contains(keyCode) { return }

        // Для обычных клавиш модификаторы не фиксируем — иначе нажатие с Shift
        // стало бы недоступным в режиме.
        let mods: CGEventFlags
        if capturesHotkey {
            mods = CGEventFlags(
                rawValue: UInt64(event.modifierFlags.rawValue)
                    & StoredSettings.interestingModifiers.rawValue
            )
        } else {
            mods = []
        }

        disarm()
        onCapture?(keyCode, Int64(mods.rawValue))
    }
}
