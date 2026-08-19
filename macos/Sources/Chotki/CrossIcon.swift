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
