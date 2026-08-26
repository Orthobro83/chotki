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
    /// The same mark, square and full-bleed, for iOS.
    ///
    /// iOS applies its own mask, so an icon must not round its own corners or
    /// inset itself — doing both leaves a small mark floating in a large
    /// rounded square inside another rounded square. The proportions are
    /// otherwise identical, because it is one rope at three sizes rather than
    /// three drawings of a rope.
    static func phoneIcon(size: CGFloat = 1024) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let ground = NSColor(red: 0.082, green: 0.086, blue: 0.110, alpha: 1)
            let gold = NSColor(red: 0.788, green: 0.635, blue: 0.153, alpha: 1)

            ground.setFill()
            NSRect(origin: .zero, size: NSSize(width: size, height: size)).fill()

            let margin = size * 0.16
            let mark = size - margin * 2
            func markX(_ u: CGFloat) -> CGFloat { margin + u * mark }
            func markY(_ v: CGFloat) -> CGFloat { margin + v * mark }

            gold.setFill()
            let knot = RopeMarkGeometry.knotRadius * mark
            for centre in RopeMarkGeometry.knotCentres {
                NSBezierPath(ovalIn: NSRect(
                    x: markX(centre.x) - knot, y: markY(centre.y) - knot,
                    width: knot * 2, height: knot * 2
                )).fill()
            }
            let box = RopeMarkGeometry.crossBox
            fill(
                in: CGRect(
                    x: markX(box.x), y: markY(box.y),
                    width: box.width * mark, height: box.height * mark
                ),
                colour: gold
            )
            return true
        }
    }

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

            // The mark is a chotki — a loop of knots with the cross hanging
            // from it — which is what the app is named after. The menu bar
            // glyph stays a bare cross: at 18 points a rope of knots is mud.
            //
            // Drawn from the same numbers in core as the SwiftUI mark, in
            // AppKit rather than through a SwiftUI Path, because NSBezierPath
            // only learned to take a CGPath in macOS 14 and this app runs on 13.
            let margin = size * 0.14
            let mark = size - margin * 2
            func markX(_ u: CGFloat) -> CGFloat { margin + u * mark }
            func markY(_ v: CGFloat) -> CGFloat { margin + v * mark }

            gold.setFill()
            let knot = RopeMarkGeometry.knotRadius * mark
            for centre in RopeMarkGeometry.knotCentres {
                NSBezierPath(ovalIn: NSRect(
                    x: markX(centre.x) - knot, y: markY(centre.y) - knot,
                    width: knot * 2, height: knot * 2
                )).fill()
            }

            let box = RopeMarkGeometry.crossBox
            fill(
                in: CGRect(
                    x: markX(box.x), y: markY(box.y),
                    width: box.width * mark, height: box.height * mark
                ),
                colour: gold
            )
            return true
        }
    }
}
