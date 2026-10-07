import SwiftUI
import ChotkiCore

/// The prayers, and the rope.
///
/// Named for the app, and the reason for it. The rope is shown when the chosen
/// prayer is one traditionally counted on it — the Jesus Prayer and its kin —
/// and hidden when the chosen thing is read instead, like the morning rule.
/// Choosing nothing shows the rope, for someone who has the prayer by heart and
/// only wants somewhere to keep the count.
///
/// A person can always overrule that. The judgement about which prayers are
/// counted belongs to the tradition, not to this app, and someone's practice
/// may differ from what is written here.
struct PrayerRopeView: View {
    @ObservedObject var model: AppModel
    /// Width and height of the circle of knots. The window has room for a
    /// larger one than the menu bar popover.
    var diameter: CGFloat = 190

    private var screen: PrayerScreen { model.prayers }
    private var showsRope: Bool { screen.showsRope() }

    var body: some View {
        VStack(spacing: 0) {
            prayerChooser

            if showsRope {
                ropeCircle
                countButton
                Text("Click, or press space.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 7).padding(.bottom, 14)
            }

            if let selection = screen.selection {
                Rectangle().fill(Theme.lineSoft).frame(height: 1)
                ScrollView {
                    RopeWords(model: model, selection: selection)
                        .frame(maxWidth: 760).frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 18)
                    ReadingEnd(identity: "\(selection)-\(model.selectedDate.iso)") {
                        model.finishPrayer(selection, counted: false)
                    }.frame(height: 1)
                    Color.clear.frame(height: 24).chotkiScrollContent()
                }
                .scrollContentBackgroundHidden()
                .frame(maxHeight: .infinity)
                .softVerticalScrollEdges()
            } else {
                Spacer(minLength: 0)
            }

            Rectangle().fill(Theme.lineSoft).frame(height: 1)
            footer
        }
        .animation(.easeInOut(duration: 0.2), value: showsRope)
    }

    /// The knots as a ring, with the count in the middle. The ring is the
    /// rope; nothing hangs from it. "Start again" waits in the corner, where it
    /// is findable and cannot be pressed by accident while counting.
    private var ropeCircle: some View {
        ZStack {
            RopeCircle(count: screen.count, target: screen.target)
            counter
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .onTapGesture { advance() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prayer rope, \(screen.count) of \(screen.target) knots counted")
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button { model.prayers.startAgain() } label: {
                Text("Start again")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 22)
        }
        .padding(.top, 4).padding(.bottom, 14)
    }

    private var counter: some View {
        VStack(spacing: 2) {
            Text("\(screen.count)")
                .font(.system(size: diameter * 0.28, weight: .light))
                .foregroundStyle(Theme.gold)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(screen.isComplete ? "the knot is complete" : "of \(screen.target)")
                .font(.system(size: 13))
                .foregroundStyle(screen.isComplete ? Theme.goldDim : Theme.muted)
        }
    }

    private var countButton: some View {
        Button { advance() } label: {
            Text("Count")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.gold))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.space, modifiers: [])
        .padding(.horizontal, 22)
    }

    /// What is being prayed. Grouped, because a rule said through and a prayer
    /// repeated are different things done with the same screen.
    private var prayerChooser: some View {
        let book = PrayerBook.shared.scoped(to: model.settings.jurisdiction.tradition)
        return HStack {
            Picker("", selection: chosen) {
                Text("The rope alone").tag(String?.none)
                // No Divider here: each Section draws its own, and the two
                // together put a double rule under the first item.
                Section("Rules") {
                    ForEach(PrayerBook.shared.sequences, id: \.id) { sequence in
                        Text(sequence.title).tag(String?.some(sequence.id))
                    }
                }
                Section("On the rope") {
                    ForEach(book.forRope(), id: \.id) { prayer in
                        Text(prayer.title).tag(String?.some(prayer.id))
                    }
                }
                Section("Read") {
                    ForEach(book.notForRope(), id: \.id) { prayer in
                        Text(prayer.title).tag(String?.some(prayer.id))
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .font(.system(size: 15))
            .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14).padding(.bottom, 10)
    }

    /// Writes through `PrayerScreen.choose`, which is what clears an earlier
    /// decision about the rope.
    private var chosen: Binding<String?> {
        Binding(get: { model.prayers.selection }, set: { model.prayers.choose($0) })
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if showsRope {
                ForEach(PrayerScreen.targets, id: \.self) { value in
                    Button { model.prayers.aim(at: value) } label: {
                        Text("\(value)")
                            .font(.system(size: 15))
                            .foregroundStyle(screen.target == value ? Theme.ground : Theme.muted)
                            .frame(width: 42, height: 22)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(screen.target == value ? Theme.gold : Theme.panel)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button { model.prayers.showRope(!showsRope) } label: {
                Text(showsRope ? "Hide rope" : "Show rope")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.gold)
            }
            .buttonStyle(.plain)
            .help("The rope follows the prayer unless you say otherwise")
        }
        .frame(maxWidth: 760).frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 18)
    }

    private func advance() {
        let wasCounted = model.prayers.count
        let completed = model.prayers.advance()
        guard model.prayers.count != wasCounted else { return }

        // The chime marks completion; the tick only confirms a press landed.
        // Never both at once — with your eyes closed they would run together.
        if completed {
            if let selection = screen.selection { model.finishPrayer(selection, counted: true) }
            if model.settings.chimeOnCompletion { sound.playBell() }
        } else if model.settings.tickEachKnot {
            // A tock where a bead sits on the rope, a tick everywhere else.
            if screen.cue == .tock { sound.playTock() } else { sound.playTick() }
        }
    }

    private let sound = SoundPlayer.shared
}

/// What the rope shows: one short prayer, or a whole rule said through.
///
/// Its own view so it can be drawn without the scroll view around it —
/// ImageRenderer does not draw ScrollView contents, and a view that cannot be
/// looked at is one that gets shipped broken.
struct RopeWords: View {
    @ObservedObject var model: AppModel
    let selection: String

    @ViewBuilder var body: some View {
        if let sequence = PrayerBook.shared.sequence(id: selection) {
            // A rule is read straight through, so it is scanned as one document:
            // otherwise "Amen" is linked at the end of every prayer in it.
            let prayers = PrayerBook.shared.prayers(of: sequence)
            let found = Glossary
                .shared(for: model.settings.jurisdiction.tradition)
                .scanOnce(across: prayers.map(\.paragraphs))

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(prayers.enumerated()), id: \.element.id) { index, prayer in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(prayer.title)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.gold)
                        if let rubric = prayer.rubric {
                            Text(rubric)
                                .font(.system(size: 12)).italic()
                                .foregroundStyle(Theme.faint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        PrayerProse(
                            model: model, paragraphs: prayer.paragraphs,
                            size: 18, spacing: 6, matches: found[index]
                        )
                        PrayerAttribution(prayer: prayer)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let prayer = PrayerBook.shared.prayer(id: selection) {
            VStack(spacing: 4) {
                PrayerProse(
                    model: model, paragraphs: prayer.paragraphs,
                    size: 20, spacing: 6, centred: true
                )
                PrayerAttribution(prayer: prayer)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// The rope as a ring of knots: counted ones filled, the next one ringed in
/// gold, the rest left as outlines.
struct RopeCircle: View {
    let count: Int
    let target: Int

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let layout = RopeCircleLayout.layout(count: target, diameter: Double(side))
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            func rect(_ centre: RopeCircleLayout.Point, _ size: Double) -> CGRect {
                CGRect(x: origin.x + CGFloat(centre.x - size / 2), y: origin.y + CGFloat(centre.y - size / 2),
                       width: CGFloat(size), height: CGFloat(size))
            }
            let dot = CGFloat(layout.dot)
            for (index, centre) in layout.knots.enumerated() {
                let path = Path(ellipseIn: rect(centre, layout.dot))
                if index < count {
                    context.fill(path, with: .color(Theme.gold))
                } else if index == count {
                    context.fill(path, with: .color(Theme.panel))
                    context.stroke(path, with: .color(Theme.gold), lineWidth: max(1.2, dot * 0.28))
                } else {
                    context.fill(path, with: .color(Theme.panel))
                    context.stroke(path, with: .color(Theme.faint.opacity(0.55)), lineWidth: max(0.7, dot * 0.14))
                }
            }
            // A bead after every tenth knot: larger, and red, as the liturgy days are. Dimmer until passed.
            for (index, centre) in layout.beads.enumerated() {
                let passed = layout.beadHasBeenPassed(index, count: count)
                context.fill(Path(ellipseIn: rect(centre, layout.bead)), with: .color(Theme.ochre.opacity(passed ? 1 : 0.55)))
            }
        }
        .allowsHitTesting(false)
    }
}
