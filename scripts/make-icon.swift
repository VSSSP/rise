import AppKit

// Draws the 1024 px app icon, a sun rising behind the hills: swift scripts/make-icon.swift <out.png>
let side = 1024
guard CommandLine.arguments.count == 2,
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
    let graphics = NSGraphicsContext(bitmapImageRep: rep)
else {
    fatalError("usage: make-icon.swift <out.png>")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let ctx = graphics.cgContext
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ stops: [(UInt32, CGFloat)], _ alpha: [CGFloat]? = nil) -> CGGradient {
    let colors = stops.enumerated().map { color($0.element.0, alpha?[$0.offset] ?? 1) }
    return CGGradient(colorsSpace: space, colors: colors as CFArray, locations: stops.map(\.1))!
}

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
let sun = CGPoint(x: 512, y: 430)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(shape)
ctx.setFillColor(color(0x23255E))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape)
ctx.clip()
let sky = gradient([(0x23255E, 0), (0x6E3A8C, 0.38), (0xE0566E, 0.72), (0xFFA155, 1)])
ctx.drawLinearGradient(
    sky, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 400), options: [.drawsAfterEndLocation])

let glow = gradient([(0xFFE3A3, 0), (0xFFB45E, 1)], [0.7, 0])
ctx.drawRadialGradient(glow, startCenter: sun, startRadius: 0, endCenter: sun, endRadius: 400, options: [])

ctx.setLineCap(.round)
ctx.setLineWidth(30)
ctx.setStrokeColor(color(0xFFE6B0, 0.95))
for ray in 0..<7 {
    let angle = CGFloat.pi * (0.13 + 0.74 * CGFloat(ray) / 6)
    ctx.move(to: CGPoint(x: sun.x + cos(angle) * 228, y: sun.y + sin(angle) * 228))
    ctx.addLine(to: CGPoint(x: sun.x + cos(angle) * 300, y: sun.y + sin(angle) * 300))
}
ctx.strokePath()

ctx.saveGState()
ctx.addEllipse(in: CGRect(x: sun.x - 175, y: sun.y - 175, width: 350, height: 350))
ctx.clip()
let disc = gradient([(0xFFF4CC, 0), (0xFFC25A, 1)])
ctx.drawLinearGradient(
    disc, start: CGPoint(x: sun.x, y: sun.y + 175), end: CGPoint(x: sun.x, y: sun.y - 175), options: [])
ctx.restoreGState()

let hills = CGMutablePath()
hills.move(to: CGPoint(x: 100, y: 470))
hills.addCurve(
    to: CGPoint(x: 924, y: 440), control1: CGPoint(x: 330, y: 560), control2: CGPoint(x: 640, y: 330))
hills.addLine(to: CGPoint(x: 924, y: 100))
hills.addLine(to: CGPoint(x: 100, y: 100))
hills.closeSubpath()
ctx.saveGState()
ctx.addPath(hills)
ctx.clip()
let ground = gradient([(0x5A2A5E, 0), (0x1D1236, 1)])
ctx.drawLinearGradient(ground, start: CGPoint(x: 512, y: 560), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

let front = CGMutablePath()
front.move(to: CGPoint(x: 100, y: 300))
front.addCurve(
    to: CGPoint(x: 924, y: 360), control1: CGPoint(x: 420, y: 230), control2: CGPoint(x: 700, y: 430))
front.addLine(to: CGPoint(x: 924, y: 100))
front.addLine(to: CGPoint(x: 100, y: 100))
front.closeSubpath()
ctx.addPath(front)
ctx.setFillColor(color(0x140C29, 0.9))
ctx.fillPath()

ctx.addPath(shape)
ctx.setStrokeColor(color(0xFFFFFF, 0.14))
ctx.setLineWidth(6)
ctx.strokePath()
ctx.restoreGState()

graphics.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
