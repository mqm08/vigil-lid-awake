import AppKit

/// The menu bar glyph: a closed MacBook lid, front-on, with a centred notch
/// echoing the real MacBook display notch. Off and on share one geometry
/// (`LidGeometry`) so the two states line up pixel-for-pixel — only the
/// fill treatment changes.
enum MenuBarGlyph {

    static let size = NSSize(width: 22, height: 16)
    static let amber = NSColor(red: 1.00, green: 0.66, blue: 0.24, alpha: 1)
    static let amberDeep = NSColor(red: 0.98, green: 0.50, blue: 0.14, alpha: 1)

    /// Monochrome template: hollow lid, hollow notch. Adapts to light/dark
    /// menu bars automatically because `isTemplate` is true.
    static let off: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(on: false, fg: .black, in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }()

    /// Coloured: amber gradient fill, glow halo, light notch cutout.
    static let on: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(on: true, fg: .labelColor, in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }()

    // MARK: - Shared geometry

    private struct LidGeometry {
        let box: NSRect
        var k: CGFloat { box.width / 22 }

        func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: box.minX + x * k, y: box.minY + y * k, width: w * k, height: h * k)
        }

        var bodyRect: NSRect { R(2.0, 3.1, 18.0, 10.2) }
        var bodyRadius: CGFloat { 2.3 * k }
        var footRect: NSRect { R(0.8, 2.0, 20.4, 1.15) }
        var footRadius: CGFloat { 0.55 * k }

        /// Flat top, rounded bottom corners only — the real MacBook notch silhouette.
        func notchPath() -> NSBezierPath {
            let w: CGFloat = 5.2, h: CGFloat = 1.9, rad: CGFloat = 0.85
            let x0 = 11 - w / 2
            let top = box.minY + (3.1 + 10.2) * k
            let rect = NSRect(x: box.minX + x0 * k, y: top - h * k, width: w * k, height: h * k)

            let p = NSBezierPath()
            p.move(to: NSPoint(x: rect.minX, y: rect.maxY))
            p.line(to: NSPoint(x: rect.minX, y: rect.minY + rad * k))
            p.curve(to: NSPoint(x: rect.minX + rad * k, y: rect.minY),
                    controlPoint1: NSPoint(x: rect.minX, y: rect.minY + rad * k * 0.45),
                    controlPoint2: NSPoint(x: rect.minX + rad * k * 0.45, y: rect.minY))
            p.line(to: NSPoint(x: rect.maxX - rad * k, y: rect.minY))
            p.curve(to: NSPoint(x: rect.maxX, y: rect.minY + rad * k),
                    controlPoint1: NSPoint(x: rect.maxX - rad * k * 0.45, y: rect.minY),
                    controlPoint2: NSPoint(x: rect.maxX, y: rect.minY + rad * k * 0.45))
            p.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
            p.close()
            return p
        }
    }

    private static func draw(on: Bool, fg: NSColor, in box: NSRect) {
        let g = LidGeometry(box: box)
        let body = NSBezierPath(roundedRect: g.bodyRect, xRadius: g.bodyRadius, yRadius: g.bodyRadius)
        let foot = NSBezierPath(roundedRect: g.footRect, xRadius: g.footRadius, yRadius: g.footRadius)

        if on {
            amber.withAlphaComponent(0.24).setFill()
            NSBezierPath(roundedRect: g.bodyRect.insetBy(dx: -1.7 * g.k, dy: -1.7 * g.k),
                        xRadius: g.bodyRadius + 1.7 * g.k, yRadius: g.bodyRadius + 1.7 * g.k).fill()

            NSGraphicsContext.saveGraphicsState()
            body.addClip()
            let grad = NSGradient(colors: [
                amber.blended(withFraction: 0.30, of: .white) ?? amber,
                amber,
                amberDeep,
            ])
            grad?.draw(in: g.bodyRect, angle: 90)
            NSGraphicsContext.restoreGraphicsState()

            NSColor(calibratedWhite: 0.99, alpha: 1).setFill()
            g.notchPath().fill()

            fg.withAlphaComponent(0.45).setFill()
            foot.fill()
        } else {
            fg.setStroke()
            body.lineWidth = 1.5 * g.k
            body.lineJoinStyle = .round
            body.stroke()

            let notch = g.notchPath()
            fg.setStroke()
            notch.lineWidth = 1.4 * g.k
            notch.lineJoinStyle = .round
            notch.stroke()

            fg.withAlphaComponent(0.55).setFill()
            foot.fill()
        }
    }
}
