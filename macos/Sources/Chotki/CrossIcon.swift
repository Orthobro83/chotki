import AppKit

/// The eight-pointed cross, drawn rather than shipped as an asset.
///
/// Drawn because a template image must be monochrome and crisp at 18pt in both
/// menu bar appearances; generating it avoids an asset pipeline and any chance
/// of shipping a non-template PNG that renders as a black smudge in dark mode.
enum CrossIcon {

    static func menuBarImage(height: CGFloat = 18) -> NSImage {
        let size = NSSize(width: height * 14.0 / 18.0, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            let s = height / 18.0
            let path = NSBezierPath()
            path.lineWidth = 1.4 * s
            path.lineCapStyle = .round

            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
                path.move(to: NSPoint(x: x1 * s, y: y1 * s))
                path.line(to: NSPoint(x: x2 * s, y: y2 * s))
            }

            line(7, 1.2, 7, 16.8)      // upright
            line(4.6, 14.6, 9.4, 14.6) // titulus
            line(1.6, 11.2, 12.4, 11.2) // main crossbar
            line(3.4, 5.0, 10.6, 7.2)  // slanted footrest

            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        // Without this the icon does not invert in a dark menu bar.
        image.isTemplate = true
        return image
    }
}

extension CrossIcon {

    /// The Dock icon: a gold cross on a dark ground.
    ///
    /// Drawn rather than shipped as an .icns for the same reason as the menu bar
    /// image — no asset pipeline, and it cannot fall out of step with the
    /// palette. Set on `NSApp.applicationIconImage` at launch.
    static func appIcon(size: CGFloat = 512) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let s = size / 512.0
            let ground = NSColor(red: 0.082, green: 0.086, blue: 0.110, alpha: 1)
            let gold = NSColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1)

            NSBezierPath(
                roundedRect: NSRect(x: 24 * s, y: 24 * s, width: 464 * s, height: 464 * s),
                xRadius: 104 * s, yRadius: 104 * s
            ).addClip()
            ground.setFill()
            NSRect(origin: .zero, size: NSSize(width: size, height: size)).fill()

            let path = NSBezierPath()
            path.lineWidth = 26 * s
            path.lineCapStyle = .round

            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
                path.move(to: NSPoint(x: x1 * s, y: y1 * s))
                path.line(to: NSPoint(x: x2 * s, y: y2 * s))
            }

            line(256, 96, 256, 416)      // upright
            line(200, 372, 312, 372)     // titulus
            line(140, 300, 372, 300)     // main crossbar
            line(178, 178, 334, 222)     // slanted footrest

            gold.setStroke()
            path.stroke()
            return true
        }
    }
}
