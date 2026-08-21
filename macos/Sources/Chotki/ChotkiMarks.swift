import SwiftUI
import ChotkiCore

extension CrossGeometry {
    /// Drawing-side convenience. The proportions themselves live in core.
    static func fitted(in rect: CGRect) -> CGRect {
        let box = fitted(
            inX: rect.minX, y: rect.minY, width: rect.width, height: rect.height
        )
        return CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
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
        for bar in CrossGeometry.bars {
            path.addRect(CGRect(
                x: x(bar.x), y: y(bar.y),
                width: bar.width * box.width, height: bar.height * box.height
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
