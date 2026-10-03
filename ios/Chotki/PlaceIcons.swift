import SwiftUI

/// The bar's icons, drawn rather than taken from SF Symbols.
///
/// The same marks Android draws: a calendar, a rope, an open book, a rising
/// line, and a gear. The glossary's closed book and the library's shelf are
/// the same strokes, offered where the bar does not carry them.
struct PlaceIcon: View {
    var place: Place
    var tint: Color
    var side: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            let width = min(size.width, size.height) * 0.085
            switch place {
            case .rule: Marks.calendar(context, size, tint, width)
            case .prayers: Marks.rope(context, size, tint, width)
            case .reading: Marks.openBook(context, size, tint, width)
            case .progress: Marks.risingLine(context, size, tint, width)
            case .settings: Marks.gear(context, size, tint, width)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

struct LibraryIcon: View {
    var tint: Color
    var side: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            Marks.library(context, size, tint, min(size.width, size.height) * 0.085)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

struct GlossaryIcon: View {
    var tint: Color
    var side: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            Marks.closedBook(context, size, tint, min(size.width, size.height) * 0.085)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// The ground, with the parchment wash off the top left and the gold wash
/// off the lower right. The bar is inset so the gold corner stays visible.
struct ChotkiBackdrop<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Chotki.ground
            Canvas { context, size in
                wash(
                    context, size,
                    center: CGPoint(x: size.width * -0.14, y: size.height * -0.10),
                    radiusX: size.width * 0.60 * 2,
                    radiusY: size.height * 0.29 * 2,
                    color: Chotki.parchment.opacity(0.26),
                    stop: 0.62
                )
                wash(
                    context, size,
                    center: CGPoint(x: size.width * 1.14, y: size.height * 1.12),
                    radiusX: size.width * 0.50 * 2,
                    radiusY: size.height * 0.26 * 2,
                    color: Chotki.gold.opacity(0.22),
                    stop: 0.58
                )
            }
            .allowsHitTesting(false)
            content()
        }
    }
}

private func wash(
    _ context: GraphicsContext, _ size: CGSize,
    center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, color: Color, stop: CGFloat
) {
    guard radiusX > 0, radiusY > 0 else { return }
    let gradient = Gradient(stops: [
        .init(color: color, location: 0),
        .init(color: color.opacity(0), location: stop),
    ])
    var mark = context
    mark.translateBy(x: center.x, y: center.y)
    mark.scaleBy(x: radiusX / radiusY, y: 1)
    mark.fill(
        Path(ellipseIn: CGRect(x: -radiusY, y: -radiusY, width: radiusY * 2, height: radiusY * 2)),
        with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: radiusY)
    )
}

enum Marks {
    static func calendar(_ context: GraphicsContext, _ size: CGSize, _ tint: Color, _ width: CGFloat) {
        let w = size.width
        let inset = w * 0.12
        let rect = CGRect(x: inset, y: w * 0.22, width: w - inset * 2, height: w * 0.66)
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        context.stroke(Path(roundedRect: rect, cornerRadius: w * 0.08), with: .color(tint), style: style)
        var line = Path()
        line.move(to: CGPoint(x: inset, y: w * 0.42))
        line.addLine(to: CGPoint(x: w - inset, y: w * 0.42))
        context.stroke(line, with: .color(tint), style: style)
        for x in [w * 0.33, w * 0.67] {
            var ring = Path()
            ring.move(to: CGPoint(x: x, y: w * 0.1))
            ring.addLine(to: CGPoint(x: x, y: w * 0.28))
            context.stroke(ring, with: .color(tint), style: style)
        }
    }

    static func rope(_ context: GraphicsContext, _ size: CGSize, _ tint: Color, _ width: CGFloat) {
        let centre = CGPoint(x: size.width / 2, y: size.height * 0.54)
        let radius = min(size.width, size.height) * 0.34
        let knots = 9
        for index in 0..<knots {
            let angle = -Double.pi / 2 + Double(index) * (2 * Double.pi / Double(knots))
            let point = CGPoint(
                x: centre.x + CGFloat(cos(angle)) * radius,
                y: centre.y + CGFloat(sin(angle)) * radius
            )
            let knot = width * 0.95
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - knot, y: point.y - knot, width: knot * 2, height: knot * 2)),
                with: .color(tint)
            )
        }
        var tassel = Path()
        tassel.move(to: CGPoint(x: centre.x, y: centre.y - radius))
        tassel.addLine(to: CGPoint(x: centre.x, y: size.height * 0.08))
        context.stroke(
            tassel, with: .color(tint),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    static func openBook(_ context: GraphicsContext, _ size: CGSize, _ tint: Color, _ width: CGFloat) {
        let w = size.width
        let h = size.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
        path.addCurve(
            to: CGPoint(x: w * 0.1, y: h * 0.22),
            control1: CGPoint(x: w * 0.34, y: h * 0.16),
            control2: CGPoint(x: w * 0.2, y: h * 0.18)
        )
        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.78))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.84),
            control1: CGPoint(x: w * 0.24, y: h * 0.72),
            control2: CGPoint(x: w * 0.38, y: h * 0.74)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.9, y: h * 0.78),
            control1: CGPoint(x: w * 0.62, y: h * 0.74),
            control2: CGPoint(x: w * 0.76, y: h * 0.72)
        )
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.22))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.28),
            control1: CGPoint(x: w * 0.8, y: h * 0.18),
            control2: CGPoint(x: w * 0.66, y: h * 0.16)
        )
        path.closeSubpath()
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(tint), style: style)
        var spine = Path()
        spine.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
        spine.addLine(to: CGPoint(x: w * 0.5, y: h * 0.84))
        context.stroke(spine, with: .color(tint), style: style)
    }

    static func risingLine(_ context: GraphicsContext, _ size: CGSize, _ tint: Color, _ width: CGFloat) {
        let w = size.width
        let h = size.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.12, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.46))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.62))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.24))
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        context.stroke(path, with: .color(tint), style: style)
        var base = Path()
        base.move(to: CGPoint(x: w * 0.12, y: h * 0.86))
        base.addLine(to: CGPoint(x: w * 0.88, y: h * 0.86))
        context.stroke(base, with: .color(tint), style: style)
    }

    static func closedBook(_ context: GraphicsContext, _ size: CGSize, _ tint: Color, _ width: CGFloat) {
        let w = size.width
        let h = size.height
        let rect = CGRect(x: w * 0.2, y: h * 0.14, width: w * 0.62, height: h * 0.72)
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        context.stroke(Path(roundedRect: rect, cornerRadius: w * 0.06), with: .color(tint), style: style)
        var spine = Path()
        spine.move(to: CGPoint(x: w * 0.34, y: h * 0.14))
        spine.addLine(to: CGPoint(x: w * 0.34, y: h * 0.86))
        context.stroke(spine, with: .color(tint), style: style)
    }

    static func gear(_ context: GraphicsContext, _ size: CGSize, _ tint: Color, _ width: CGFloat) {
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.22
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        context.stroke(
            Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(tint), style: style
        )
        let inner = radius * 0.38
        context.stroke(
            Path(ellipseIn: CGRect(x: centre.x - inner, y: centre.y - inner, width: inner * 2, height: inner * 2)),
            with: .color(tint), style: style
        )
        for tooth in 0..<8 {
            let angle = CGFloat(tooth) * (.pi / 4)
            var spoke = Path()
            spoke.move(to: CGPoint(x: centre.x + cos(angle) * radius * 1.05, y: centre.y + sin(angle) * radius * 1.05))
            spoke.addLine(to: CGPoint(x: centre.x + cos(angle) * radius * 1.55, y: centre.y + sin(angle) * radius * 1.55))
            context.stroke(spoke, with: .color(tint), style: style)
        }
    }

    static func library(_ context: GraphicsContext, _ size: CGSize, _ tint: Color, _ width: CGFloat) {
        let w = size.width
        let foot = w * 0.84
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        func spine(_ left: CGFloat, _ top: CGFloat) {
            let wide = w * 0.15
            let rect = CGRect(x: left, y: top, width: wide, height: foot - top)
            context.stroke(Path(rect), with: .color(tint), style: style)
            let band = top + (foot - top) * 0.30
            var line = Path()
            line.move(to: CGPoint(x: left, y: band))
            line.addLine(to: CGPoint(x: left + wide, y: band))
            context.stroke(line, with: .color(tint), style: style)
        }
        spine(w * 0.14, w * 0.28)
        spine(w * 0.36, w * 0.18)
        var lean = Path()
        lean.move(to: CGPoint(x: w * 0.60, y: foot))
        lean.addLine(to: CGPoint(x: w * 0.71, y: w * 0.24))
        lean.addLine(to: CGPoint(x: w * 0.85, y: w * 0.29))
        lean.addLine(to: CGPoint(x: w * 0.74, y: foot))
        lean.closeSubpath()
        context.stroke(lean, with: .color(tint), style: style)
        var band = Path()
        band.move(to: CGPoint(x: w * 0.665, y: w * 0.44))
        band.addLine(to: CGPoint(x: w * 0.805, y: w * 0.49))
        context.stroke(band, with: .color(tint), style: style)
    }
}
