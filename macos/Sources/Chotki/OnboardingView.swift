import SwiftUI
import ChotkiCore

/// First run, once and never again.
///
/// This replaced a screen that suggested three rules and let you tick them
/// there and then. That screen and this one both said "start small" in
/// different words, and two screens saying the same thing in different words is
/// worse than one — so the suggestions went and the Library does that job,
/// which is where someone ends up anyway.
///
/// The words are in `Welcome`, in core, so this and the Android screen cannot
/// drift apart.
/// The welcome, once. The rope and the cross are not part of this screen.
/// They play on every cold open, including this first one, and then leave.
struct FirstRunView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        OnboardingView(model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var name = ""
    @State private var church = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 14) {
                Text(Welcome.title)
                    .font(Theme.reading(26))
                    .foregroundStyle(Theme.parchment)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("The welcome")

                ForEach(Array(Welcome.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Paragraph(paragraph)
                }

                Text("What should we call you?")
                    .font(Theme.reading(26))
                    .foregroundStyle(Theme.parchment)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                TextField("First name or Baptismal name.", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.reading(17))
                    .accessibilityLabel("What should we call you?")
                Text(Welcome.churchPrompt)
                    .font(Theme.reading(22))
                    .foregroundStyle(Theme.parchment)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                Picker(Welcome.churchPrompt, selection: $church) {
                    Text(Welcome.noChurchAffiliation).tag("")
                    ForEach(Jurisdiction.known, id: \.name) { jurisdiction in
                        Text(jurisdiction.name).tag(jurisdiction.name)
                    }
                }
                .labelsHidden()
                .accessibilityLabel(Welcome.churchPrompt)
                Button {
                    let chosen = church
                    model.update {
                        $0.hasCompletedFirstRun = true
                        $0.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        $0.chooseChurch(named: chosen.isEmpty ? nil : chosen)
                    }
                    model.notice = nil
                } label: {
                    Text(Welcome.beginLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .buttonStyle(GoldButtonStyle())
                .accessibilityLabel(Welcome.beginLabel)
                .padding(.top, 4)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .softVerticalScrollEdges()
    }
}

/// The mark, on a cold open.
///
/// A quit, a reboot, or any other start from a process that was not running.
/// Returning to an app that is still in memory does not play it. The welcome
/// underneath is a separate question, and it is still asked only once.
///
/// Eleven knots come in from the lower one on the left, around to the lower
/// one on the right. The cross then appears between them. The whole mark eases
/// from 85% to full size over 1.8 seconds, holds, and leaves. The same timing
/// and the same rope as the Android opening.
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The opening")
        .onAppear {
            // A render captures the welcome, not a frame of the mark on its way in.
            let rendering = ProcessInfo.processInfo.environment["CHOTKI_RENDER"] != nil
                || ProcessInfo.processInfo.environment["CHOTKI_RENDER_WINDOW"] != nil
            if reduceMotion || rendering {
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
struct OpeningMarkDrawing: View {
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
                context.fill(Path(ellipseIn: rect), with: .color(Theme.gold.opacity(alpha)))
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
                    with: .color(Theme.gold.opacity(crossAlpha))
                )
            }
        }
        .frame(width: 220, height: 220)
        .scaleEffect(motion.scale)
        .opacity(motion.opacity)
    }
}

/// Plays [OpeningMark] once the view's window is actually on screen.
///
/// The menu-bar popover's view exists before anyone has opened it. Starting
/// the mark there would spend the cold open where nobody can see it, and the
/// window that then appears would have nothing left to play.
struct ColdOpenCurtain: View {
    @ObservedObject var model: AppModel
    @State private var playing = false

    var body: some View {
        ZStack {
            if model.coldOpen && playing {
                OpeningMark { model.coldOpen = false }
                    .background(ChotkiBackdrop())
            }
            WindowBecameVisible {
                if model.coldOpen { playing = true }
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
        }
    }
}

/// Reports when this view's window is on screen, including a window that
/// becomes key after the view has already been installed in it.
private struct WindowBecameVisible: NSViewRepresentable {
    var onVisible: () -> Void

    func makeNSView(context: Context) -> Probe {
        let view = Probe()
        view.onVisible = onVisible
        return view
    }

    func updateNSView(_ nsView: Probe, context: Context) {
        nsView.onVisible = onVisible
    }

    final class Probe: NSView {
        var onVisible: (() -> Void)?
        private var token: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
            guard let window else { return }
            if window.isVisible {
                onVisible?()
                return
            }
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onVisible?() }
            }
        }
    }
}

/// The opening's clock. Android's `OpeningMark` uses these same numbers.
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

    /// Knots are numbered from 1. Index 0 is the gap the cross hangs in.
    static func knotAlpha(ms: Double, index: Int) -> Double {
        let knots = Double(RopeMarkGeometry.knots)
        let start = Double(index - 1) / (knots - 1) * (build * 1000 - 200)
        return min(1, max(0, (ms - start) / 160))
    }

    static func crossAlpha(ms: Double) -> Double {
        min(1, max(0, (ms - (build * 1000 - 160)) / 160))
    }
}

/// One paragraph, with its links live.
///
/// Built as an `AttributedString` from the spans rather than parsed out of
/// marked-up text: core hands over where the links are, so nothing here has to
/// work it out.
private struct Paragraph: View {
    let paragraph: WelcomeParagraph

    init(_ paragraph: WelcomeParagraph) { self.paragraph = paragraph }

    private var text: AttributedString {
        var whole = AttributedString()
        for span in paragraph.spans {
            var piece = AttributedString(span.text)
            if let url = span.url, let link = URL(string: url) {
                piece.link = link
                piece.foregroundColor = Theme.gold
                piece.underlineStyle = .single
            }
            whole.append(piece)
        }
        return whole
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if paragraph.isAside {
                Rectangle().fill(Theme.line).frame(width: 2)
            }
            Text(text)
                .font(Theme.reading(paragraph.isAside ? 13 : 16))
                .italic(paragraph.isAside)
                .foregroundStyle(paragraph.isAside ? Theme.faint : Theme.parchment)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .tint(Theme.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
