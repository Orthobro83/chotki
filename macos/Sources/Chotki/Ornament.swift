import SwiftUI

/// A border for the pages that carry received text.
///
/// The same drawing as `Ornament.kt` on Android, to the value: the two are one
/// application, and a person who keeps their rule on both should not find the
/// prayers framed differently on each.
///
/// Ryan's reference is a scanned ornament printed in black on white. On this
/// ground black is nothing at all, so it is redrawn in the app's own parchment
/// at low opacity. The motif is his: arrowhead, diamond, arrowhead, running
/// between two hairlines, with a knot where the two arms meet.
///
/// Four corner pieces rather than a frame, which is what the reference is and
/// the better reading of it: a continuous band closes a page in like a
/// certificate, where corners suggest the border and leave the page open. The
/// rules that run between them fade out at both ends rather than butting into
/// the knot.
struct VenerationBorder: View {
    var colour: Color = Theme.parchment
    var opacity: Double = VenerationBorder.present

    /// What Ryan chose: present when you look for it, gone while you read.
    static let present = 0.11

    /// How far the ornament sits from the edge of the page. The text is held
    /// further in again by its own margin.
    static let inset: CGFloat = 14

    private static let arm: CGFloat = 74
    private static let band: CGFloat = 11
    private static let tile: CGFloat = 16
    private static let knot: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            let ink = colour.opacity(opacity)
            let inset = Self.inset
            let left = inset, top = inset
            let right = size.width - inset, bottom = size.height - inset

            // Only draw arms that fit. On a short pane they would otherwise
            // overlap in the middle and read as a solid box.
            let armX = min(Self.arm, (right - left) / 2 - 8)
            let armY = min(Self.arm, (bottom - top) / 2 - 8)
            guard armX > 0, armY > 0 else { return }

            corner(context, at: CGPoint(x: left, y: top), sx: 1, sy: 1, armX: armX, armY: armY, ink: ink)
            corner(context, at: CGPoint(x: right, y: top), sx: -1, sy: 1, armX: armX, armY: armY, ink: ink)
            corner(context, at: CGPoint(x: left, y: bottom), sx: 1, sy: -1, armX: armX, armY: armY, ink: ink)
            corner(context, at: CGPoint(x: right, y: bottom), sx: -1, sy: -1, armX: armX, armY: armY, ink: ink)

            edge(context, from: CGPoint(x: left + armX, y: top),
                 to: CGPoint(x: right - armX, y: top), ink: ink)
            edge(context, from: CGPoint(x: left + armX, y: bottom),
                 to: CGPoint(x: right - armX, y: bottom), ink: ink)
            edge(context, from: CGPoint(x: left, y: top + armY),
                 to: CGPoint(x: left, y: bottom - armY), ink: ink)
            edge(context, from: CGPoint(x: right, y: top + armY),
                 to: CGPoint(x: right, y: bottom - armY), ink: ink)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// `sx` and `sy` are ±1 and mirror the whole piece, so one drawing serves
    /// all four corners without four sets of coordinates to keep in step.
    private func corner(
        _ context: GraphicsContext, at origin: CGPoint,
        sx: CGFloat, sy: CGFloat, armX: CGFloat, armY: CGFloat, ink: Color
    ) {
        var here = context
        here.translateBy(x: origin.x, y: origin.y)
        here.scaleBy(x: sx, y: sy)

        arm(here, length: armX, ink: ink)

        // The second arm is the first reflected in the line y = x.
        var turned = here
        turned.transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
            .concatenating(here.transform)
        arm(turned, length: armY, ink: ink)

        knot(here, ink: ink)
    }

    /// One arm: two hairlines with the motif repeating between them.
    private func arm(_ context: GraphicsContext, length: CGFloat, ink: Color) {
        let band = Self.band, tile = Self.tile, start = Self.knot, hair: CGFloat = 0.9
        guard length > start else { return }

        context.fill(
            Path(CGRect(x: start, y: 0, width: length - start, height: hair)),
            with: .color(ink))
        context.fill(
            Path(CGRect(x: start, y: band - hair, width: length - start, height: hair)),
            with: .color(ink))

        var x = start
        let middle = band / 2
        while x + tile <= length {
            var path = Path()
            path.move(to: CGPoint(x: x + tile / 2, y: middle - tile * 0.23))
            path.addLine(to: CGPoint(x: x + tile * 0.72, y: middle))
            path.addLine(to: CGPoint(x: x + tile / 2, y: middle + tile * 0.23))
            path.addLine(to: CGPoint(x: x + tile * 0.28, y: middle))
            path.closeSubpath()

            path.move(to: CGPoint(x: x, y: middle))
            path.addLine(to: CGPoint(x: x + tile * 0.17, y: middle - tile * 0.105))
            path.addLine(to: CGPoint(x: x + tile * 0.17, y: middle + tile * 0.105))
            path.closeSubpath()

            path.move(to: CGPoint(x: x + tile, y: middle))
            path.addLine(to: CGPoint(x: x + tile * 0.83, y: middle - tile * 0.105))
            path.addLine(to: CGPoint(x: x + tile * 0.83, y: middle + tile * 0.105))
            path.closeSubpath()

            context.fill(path, with: .color(ink))
            x += tile
        }
    }

    /// The knot: an outlined diamond with a ring inside it. A filled centre
    /// reads as a blob at this size.
    private func knot(_ context: GraphicsContext, ink: Color) {
        let k = Self.knot
        let c = k / 2

        func diamond(_ radius: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: c, y: c - radius))
            path.addLine(to: CGPoint(x: c + radius, y: c))
            path.addLine(to: CGPoint(x: c, y: c + radius))
            path.addLine(to: CGPoint(x: c - radius, y: c))
            path.closeSubpath()
            return path
        }

        context.stroke(diamond(c - 0.6), with: .color(ink), lineWidth: 1)
        context.stroke(diamond(c * 0.58), with: .color(ink), lineWidth: 1.6)
    }

    /// A hairline that fades in from nothing and back to nothing.
    private func edge(
        _ context: GraphicsContext, from: CGPoint, to: CGPoint, ink: Color
    ) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: ink, location: 0.22),
                    .init(color: ink, location: 0.78),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: from, endPoint: to),
            lineWidth: 0.9)
    }
}

/// Where scrolling text goes to disappear.
///
/// The ornament is drawn over the words, so a line arriving at the top of the
/// page crossed the border and sat on top of it for a moment before leaving.
/// It comes out from behind it instead.
///
/// A band of the page's own ground at each end, solid at the very edge and
/// gone by the time it is clear of the band, drawn under the ornament and over
/// the text. Nothing is clipped and nothing reflows: the text keeps the full
/// height of the page and simply dissolves before it reaches the frame.
struct EdgeFade: View {
    var ground: Color = Theme.ground
    var depth: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: ground, location: 0),
                    .init(color: ground, location: 0.55),
                    .init(color: ground.opacity(0), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
                .frame(height: depth)

            Spacer(minLength: 0)

            LinearGradient(
                stops: [
                    .init(color: ground.opacity(0), location: 0),
                    .init(color: ground, location: 0.45),
                    .init(color: ground, location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
                .frame(height: depth)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
