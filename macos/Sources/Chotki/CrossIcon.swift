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

    /// The menu bar item: the rope mark, which is the app's own logo — the same
    /// mark as the Dock icon and the one drawn beside the day.
    ///
    /// It was the bare cross before. A three-bar cross in a menu bar is any
    /// Orthodox app; the rope is this one, and it is what the app is named
    /// after. A template image, so macOS inverts it for light and dark menu
    /// bars without a second drawing.
    ///
    /// The knots are drawn at a floor of half a point. At 18 points tall the
    /// geometric radius is about three quarters of a point, which on a
    /// non-Retina display rounds away to nothing and leaves a cross hanging
    /// from an empty circle.
    static func menuBarImage(height: CGFloat = 18) -> NSImage {
        let size = NSSize(width: (height * ropeAspect).rounded(), height: height)
        let image = NSImage(size: size, flipped: true) { rect in
            fillRope(in: rect, colour: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The proportions of the rope mark: the loop, plus the cross hanging below
    /// it. Taken from the geometry rather than measured by eye, so it follows if
    /// the mark is ever redrawn.
    static var ropeAspect: CGFloat {
        let box = RopeMarkGeometry.crossBox
        let top = RopeMarkGeometry.centreY - RopeMarkGeometry.loopRadius
            - RopeMarkGeometry.knotRadius
        let bottom = box.y + box.height
        let left = RopeMarkGeometry.centreX - RopeMarkGeometry.loopRadius
            - RopeMarkGeometry.knotRadius
        let right = RopeMarkGeometry.centreX + RopeMarkGeometry.loopRadius
            + RopeMarkGeometry.knotRadius
        return CGFloat((right - left) / (bottom - top))
    }

    /// Fills the rope mark into `rect` of an already-flipped (top-down) context,
    /// scaled to fit and centred.
    private static func fillRope(in rect: CGRect, colour: NSColor) {
        let box = RopeMarkGeometry.crossBox
        let top = RopeMarkGeometry.centreY - RopeMarkGeometry.loopRadius
            - RopeMarkGeometry.knotRadius
        let left = RopeMarkGeometry.centreX - RopeMarkGeometry.loopRadius
            - RopeMarkGeometry.knotRadius
        let usedWidth = CGFloat(
            (RopeMarkGeometry.loopRadius + RopeMarkGeometry.knotRadius) * 2)
        let usedHeight = CGFloat(box.y + box.height - top)

        // Fit the used part of the mark, not the notional unit box, or the
        // drawing sits small in the middle of its own padding.
        let scale = min(rect.width / usedWidth, rect.height / usedHeight)
        let drawn = CGSize(width: usedWidth * scale, height: usedHeight * scale)
        let originX = rect.minX + (rect.width - drawn.width) / 2
        let originY = rect.minY + (rect.height - drawn.height) / 2

        func x(_ u: Double) -> CGFloat { originX + (CGFloat(u) - CGFloat(left)) * scale }
        func y(_ v: Double) -> CGFloat { originY + (CGFloat(v) - CGFloat(top)) * scale }

        colour.setFill()
        let knot = max(CGFloat(RopeMarkGeometry.knotRadius) * scale, 0.5)
        for centre in RopeMarkGeometry.knotCentres {
            NSBezierPath(ovalIn: NSRect(
                x: x(centre.x) - knot, y: y(centre.y) - knot,
                width: knot * 2, height: knot * 2
            )).fill()
        }

        fill(in: CGRect(
            x: x(box.x), y: y(box.y),
            width: CGFloat(box.width) * scale, height: CGFloat(box.height) * scale
        ), colour: colour)
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
