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

    @State private var count: Int
    @State private var target = 33
    @State private var selection: String
    /// nil follows the prayer; true or false is the person's own decision.
    @State private var ropeOverride: Bool?

    private let targets = [33, 50, 100]
    /// Chosen when nothing is selected: the rope on its own.
    private static let nothing = "none"

    init(model: AppModel, startingAt count: Int = 0, showing selection: String = "jesus-prayer") {
        self.model = model
        _count = State(initialValue: count)
        _selection = State(initialValue: selection)
    }

    // MARK: what is shown

    /// The rope follows the prayer unless the person has said otherwise.
    private var showsRope: Bool {
        ropeOverride ?? PrayerBook.shared.ropeBelongs(
            with: selection == Self.nothing ? nil : selection
        )
    }

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

            if selection != Self.nothing {
                Rectangle().fill(Theme.lineSoft).frame(height: 1)
                ScrollView {
                    RopeWords(selection: selection)
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
            Text("\(count)")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Theme.gold)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(count >= target ? "the knot is complete" : "of \(target)")
                .font(.system(size: 12))
                .foregroundStyle(count >= target ? Theme.goldDim : Theme.muted)
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
            Picker("", selection: $selection) {
                Text("The rope alone").tag(Self.nothing)
                Divider()
                Section("Rules") {
                    ForEach(PrayerBook.shared.sequences, id: \.id) { sequence in
                        Text(sequence.title).tag(sequence.id)
                    }
                }
                Section("On the rope") {
                    ForEach(book.forRope(), id: \.id) { prayer in
                        Text(prayer.title).tag(prayer.id)
                    }
                }
                Section("Read") {
                    ForEach(book.notForRope(), id: \.id) { prayer in
                        Text(prayer.title).tag(prayer.id)
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
        // Choosing again returns to following the prayer, rather than leaving
        // an earlier decision stuck to everything chosen afterwards.
        .onChange(of: selection) { _ in ropeOverride = nil }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if showsRope {
                ForEach(targets, id: \.self) { value in
                    Button { target = value; count = 0 } label: {
                        Text("\(value)")
                            .font(.system(size: 11))
                            .foregroundStyle(target == value ? Theme.ground : Theme.muted)
                            .frame(width: 42, height: 22)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(target == value ? Theme.gold : Theme.panel)
                            }
                    }
                    .buttonStyle(.plain)
                }
                Button { count = 0 } label: {
                    Text("Start again")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button { ropeOverride = !showsRope } label: {
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
        let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: min(target, 10))
        return LazyVGrid(columns: columns, spacing: 5) {
            ForEach(0..<target, id: \.self) { index in
                Circle()
                    .fill(index < count ? Theme.gold : Theme.panel)
                    .frame(height: 7)
            }
        }
    }

    private func advance() {
        guard count < target else { return }
        count += 1

        // The chime marks completion; the tick only confirms a press landed.
        // Never both at once — with your eyes closed they would run together.
        if count == target {
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
    let selection: String

    @ViewBuilder var body: some View {
        if let sequence = PrayerBook.shared.sequence(id: selection) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(PrayerBook.shared.prayers(of: sequence), id: \.id) { prayer in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(prayer.title)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.gold)
                        ForEach(prayer.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.custom("Cardo", size: 14))
                                .foregroundStyle(Theme.parchment)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let first = PrayerBook.shared.prayers(of: sequence).first {
                    PrayerAttribution(prayer: first)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let prayer = PrayerBook.shared.prayer(id: selection) {
            VStack(spacing: 4) {
                Text(prayer.text)
                    .font(.custom("Cardo", size: 15))
                    .foregroundStyle(Theme.parchment)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                PrayerAttribution(prayer: prayer)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
