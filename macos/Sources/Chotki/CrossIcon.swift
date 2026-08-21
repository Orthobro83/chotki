import AppKit
import SwiftUI
import ChotkiCore

/// The cross as AppKit images: the menu bar item and the Dock icon.
///
/// Both take their proportions from `CrossGeometry`, the same source the
/// watermark and the rope mark use, so the four cannot drift apart. Drawn
/// rather than shipped as assets — nothing to keep in step with the palette,
/// and nothing to fall out of date.
enum CrossIcon {

    /// Fills the cross into `rect` of an already-flipped (top-down) context.
    private static func fill(in rect: CGRect, colour: NSColor) {
        let box = CrossGeometry.fitted(in: rect)
        func x(_ u: CGFloat) -> CGFloat { box.minX + u * box.width }
        func y(_ v: CGFloat) -> CGFloat { box.minY + v * box.height }

        colour.setFill()
        for bar in CrossGeometry.bars {
            NSBezierPath(rect: NSRect(
                x: x(bar.x), y: y(bar.y),
                width: bar.width * box.width, height: bar.height * box.height
            )).fill()
        }

        let f = CrossGeometry.footrest
        let footrest = NSBezierPath()
        footrest.move(to: NSPoint(x: x(f.leadingX), y: y(f.leadingY)))
        footrest.line(to: NSPoint(x: x(f.trailingX), y: y(f.trailingY)))
        footrest.line(to: NSPoint(x: x(f.trailingX), y: y(f.trailingY + f.thickness)))
        footrest.line(to: NSPoint(x: x(f.leadingX), y: y(f.leadingY + f.thickness)))
        footrest.close()
        footrest.fill()
    }

    /// The menu bar item. A template image, so macOS inverts it correctly in
    /// both light and dark menu bars.
    static func menuBarImage(height: CGFloat = 18) -> NSImage {
        let size = NSSize(width: (height * CrossGeometry.aspect).rounded(), height: height)
        // Flipped, so the shared top-down geometry can be used directly.
        let image = NSImage(size: size, flipped: true) { rect in
            fill(in: rect, colour: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The Dock icon: gold on a dark rounded square.
    static func appIcon(size: CGFloat = 512) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let ground = NSColor(red: 0.082, green: 0.086, blue: 0.110, alpha: 1)
            let gold = NSColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1)
            let inset = size * 0.047

            NSBezierPath(
                roundedRect: NSRect(
                    x: inset, y: inset, width: size - inset * 2, height: size - inset * 2
                ),
                xRadius: size * 0.203, yRadius: size * 0.203
            ).addClip()
            ground.setFill()
            NSRect(origin: .zero, size: NSSize(width: size, height: size)).fill()

            // Generous margin, so the cross does not crowd the rounded corners.
            let margin = size * 0.20
            fill(
                in: CGRect(
                    x: margin, y: margin, width: size - margin * 2, height: size - margin * 2
                ),
                colour: gold
            )
            return true
        }
    }
}
