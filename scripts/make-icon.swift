// FALLBACK icon generator. The shipped icon is Resources/icon-master.png
// (AI-generated "fleet in formation" artwork) — this script only exists to
// regenerate a programmatic placeholder if that master is ever lost.
//
// Full regeneration (macOS 26 needs an asset catalog, older macOS the icns):
//   swift scripts/make-icon.swift               # writes /tmp/Fleet.iconset PNGs
//   build an AppIcon.appiconset around the PNGs, then:
//   xcrun actool <xcassets> --compile out --platform macosx \
//     --minimum-deployment-target 14.0 --app-icon AppIcon \
//     --output-partial-info-plist /dev/null
//   cp out/Assets.car out/AppIcon.icns Resources/
import AppKit

let canvas: CGFloat = 1024

func drawIcon() -> NSImage {
    let img = NSImage(size: NSSize(width: canvas, height: canvas))
    img.lockFocus()

    // macOS-style squircle with the standard ~10% transparent margin.
    let inset: CGFloat = canvas * 0.098
    let rect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

    // Dark terminal background, subtle vertical gradient.
    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.23, alpha: 1),
        ending: NSColor(srgbRed: 0.09, green: 0.10, blue: 0.13, alpha: 1))!
    gradient.draw(in: squircle, angle: -90)

    // Hairline top bevel for depth.
    NSColor.white.withAlphaComponent(0.08).setStroke()
    squircle.lineWidth = 6
    squircle.stroke()

    // Prompt chevron "❯" — the terminal identity.
    let promptFont = NSFont.monospacedSystemFont(ofSize: canvas * 0.42, weight: .bold)
    let prompt = NSAttributedString(string: "❯", attributes: [
        .font: promptFont,
        .foregroundColor: NSColor(srgbRed: 0.35, green: 0.62, blue: 1.0, alpha: 1),
    ])
    prompt.draw(at: NSPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.30))

    // Blinking-cursor block next to the prompt.
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSRect(x: rect.minX + rect.width * 0.47, y: rect.minY + rect.height * 0.345,
           width: rect.width * 0.095, height: rect.height * 0.30).fill()

    // The three status dots — Fleet's status language.
    let dotColors = [
        NSColor(srgbRed: 1.00, green: 0.27, blue: 0.27, alpha: 1),
        NSColor(srgbRed: 1.00, green: 0.62, blue: 0.11, alpha: 1),
        NSColor(srgbRed: 0.25, green: 0.85, blue: 0.42, alpha: 1),
    ]
    let dotR = rect.width * 0.052
    let dotY = rect.minY + rect.height * 0.155
    let startX = rect.minX + rect.width * 0.60
    for (i, color) in dotColors.enumerated() {
        color.setFill()
        let x = startX + CGFloat(i) * dotR * 3.0
        NSBezierPath(ovalIn: NSRect(x: x, y: dotY, width: dotR * 2, height: dotR * 2)).fill()
    }

    img.unlockFocus()
    return img
}

func savePNG(_ image: NSImage, to path: String, size: Int) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let iconset = "/tmp/Fleet.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let master = drawIcon()
for size in [16, 32, 128, 256, 512] {
    savePNG(master, to: "\(iconset)/icon_\(size)x\(size).png", size: size)
    savePNG(master, to: "\(iconset)/icon_\(size)x\(size)@2x.png", size: size * 2)
}
print("iconset written to \(iconset) — now: iconutil -c icns \(iconset) -o Resources/AppIcon.icns")
