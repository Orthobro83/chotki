import SwiftUI
import ChotkiCore

/// First run, once and never again.
///
/// The words are `Welcome` in core, so this and the other two platforms say the
/// same thing. Android had no first-run screen at all for months — the flag was
/// in the shared settings and nothing on that side read it — and this exists
/// partly so that cannot happen a third time.
struct WelcomeView: View {
    @Bindable var model: Model

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RopeMark(size: 72).padding(.top, 8)

                Text(Welcome.title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Chotki.gold)
                    .accessibilityIdentifier("The welcome")

                ForEach(Array(Welcome.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Paragraph(paragraph)
                }

                Button {
                    withAnimation(.snappy) { model.beginningIsDone() }
                } label: {
                    Text(Welcome.beginLabel)
                        .font(.system(size: 17))
                        .padding(.horizontal, 30).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(Chotki.gold)
                .padding(.top, 6)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .background(Chotki.ground)
    }
}

/// One paragraph, with its links live.
///
/// Built from the spans core hands over rather than parsed out of marked-up
/// text — nothing here has to work out where the links are.
private struct Paragraph: View {
    let paragraph: WelcomeParagraph

    init(_ paragraph: WelcomeParagraph) { self.paragraph = paragraph }

    private var text: AttributedString {
        var whole = AttributedString()
        for span in paragraph.spans {
            var piece = AttributedString(span.text)
            if let url = span.url, let link = URL(string: url) {
                piece.link = link
                piece.foregroundColor = Chotki.gold
                piece.underlineStyle = .single
            }
            whole.append(piece)
        }
        return whole
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if paragraph.isAside {
                Rectangle().fill(Chotki.line).frame(width: 2)
            }
            Text(text)
                .font(.system(size: paragraph.isAside ? 14 : 15))
                .italic(paragraph.isAside)
                .foregroundStyle(paragraph.isAside ? Chotki.faint : Chotki.parchment)
                .tint(Chotki.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The app's mark: a chotki, which is what the name means.
///
/// Drawn from `RopeMarkGeometry` in core — the same numbers the macOS icon and
/// the Android launcher icon use, so all three are one rope at three sizes
/// rather than three drawings of a rope.
struct RopeMark: View {
    var size: CGFloat

    var body: some View {
        Canvas { context, _ in
            let knot = RopeMarkGeometry.knotRadius * size
            for centre in RopeMarkGeometry.knotCentres {
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: centre.x * size - knot, y: centre.y * size - knot,
                        width: knot * 2, height: knot * 2
                    )),
                    with: .color(Chotki.gold)
                )
            }
            let box = RopeMarkGeometry.crossBox
            context.fill(
                OrthodoxCross().path(in: CGRect(
                    x: box.x * size, y: box.y * size,
                    width: box.width * size, height: box.height * size
                )),
                with: .color(Chotki.gold)
            )
        }
        .frame(width: size, height: size)
        .accessibilityLabel("The Chotki mark")
    }
}

/// The eight-pointed cross, filled rather than stroked.
struct OrthodoxCross: Shape {
    func path(in rect: CGRect) -> Path {
        let fitted = CrossGeometry.fitted(
            inX: rect.minX, y: rect.minY, width: rect.width, height: rect.height
        )
        func x(_ u: Double) -> CGFloat { fitted.x + u * fitted.width }
        func y(_ v: Double) -> CGFloat { fitted.y + v * fitted.height }

        var path = Path()
        for bar in CrossGeometry.bars {
            path.addRect(CGRect(
                x: x(bar.x), y: y(bar.y),
                width: bar.width * fitted.width, height: bar.height * fitted.height
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
