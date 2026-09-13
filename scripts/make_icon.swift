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
    (240, 800, 7, 0.9), (330, 700, 4, 0.6), (760, 820, 5, 0.8), (820, 690, 3.5, 0.55),
    (200, 620, 3, 0.45), (690, 760, 3, 0.5), (420, 830, 3.5, 0.6), (860, 560, 3, 0.4)
]
for (x, y, r, a) in stars {
    ctx.setFillColor(rgb(1, 0.97, 0.9, a))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// ---- Crescent moon (amber), with glow
let moonC = CGPoint(x: 530, y: 610), moonR: CGFloat = 170
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 70, color: rgb(1.0, 0.62, 0.22, 0.85))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: moonC.x - moonR, y: moonC.y - moonR, width: moonR * 2, height: moonR * 2))
ctx.clip()
let moonGrad = CGGradient(colorsSpace: space, colors: [
    rgb(1.0, 0.86, 0.52), rgb(1.0, 0.64, 0.24), rgb(0.95, 0.44, 0.15)
] as CFArray, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(moonGrad, start: CGPoint(x: moonC.x - moonR, y: moonC.y + moonR),
                       end: CGPoint(x: moonC.x + moonR, y: moonC.y - moonR), options: [])
ctx.restoreGState()
ctx.setBlendMode(.clear)
let bite = CGPoint(x: moonC.x + 92, y: moonC.y + 62), biteR: CGFloat = 150
ctx.fillEllipse(in: CGRect(x: bite.x - biteR, y: bite.y - biteR, width: biteR * 2, height: biteR * 2))
ctx.endTransparencyLayer()
ctx.restoreGState()

// ---- Closed laptop, seen slightly from the front
let lidRect = CGRect(x: 232, y: 262, width: 560, height: 62)
let lidPath = CGPath(roundedRect: lidRect, cornerWidth: 26, cornerHeight: 26, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0, 0, 0, 0.5))
ctx.addPath(lidPath); ctx.setFillColor(rgb(0.7, 0.72, 0.78)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(lidPath); ctx.clip()
let metal = CGGradient(colorsSpace: space, colors: [
    rgb(0.93, 0.94, 0.97), rgb(0.72, 0.74, 0.80), rgb(0.55, 0.57, 0.64)
] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(metal, start: CGPoint(x: 512, y: lidRect.maxY), end: CGPoint(x: 512, y: lidRect.minY), options: [])
ctx.restoreGState()
// seam between lid and base
ctx.setFillColor(rgb(0.30, 0.31, 0.38, 0.9))
ctx.fill(CGRect(x: lidRect.minX + 20, y: lidRect.minY + 22, width: lidRect.width - 40, height: 3))
// front notch
ctx.setFillColor(rgb(0.42, 0.43, 0.50, 0.8))
let notch = CGPath(roundedRect: CGRect(x: 462, y: lidRect.minY + 4, width: 100, height: 10),
                   cornerWidth: 5, cornerHeight: 5, transform: nil)
ctx.addPath(notch); ctx.fillPath()

// "still awake" LED
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 22, color: rgb(1.0, 0.7, 0.3, 1))
ctx.setFillColor(rgb(1.0, 0.8, 0.45))
ctx.fillEllipse(in: CGRect(x: 505, y: lidRect.minY + 34, width: 14, height: 14))
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
