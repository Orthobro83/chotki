import SwiftUI

/// The proportions of the eight-pointed cross, in one place.
///
/// Taken from a reference drawing rather than invented, and expressed as
/// fractions of a bounding box so the menu bar icon, the Dock icon, the
/// watermark and the rope mark are all the same cross at different sizes.
///
/// Note the footrest: the viewer's **left** end is the raised one. That is the
/// traditional orientation — it points to Paradise, for the thief crucified at
/// Christ's right hand. An earlier version had it the other way round.
enum CrossGeometry {
    /// Width divided by height.
    static let aspect: CGFloat = 748.0 / 1440.0

    /// Upright, titulus and crossbar, as fractions: (x, y, width, height).
    static let bars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.402, 0.000, 0.201, 1.000),   // upright
        (0.205, 0.101, 0.594, 0.097),   // titulus
        (0.000, 0.299, 1.000, 0.097)    // crossbar
    ]

    /// The slanted footrest, as a parallelogram: leading and trailing x, the
    /// y of the top edge at each end, and its thickness.
    static let footrest = (
        leadingX: CGFloat(0.209), trailingX: CGFloat(0.786),
        leadingY: CGFloat(0.639), trailingY: CGFloat(0.792),
        thickness: CGFloat(0.097)
    )

    /// The box the cross occupies inside `rect`, keeping its proportions.
    static func fitted(in rect: CGRect) -> CGRect {
        var width = rect.width
        var height = rect.height
        if width / height > aspect { width = height * aspect } else { height = width / aspect }
        return CGRect(
            x: rect.midX - width / 2, y: rect.midY - height / 2,
            width: width, height: height
        )
    }
}

/// The eight-pointed cross as a filled shape.
///
/// Filled rather than stroked: at a watermark's opacity a stroked outline reads
/// as a few stray lines, and a solid cross reads as a cross.
struct OrthodoxCross: Shape {
    func path(in rect: CGRect) -> Path {
        let box = CrossGeometry.fitted(in: rect)
        func x(_ u: CGFloat) -> CGFloat { box.minX + u * box.width }
        func y(_ v: CGFloat) -> CGFloat { box.minY + v * box.height }

        var path = Path()
        for (bx, by, bw, bh) in CrossGeometry.bars {
            path.addRect(CGRect(
                x: x(bx), y: y(by), width: bw * box.width, height: bh * box.height
            ))
        }

        let f = CrossGeometry.footrest
        path.move(to: CGPoint(x: x(f.leadingX), y: y(f.leadingY)))
        path.addLine(to: CGPoint(x: x(f.trailingX), y: y(f.trailingY)))
        path.addLine(to: CGPoint(x: x(f.trailingX), y: y(f.trailingY + f.thickness)))
        path.addLine(to: CGPoint(x: x(f.leadingX), y: y(f.leadingY + f.thickness)))
        path.closeSubpath()
        return path
    }
}

/// A faint cross behind the day's rules, filling space that would otherwise be
/// empty. Kept very low in contrast: it should be noticed only once, and never
/// compete with the text over it.
struct CrossWatermark: View {
    var height: CGFloat = 150

    var body: some View {
        OrthodoxCross()
            .fill(Theme.parchment)
            .frame(width: height * CrossGeometry.aspect, height: height)
            .opacity(0.07)
            .allowsHitTesting(false)
    }
}

/// The app's mark: a prayer rope, which is what the name means.
///
/// A loop of knots with the cross hanging from it, as a chotki is actually
/// made. Small and quiet — a signature in the corner, not a badge.
struct RopeMark: View {
    var size: CGFloat = 26
    var knots: Int = 12

    var body: some View {
        Canvas { context, canvasSize in
            let radius = size * 0.30
            let centre = CGPoint(x: canvasSize.width / 2, y: radius + size * 0.06)
            let knotRadius = size * 0.042

            for index in 0..<knots {
                // Start at the bottom and go round, so the gap for the cross
                // sits where the cross actually hangs.
                let fraction = Double(index) / Double(knots)
                let angle = .pi / 2 + fraction * 2 * .pi
                let point = CGPoint(
                    x: centre.x + radius * cos(angle),
                    y: centre.y + radius * sin(angle)
                )
                // Leave the lowest knot out; the cross takes its place.
                guard index != 0 else { continue }
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - knotRadius, y: point.y - knotRadius,
                        width: knotRadius * 2, height: knotRadius * 2
                    )),
                    with: .color(Theme.gold)
                )
            }

            // The cross, hanging below the loop.
            let crossHeight = size * 0.34
            let crossRect = CGRect(
                x: centre.x - crossHeight * CrossGeometry.aspect / 2,
                y: centre.y + radius - knotRadius,
                width: crossHeight * CrossGeometry.aspect,
                height: crossHeight
            )
            context.fill(OrthodoxCross().path(in: crossRect), with: .color(Theme.gold))
        }
        .frame(width: size, height: size)
        .opacity(0.5)
        .allowsHitTesting(false)
        .help("chotki")
    }
}

/// What sits behind the day's rules: a faint cross where the panel would
/// otherwise be blank, and the rope mark in the corner.
///
/// Its own view so the app and the offscreen renderer draw the same thing.
struct RuleBackdrop: View {
    var crossHeight: CGFloat = 96
    var markSize: CGFloat = 30

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Anchored to the bottom, where the space actually is. Centred, it
            // struck through the calendar and read as stray lines rather than
            // as a cross.
            VStack {
                Spacer(minLength: 0)
                CrossWatermark(height: crossHeight)
                    .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)

            RopeMark(size: markSize)
                .padding(.trailing, 14)
                .padding(.bottom, 14)
        }
    }
}
