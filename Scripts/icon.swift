import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let image = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
    let tile = NSBezierPath(roundedRect: CGRect(x: 95, y: 95, width: 834, height: 834), xRadius: 198, yRadius: 198)
    NSGradient(starting: NSColor(srgbRed: 0.05, green: 0.11, blue: 0.16, alpha: 1),
               ending: NSColor(srgbRed: 0.12, green: 0.24, blue: 0.31, alpha: 1))?.draw(in: tile, angle: 65)

    let phone = NSBezierPath(roundedRect: CGRect(x: 365, y: 225, width: 294, height: 574), xRadius: 75, yRadius: 75)
    phone.lineWidth = 27
    NSColor(srgbRed: 0.64, green: 0.78, blue: 0.86, alpha: 1).setStroke()
    phone.stroke()

    let glide = NSBezierPath()
    glide.move(to: CGPoint(x: 512, y: 650))
    glide.curve(to: CGPoint(x: 512, y: 378), controlPoint1: CGPoint(x: 414, y: 566),
                controlPoint2: CGPoint(x: 607, y: 470))
    glide.move(to: CGPoint(x: 443, y: 438))
    glide.line(to: CGPoint(x: 512, y: 367))
    glide.line(to: CGPoint(x: 581, y: 438))
    glide.lineWidth = 35
    glide.lineCapStyle = .round
    glide.lineJoinStyle = .round
    NSColor(srgbRed: 0.51, green: 0.98, blue: 0.73, alpha: 1).setStroke()
    glide.stroke()
    return true
}

for edge in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = edge * factor
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Unable to create icon bitmap") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = factor == 2 ? "@2x" : ""
        let url = root.appendingPathComponent("icon_\(edge)x\(edge)\(suffix).png")
        guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to encode icon") }
        try data.write(to: url)
    }
}
