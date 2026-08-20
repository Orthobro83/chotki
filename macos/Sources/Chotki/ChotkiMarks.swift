import SwiftUI

/// The eight-pointed cross, as a path rather than an image.
///
/// Same proportions as the menu bar icon, so the two cannot drift apart. Drawn
/// with strokes rather than filled shapes, which keeps it legible at both the
/// large faint size used as a watermark and the small one used in the mark.
struct OrthodoxCross: Shape {
    /// Drawn in a 14 × 18 space and scaled to fit.
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / 14, rect.height / 18)
        let dx = rect.midX - 7 * s
        let dy = rect.midY - 9 * s

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: dx + x * s, y: dy + y * s)
        }

        var path = Path()
        path.move(to: point(7, 1.2)); path.addLine(to: point(7, 16.8))       // upright
        path.move(to: point(4.6, 3.4)); path.addLine(to: point(9.4, 3.4))    // titulus
        path.move(to: point(1.6, 6.8)); path.addLine(to: point(12.4, 6.8))   // crossbar
        path.move(to: point(3.4, 13.0)); path.addLine(to: point(10.6, 10.8)) // footrest
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
            .stroke(Theme.parchment, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: height * 14 / 18, height: height)
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
                x: centre.x - crossHeight * 14 / 18 / 2,
                y: centre.y + radius - knotRadius,
                width: crossHeight * 14 / 18,
                height: crossHeight
            )
            context.stroke(
                OrthodoxCross().path(in: crossRect),
                with: .color(Theme.gold),
                style: StrokeStyle(lineWidth: max(1, size * 0.038), lineCap: .round)
            )
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
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Anchored to the bottom, where the space actually is. Centred, it
            // struck through the calendar and read as stray lines rather than
            // as a cross.
            VStack {
                Spacer(minLength: 0)
                CrossWatermark(height: 96)
                    .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)

            RopeMark(size: 30)
                .padding(.trailing, 14)
                .padding(.bottom, 14)
        }
    }
}
