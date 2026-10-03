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
    @State private var name: String
    @State private var church: String

    init(model: Model) {
        self.model = model
        _name = State(initialValue: model.settings.displayName)
        _church = State(initialValue: model.settings.namedChurch ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RopeMark(size: 72).padding(.top, 8)

                Text(Welcome.title)
                    .font(Chotki.reading(26))
                    .foregroundStyle(Chotki.parchment)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("The welcome")

                ForEach(Array(Welcome.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Paragraph(paragraph)
                }

                Text("What should we call you?")
                    .font(Chotki.reading(26))
                    .foregroundStyle(Chotki.parchment)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                TextField("First name or Baptismal name.", text: $name)
                    .font(Chotki.reading(17))
                    .foregroundStyle(Chotki.parchment)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Chotki.panel)
                    .accessibilityLabel("What should we call you?")

                Text(Welcome.churchPrompt)
                    .font(Chotki.reading(22))
                    .foregroundStyle(Chotki.parchment)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                Picker(Welcome.churchPrompt, selection: $church) {
                    Text(Welcome.noChurchAffiliation).tag("")
                    ForEach(Jurisdiction.known, id: \.name) { Text($0.name).tag($0.name) }
                }
                .accessibilityLabel(Welcome.churchPrompt)

                Button {
                    let chosen = church
                    let called = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let today = model.today
                    withAnimation(.snappy) {
                        model.update {
                            $0.displayName = called
                            $0.hasCompletedFirstRun = true
                            if $0.firstRunOn == nil { $0.firstRunOn = today }
                            $0.chooseChurch(named: chosen.isEmpty ? nil : chosen)
                        }
                    }
                } label: {
                    Text(Welcome.beginLabel)
                        .font(.system(size: 16))
                        .foregroundStyle(Chotki.ground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Chotki.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .accessibilityLabel(Welcome.beginLabel)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .background(Chotki.ground)
        .tint(Chotki.gold)
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

/// One opening per process.
///
/// A quit or a reboot starts a new process, and this is true again. Returning
/// from the background keeps the process, so it stays false. Touched on the
/// main thread only; it is not actor state because the view's first read
/// happens before the main-actor body.
enum ColdOpen {
    nonisolated(unsafe) static var pending = true
}

/// The rope and the cross, once per process. Not the welcome: that is still
/// asked only once, underneath this.
///
/// The clock matches the Mac `OpeningTiming` and the Android opening: 1.8
/// seconds to draw, 1.5 to hold, 0.4 to leave. Reduced motion skips it.
struct OpeningMark: View {
    var onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: started == nil)) { context in
            let elapsed = started.map { context.date.timeIntervalSince($0) } ?? 0
            OpeningMarkDrawing(elapsed: elapsed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Chotki.ground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The opening")
        .onAppear {
            if reduceMotion {
                DispatchQueue.main.async { onFinished() }
                return
            }
            started = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + OpeningTiming.total) {
                onFinished()
            }
        }
    }
}

/// One frame of the opening. `elapsed` is seconds from the start.
private struct OpeningMarkDrawing: View {
    var elapsed: TimeInterval

    var body: some View {
        let motion = OpeningTiming.frame(at: elapsed)
        Canvas { context, size in
            let side = min(size.width, size.height)
            let left = (size.width - side) / 2
            let top = (size.height - side) / 2
            let knot = RopeMarkGeometry.knotRadius * side
            for (offset, centre) in RopeMarkGeometry.knotCentres.enumerated() {
                let alpha = OpeningTiming.knotAlpha(ms: motion.milliseconds, index: offset + 1)
                guard alpha > 0 else { continue }
                let rect = CGRect(
                    x: left + centre.x * side - knot,
                    y: top + centre.y * side - knot,
                    width: knot * 2, height: knot * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(Chotki.gold.opacity(alpha)))
            }
            let crossAlpha = OpeningTiming.crossAlpha(ms: motion.milliseconds)
            if crossAlpha > 0 {
                let box = RopeMarkGeometry.crossBox
                let rect = CGRect(
                    x: left + box.x * side, y: top + box.y * side,
                    width: box.width * side, height: box.height * side
                )
                context.fill(
                    OrthodoxCross().path(in: rect),
                    with: .color(Chotki.gold.opacity(crossAlpha))
                )
            }
        }
        .frame(width: 220, height: 220)
        .scaleEffect(motion.scale)
        .opacity(motion.opacity)
    }
}

/// The opening's clock. Keep these numbers equal to the Mac `OpeningTiming`
/// and the Android opening. Both copies have a test that fails if they drift.
enum OpeningTiming {
    static let build: TimeInterval = 1.8
    static let hold: TimeInterval = 1.5
    static let fade: TimeInterval = 0.4
    static var total: TimeInterval { build + hold + fade }

    struct Frame {
        var milliseconds: Double
        var scale: CGFloat
        var opacity: Double
    }

    static func frame(at elapsed: TimeInterval) -> Frame {
        let ms = max(0, elapsed) * 1000
        let buildMs = build * 1000
        let holdEnd = (build + hold) * 1000
        let grown = min(1, max(0, ms / buildMs))
        let opacity = ms < holdEnd ? 1 : max(0, 1 - (ms - holdEnd) / (fade * 1000))
        return Frame(milliseconds: ms, scale: 0.85 + 0.15 * grown, opacity: opacity)
    }

    static func knotAlpha(ms: Double, index: Int) -> Double {
        let knots = Double(RopeMarkGeometry.knots)
        let start = Double(index - 1) / (knots - 1) * (build * 1000 - 200)
        return min(1, max(0, (ms - start) / 160))
    }

    static func crossAlpha(ms: Double) -> Double {
        min(1, max(0, (ms - (build * 1000 - 160)) / 160))
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
