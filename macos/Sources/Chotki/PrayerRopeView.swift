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

    private var screen: PrayerScreen { model.prayers }
    private var showsRope: Bool { screen.showsRope() }

    var body: some View {
        VStack(spacing: 0) {
            prayerChooser

            if showsRope {
                counter
                knots
                    .padding(.horizontal, 22).padding(.bottom, 16)
                countButton
                Text("Click, or press space.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 7).padding(.bottom, 14)
            }

            if let selection = screen.selection {
                Rectangle().fill(Theme.lineSoft).frame(height: 1)
                ScrollView {
                    RopeWords(model: model, selection: selection)
                        .padding(.horizontal, 22).padding(.vertical, 14)
                }
                .scrollContentBackgroundHidden()
                .frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }

            Rectangle().fill(Theme.lineSoft).frame(height: 1)
            footer
        }
        .animation(.easeInOut(duration: 0.2), value: showsRope)
    }

    private var counter: some View {
        VStack(spacing: 4) {
            Text("\(screen.count)")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Theme.gold)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(screen.isComplete ? "the knot is complete" : "of \(screen.target)")
                .font(.system(size: 12))
                .foregroundStyle(screen.isComplete ? Theme.goldDim : Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2).padding(.bottom, 16)
    }

    private var countButton: some View {
        Button { advance() } label: {
            Text("Count")
                .font(.system(size: 13))
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
            .font(.system(size: 11))
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
                            .font(.system(size: 11))
                            .foregroundStyle(screen.target == value ? Theme.ground : Theme.muted)
                            .frame(width: 42, height: 22)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(screen.target == value ? Theme.gold : Theme.panel)
                            }
                    }
                    .buttonStyle(.plain)
                }
                Button { model.prayers.startAgain() } label: {
                    Text("Start again")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button { model.prayers.showRope(!showsRope) } label: {
                Text(showsRope ? "Hide rope" : "Show rope")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
            }
            .buttonStyle(.plain)
            .help("The rope follows the prayer unless you say otherwise")
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }

    /// One dot per knot, filling as it goes.
    private var knots: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: min(screen.target, 10))
        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<screen.target, id: \.self) { index in
                Circle()
                    .fill(index < screen.count ? Theme.gold : Theme.panel)
                    .frame(height: 7)
            }
        }
    }

    private func advance() {
        let wasCounted = model.prayers.count
        let completed = model.prayers.advance()
        guard model.prayers.count != wasCounted else { return }

        // The chime marks completion; the tick only confirms a press landed.
        // Never both at once — with your eyes closed they would run together.
        if completed {
            if model.settings.chimeOnCompletion { sound.playBell() }
        } else if model.settings.tickEachKnot {
            sound.playTick()
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
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.gold)
                        PrayerProse(
                            model: model, paragraphs: prayer.paragraphs,
                            size: 14, spacing: 4, matches: found[index]
                        )
                    }
                }
                if let first = prayers.first {
                    PrayerAttribution(prayer: first)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let prayer = PrayerBook.shared.prayer(id: selection) {
            VStack(spacing: 4) {
                PrayerProse(
                    model: model, paragraphs: prayer.paragraphs,
                    size: 15, spacing: 4, centred: true
                )
                PrayerAttribution(prayer: prayer)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
