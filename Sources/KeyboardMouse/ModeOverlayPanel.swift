import Foundation
import AppKit
import SwiftUI

/// Плавающая панель-подсказка вверху экрана, видимая пока режим активен.
final class ModeOverlayPanel: NSPanel {
    private var hostedView: NSHostingView<OverlayView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        isMovable = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        hasShadow = true
    }

    /// Показать панель с легендой по текущим настройкам.
    func show(settings: StoredSettings) {
        updateLegend(settings)
        positionOnScreen()
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    /// Пересобрать содержимое панели под новые настройки.
    func updateLegend(_ settings: StoredSettings) {
        let view = OverlayView(legend: Self.legendLines(settings))
        if let hosted = hostedView {
            hosted.rootView = view
        } else {
            let hosted = NSHostingView(rootView: view)
            hosted.frame = NSRect(x: 0, y: 0, width: 680, height: 56)
            contentView = hosted
            self.hostedView = hosted
        }
    }

    private func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = contentView?.frame.size ?? CGSize(width: 680, height: 56)
        setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.maxY - size.height - 12
            )
        )
    }

    /// Собрать строки легенды из настроек.
    static func legendLines(_ s: StoredSettings) -> [String] {
        var lines: [String] = []
        var moveParts: [String] = []
        if s.moveLeft != 0 { moveParts.append(keyName(s.moveLeft)) }
        if s.moveRight != 0 { moveParts.append(keyName(s.moveRight)) }
        if s.moveUp != 0 { moveParts.append(keyName(s.moveUp)) }
        if s.moveDown != 0 { moveParts.append(keyName(s.moveDown)) }
        if !moveParts.isEmpty {
            lines.append("\(moveParts.joined(separator: " ")) — движение")
        }
        if s.fastModifier != FastModifier.none {
            lines.append("\(s.fastModifier.label) — ускорение")
        }
        if s.clickLeft != 0 { lines.append("\(keyName(s.clickLeft)) — клик") }
        if s.clickRight != 0 { lines.append("\(keyName(s.clickRight)) — правый клик") }
        if s.clickMiddle != 0 { lines.append("\(keyName(s.clickMiddle)) — средний клик") }
        if s.clickDouble != 0 { lines.append("\(keyName(s.clickDouble)) — двойной клик") }
        if s.dragToggle != 0 { lines.append("\(keyName(s.dragToggle)) — перетаскивание") }
        var scrollParts: [String] = []
        if s.scrollUp != 0 { scrollParts.append(keyName(s.scrollUp)) }
        if s.scrollDown != 0 { scrollParts.append(keyName(s.scrollDown)) }
        if !scrollParts.isEmpty {
            lines.append("\(scrollParts.joined(separator: " / ")) — прокрутка")
        }
        lines.append("Esc — выход")
        return lines
    }
}

private struct OverlayView: View {
    let legend: [String]

    var body: some View {
        VStack(spacing: 4) {
            Text("РЕЖИМ УПРАВЛЕНИЯ КУРСОРОМ")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.red)
            Text(legend.joined(separator: "   •   "))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: 680)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .opacity(0.92)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.red.opacity(0.75), lineWidth: 1.5)
        )
    }
}
