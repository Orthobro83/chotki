import SwiftUI
import ChotkiCore

/// The prayers a rule carries, in the order they are said.
struct PrayersView: View {
    @Bindable var model: Model
    let ruleID: UUID

    private var rule: Rule? { model.rules.first { $0.id == ruleID } }

    private var prayers: [Prayer] {
        PrayerBook.shared.prayers(rule?.prayerIDs ?? [])
    }

    /// Scanned as one document rather than prayer by prayer, so "Amen" is not
    /// linked at the end of every one of them.
    private var found: [[[TermMatch]]] {
        Glossary.shared(for: model.settings.jurisdiction.tradition)
            .scanOnce(across: prayers.map(\.paragraphs))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if prayers.isEmpty {
                    Text("This rule carries no text of its own.")
                        .foregroundStyle(Chotki.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    let matches = found
                    ForEach(Array(prayers.enumerated()), id: \.element.id) { index, prayer in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(prayer.title)
                                .font(Chotki.reading(13))
                                .foregroundStyle(Chotki.gold)
                            if let rubric = prayer.rubric {
                                Text(rubric).font(.system(size: 12)).italic()
                                    .foregroundStyle(Chotki.faint)
                            }
                            PrayerProse(
                                model: model, paragraphs: prayer.paragraphs,
                                matches: matches[index]
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let first = prayers.first { PrayerAttribution(prayer: first) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Chotki.ground)
        .navigationTitle(rule?.title ?? "Prayers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The prayers, and the rope where the rope belongs.
///
/// This screen shipped showing a picker of rope prayers and nothing else — no
/// rules, none of the prayers that are read rather than counted, and no text of
/// any prayer anywhere on it. Which is the Android failure again: a screen that
/// draws correctly and carries a fraction of what the Mac carries. What is on
/// offer comes from `PrayerBook` here, so it cannot fall behind it again.
///
/// The rope follows the prayer — a hundred Jesus Prayers are counted, the
/// Creed is not — and the reader can overrule that either way. Both decisions
/// belong to core's `PrayerScreen`, which is why this holds none of them.
struct RopeView: View {
    @Bindable var model: Model
    @Environment(\.pushRoute) private var pushRoute

    private var book: PrayerBook {
        PrayerBook.shared.scoped(to: model.settings.jurisdiction.tradition)
    }

    private var showsRope: Bool { model.prayers.showsRope() }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    chooser
                    if showsRope { rope }
                    words
                }
                .frame(maxWidth: .infinity)
            }
            // "Start again" sits at the far corner from the Count button, so it is not pressed by
            // accident while counting.
            HStack(spacing: 0) {
                GlossaryOfTerms { pushRoute(.term(slug: nil)) }
                if showsRope {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { model.prayers.startAgain() }
                    } label: {
                        Text("Start again")
                            .font(Chotki.reading(12))
                            .foregroundStyle(Chotki.muted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Chotki.ground)
        .navigationTitle("Prayers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { ropeToggle }
        }
    }

    /// In the bar rather than under the text.
    ///
    /// It sat at the foot of the scroll first, which is where macOS keeps it —
    /// but macOS keeps it in a popover with a fixed footer, and here the
    /// morning prayers are eleven prayers long. A control you have to read a
    /// whole rule to reach is one nobody finds.
    private var ropeToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { model.prayers.showRope(!showsRope) }
        } label: {
            Text(showsRope ? "Hide rope" : "Show rope").font(.footnote)
        }
        .tint(Chotki.gold)
        .accessibilityHint("The rope follows the prayer unless you say otherwise")
    }

    /// What is being prayed. Grouped, because a rule said through and a prayer
    /// repeated are different things done with the same screen.
    private var chooser: some View {
        Picker("Prayer", selection: chosen) {
            Text("The rope alone").tag(String?.none)
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
        .pickerStyle(.menu)
        .font(Chotki.reading(17))
        .tint(Chotki.gold)
        .padding(.top, 8)
    }

    /// Writes through `PrayerScreen.choose`, which is what clears an earlier
    /// decision about the rope.
    private var chosen: Binding<String?> {
        Binding(
            get: { model.prayers.selection },
            set: { selection in
                withAnimation(.snappy(duration: 0.22)) { model.prayers.choose(selection) }
            }
        )
    }

    private var rope: some View {
        VStack(spacing: 10) {
            ropeCircle

            Button { advance() } label: {
                Text("Count").font(.system(size: 19))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(Chotki.gold)
            .padding(.top, 4)

            HStack(spacing: 8) {
                ForEach(PrayerScreen.targets, id: \.self) { value in
                    Button("\(value)") {
                        withAnimation(.snappy(duration: 0.2)) { model.prayers.aim(at: value) }
                    }
                    .buttonStyle(.bordered)
                    .tint(model.prayers.target == value ? Chotki.gold : Chotki.muted)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// The knots as a ring, with the count in the middle. The ring is the rope;
    /// nothing hangs from it.
    private var ropeCircle: some View {
        ZStack {
            RopeCircle(count: model.prayers.count, target: model.prayers.target)
            VStack(spacing: 2) {
                Text("\(model.prayers.count)")
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .foregroundStyle(Chotki.gold)
                    .contentTransition(.numericText(value: Double(model.prayers.count)))
                    .animation(.snappy(duration: 0.2), value: model.prayers.count)
                Text(model.prayers.isComplete ? "the knot is complete" : "of \(model.prayers.target)")
                    .font(.footnote)
                    .foregroundStyle(model.prayers.isComplete ? Chotki.goldDim : Chotki.muted)
            }
        }
        .frame(width: Self.ringDiameter, height: Self.ringDiameter)
        .contentShape(Circle())
        .onTapGesture { advance() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prayer rope, \(model.prayers.count) of \(model.prayers.target) knots counted")
        .accessibilityAddTraits(.isButton)
        .frame(maxWidth: .infinity)
        .padding(.top, 4).padding(.bottom, 6)
    }

    private static let ringDiameter: CGFloat = 260

    /// The words themselves. Absent entirely before this — the screen offered a
    /// prayer to choose and then never showed it.
    @ViewBuilder
    private var words: some View {
        if let selection = model.prayers.selection {
            RopeWords(model: model, selection: selection)
                .padding(.horizontal, 18)
                .padding(.top, showsRope ? 6 : 12)
        } else {
            Text("The words by heart, and the rope to keep the count.")
                .font(.footnote)
                .foregroundStyle(Chotki.faint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30).padding(.top, 8)
        }
    }

    private func advance() {
        let before = model.prayers.count
        let completed = model.prayers.advance()
        guard model.prayers.count != before else { return }

        // The chime marks completion; the tick only confirms a press landed.
        // Never both at once — with your eyes closed they would run together.
        // Neither is applause: the app does not congratulate anyone for
        // praying, and the bell is the sound a rope makes.
        if completed {
            if model.settings.chimeOnCompletion { Sound.shared.playBell() }
            // Only the Jesus Prayer, and only while it is the prayer open.
            if model.prayers.selection == "jesus-prayer" {
                model.entries(on: model.selectedDate)
                    .filter {
                        $0.rule.ropePrayerID == "jesus-prayer" || $0.rule.title == "The Jesus Prayer"
                    }
                    .forEach(model.markKept)
            }
        } else if model.settings.tickEachKnot {
            // A tock where a bead sits on the rope, a tick everywhere else.
            if model.prayers.cue == .tock { Sound.shared.playTock() } else { Sound.shared.playTick() }
        }
    }
}

/// What the rope shows: one short prayer, or a whole rule said through.
struct RopeWords: View {
    let model: Model
    let selection: String

    @ViewBuilder var body: some View {
        if let sequence = PrayerBook.shared.sequence(id: selection) {
            // A rule is read straight through, so it is scanned as one
            // document: otherwise "Amen" is linked at the end of every prayer.
            let prayers = PrayerBook.shared.prayers(of: sequence)
            let found = Glossary
                .shared(for: model.settings.jurisdiction.tradition)
                .scanOnce(across: prayers.map(\.paragraphs))

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(prayers.enumerated()), id: \.element.id) { index, prayer in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(prayer.title)
                            .font(Chotki.reading(13))
                            .foregroundStyle(Chotki.gold)
                        if let rubric = prayer.rubric {
                            Text(rubric).font(.system(size: 12)).italic()
                                .foregroundStyle(Chotki.faint)
                        }
                        PrayerProse(
                            model: model, paragraphs: prayer.paragraphs,
                            size: 17, matches: found[index]
                        )
                        PrayerAttribution(prayer: prayer)
                    }
                }
                if selection == "morning" || selection == "evening" {
                    // Reaching the last line marks the rule. Opening the prayers does not.
                    ReadingEnd(identity: "rope-\(selection)-\(model.selectedDate.iso)") {
                        let title = selection == "morning" ? "Morning prayers" : "Evening prayers"
                        model.entries(on: model.selectedDate)
                            .filter { $0.rule.title == title }
                            .forEach(model.markKept)
                    }
                    .frame(height: 1)
                    .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let prayer = PrayerBook.shared.prayer(id: selection) {
            VStack(spacing: 6) {
                if let rubric = prayer.rubric {
                    Text(rubric).font(.system(size: 12)).italic()
                        .foregroundStyle(Chotki.faint)
                }
                PrayerProse(
                    model: model, paragraphs: prayer.paragraphs,
                    size: 17, centred: true
                )
                PrayerAttribution(prayer: prayer)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// The rope as a ring of knots: counted ones filled, the next one ringed in
/// gold, the rest left as outlines. Where each sits comes from core.
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
                    context.fill(path, with: .color(Chotki.gold))
                } else if index == count {
                    context.fill(path, with: .color(Chotki.panel))
                    context.stroke(path, with: .color(Chotki.gold), lineWidth: max(1.2, dot * 0.28))
                } else {
                    context.fill(path, with: .color(Chotki.panel))
                    context.stroke(path, with: .color(Chotki.faint.opacity(0.55)), lineWidth: max(0.7, dot * 0.14))
                }
            }
            // A bead after every tenth knot: larger, and red, as the liturgy days are. Dimmer until passed.
            for (index, centre) in layout.beads.enumerated() {
                let passed = layout.beadHasBeenPassed(index, count: count)
                context.fill(Path(ellipseIn: rect(centre, layout.bead)), with: .color(Chotki.ochre.opacity(passed ? 1 : 0.55)))
            }
        }
        .allowsHitTesting(false)
    }
}
