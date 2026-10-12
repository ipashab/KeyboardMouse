// Генерация иконки приложения: AppIcon.iconset в указанном каталоге.
// Запуск: swift Support/generate-icon.swift <выходной-каталог>
import AppKit

let outputDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "AppIcon.iconset")

try? FileManager.default.createDirectory(
    at: outputDir, withIntermediateDirectories: true
)

/// Битмап-контекст фиксированного пиксельного размера.
func makeRep(_ px: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        FileHandle.standardError.write("Не удалось создать битмап\n".data(using: .utf8)!)
        exit(1)
    }
    rep.size = NSSize(width: px, height: px)
    return rep
}

func drawIcon(into rep: NSBitmapImageRep) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    defer { NSGraphicsContext.restoreGraphicsState() }

    let size = CGFloat(rep.pixelsWide)
    let full = NSRect(x: 0, y: 0, width: size, height: size)

    // Фон: скруглённый квадрат с диагональным индиго-градиентом.
    let inset = size * 0.03125
    let corner = size * 0.2246
    let bgRect = full.insetBy(dx: inset, dy: inset)
    let background = NSBezierPath(
        roundedRect: bgRect, xRadius: corner, yRadius: corner
    )
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.51, green: 0.55, blue: 0.97, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.27, blue: 0.83, alpha: 1),
        ]
    )!
    gradient.draw(in: background, angle: -45)

    // Лёгкая внутренняя подсветка сверху.
    let highlight = NSBezierPath(
        roundedRect: bgRect.insetBy(dx: size * 0.012, dy: size * 0.012),
        xRadius: corner * 0.92, yRadius: corner * 0.92
    )
    highlight.lineWidth = size * 0.006
    NSColor.white.withAlphaComponent(0.18).setStroke()
    highlight.stroke()

    // Стрелка курсора: классический полигон в юнит-координатах (256-канва, y вниз).
    let unit: [(Double, Double)] = [
        (32, 0), (32, 224), (96, 170), (138, 256), (176, 240), (134, 158), (216, 158),
    ]
    // Масштаб: стрелка занимает ~58% высоты канвы, центрируется по своим границам.
    let scale = size * 0.58 / 256
    let cxUnit = 124.0  // центр полигона по x
    let cyUnit = 128.0  // центр полигона по y
    let arrow = NSBezierPath()
    var first = true
    for (ux, uy) in unit {
        // Юнит-координаты (y вниз) → AppKit (y вверх), относительно центра канвы.
        let x = size / 2 + CGFloat(ux - cxUnit) * scale
        let y = size / 2 + CGFloat(cyUnit - uy) * scale
        if first {
            arrow.move(to: NSPoint(x: x, y: y))
            first = false
        } else {
            arrow.line(to: NSPoint(x: x, y: y))
        }
    }
    arrow.close()

    // Тень стрелки.
    let shadow = NSShadow()
    shadow.shadowBlurRadius = size * 0.022
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.014)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.set()

    NSColor.white.setFill()
    arrow.fill()
    NSGraphicsContext.current?.shouldAntialias = true
}

/// Записать PNG нужного размера.
func writePNG(_ px: Int, _ name: String) {
    let rep = makeRep(px)
    drawIcon(into: rep)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("Не удалось создать PNG \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    let url = outputDir.appendingPathComponent(name)
    do {
        try png.write(to: url)
    } catch {
        FileHandle.standardError.write("Ошибка записи \(url.path)\n".data(using: .utf8)!)
        exit(1)
    }
}

writePNG(16, "icon_16x16.png")
writePNG(32, "icon_16x16@2x.png")
writePNG(32, "icon_32x32.png")
writePNG(64, "icon_32x32@2x.png")
writePNG(128, "icon_128x128.png")
writePNG(256, "icon_128x128@2x.png")
writePNG(256, "icon_256x256.png")
writePNG(512, "icon_256x256@2x.png")
writePNG(512, "icon_512x512.png")
writePNG(1024, "icon_512x512@2x.png")

print("Iconset готов: \(outputDir.path)")
