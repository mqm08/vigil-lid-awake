// Renders the Vigil app icon at 1024×1024.
//   swiftc scripts/make_icon.swift -o build/make_icon && build/make_icon out.png
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let space = CGColorSpaceCreateDeviceRGB()

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

// ---- Squircle body (macOS icon grid: 824pt body, 100pt margin)
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.35))
ctx.addPath(squircle); ctx.setFillColor(rgb(0.05, 0.06, 0.16)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()

// Night sky gradient
let sky = CGGradient(colorsSpace: space, colors: [
    rgb(0.24, 0.26, 0.58), rgb(0.12, 0.13, 0.34), rgb(0.04, 0.05, 0.14)
] as CFArray, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// Warm horizon bloom behind the moon
let bloom = CGGradient(colorsSpace: space, colors: [
    rgb(1.0, 0.62, 0.25, 0.42), rgb(1.0, 0.55, 0.2, 0.0)
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(bloom, startCenter: CGPoint(x: 540, y: 600), startRadius: 0,
                       endCenter: CGPoint(x: 540, y: 600), endRadius: 400, options: [])

// Stars
let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (200, 800, 6, 0.7), (280, 700, 3.5, 0.5), (800, 800, 5, 0.65), (850, 680, 3, 0.45),
    (180, 610, 3, 0.4), (860, 570, 3, 0.35)
]
for (x, y, r, a) in stars {
    ctx.setFillColor(rgb(1, 0.97, 0.9, a))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// ---- Hero: the closed lid, front-on, with a glowing notch — the same
// motif as the menu bar glyph (MenuBarGlyph.swift), just much larger and
// more dimensional. One bold shape, matching CleanMyMac / CARROT's style
// of a single illustrative focal object rather than a busy scene.
let lidW: CGFloat = 620, lidH: CGFloat = 372
let lidRect = CGRect(x: 512 - lidW / 2, y: 330, width: lidW, height: lidH)
let lidRadius: CGFloat = 72
let lidPath = CGPath(roundedRect: lidRect, cornerWidth: lidRadius, cornerHeight: lidRadius, transform: nil)

// Glow halo behind the lid
ctx.saveGState()
let halo = CGGradient(colorsSpace: space, colors: [
    rgb(1.0, 0.62, 0.22, 0.55), rgb(1.0, 0.55, 0.18, 0.0)
] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(halo, startCenter: CGPoint(x: lidRect.midX, y: lidRect.midY), startRadius: 0,
                       endCenter: CGPoint(x: lidRect.midX, y: lidRect.midY), endRadius: 420, options: [])
ctx.restoreGState()

// Cast shadow under the lid
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 46, color: rgb(0, 0, 0, 0.45))
ctx.addPath(lidPath); ctx.setFillColor(rgb(0.6, 0.3, 0.05)); ctx.fillPath()
ctx.restoreGState()

// Amber gradient body, top-lit
ctx.saveGState()
ctx.addPath(lidPath); ctx.clip()
let lidGrad = CGGradient(colorsSpace: space, colors: [
    rgb(1.0, 0.86, 0.55), rgb(1.0, 0.66, 0.24), rgb(0.93, 0.42, 0.12)
] as CFArray, locations: [0, 0.45, 1])!
ctx.drawLinearGradient(lidGrad, start: CGPoint(x: 512, y: lidRect.maxY), end: CGPoint(x: 512, y: lidRect.minY), options: [])
ctx.restoreGState()

// Notch: flat top, rounded bottom corners — cut into the top edge, tinted
// like a pane onto the night sky behind it.
let notchW: CGFloat = 188, notchH: CGFloat = 64, notchRad: CGFloat = 30
let notchRect = CGRect(x: 512 - notchW / 2, y: lidRect.maxY - notchH, width: notchW, height: notchH)
let notch = CGMutablePath()
notch.move(to: CGPoint(x: notchRect.minX, y: notchRect.maxY))
notch.addLine(to: CGPoint(x: notchRect.minX, y: notchRect.minY + notchRad))
notch.addArc(tangent1End: CGPoint(x: notchRect.minX, y: notchRect.minY),
            tangent2End: CGPoint(x: notchRect.minX + notchRad, y: notchRect.minY), radius: notchRad)
notch.addLine(to: CGPoint(x: notchRect.maxX - notchRad, y: notchRect.minY))
notch.addArc(tangent1End: CGPoint(x: notchRect.maxX, y: notchRect.minY),
            tangent2End: CGPoint(x: notchRect.maxX, y: notchRect.minY + notchRad), radius: notchRad)
notch.addLine(to: CGPoint(x: notchRect.maxX, y: notchRect.maxY))
notch.closeSubpath()
ctx.setFillColor(rgb(0.98, 0.97, 0.94))
ctx.addPath(notch); ctx.fillPath()

// Thin dark foot beneath the lid — the closed base, viewed edge-on.
let footRect = CGRect(x: lidRect.minX - 18, y: 296, width: lidRect.width + 36, height: 30)
ctx.setFillColor(rgb(0.10, 0.09, 0.14, 0.85))
ctx.addPath(CGPath(roundedRect: footRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
ctx.fillPath()

// Top highlight arc on the lid, like glass catching light.
ctx.saveGState()
ctx.addPath(lidPath); ctx.clip()
let sheen = CGGradient(colorsSpace: space, colors: [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: lidRect.maxY), end: CGPoint(x: 512, y: lidRect.maxY - 90), options: [])
ctx.restoreGState()

// Subtle top highlight on the squircle
let gloss = CGGradient(colorsSpace: space, colors: [rgb(1, 1, 1, 0.10), rgb(1, 1, 1, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(gloss, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 640), options: [])
ctx.restoreGState()

// Hairline border
ctx.addPath(squircle)
ctx.setStrokeColor(rgb(1, 1, 1, 0.08)); ctx.setLineWidth(2); ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
