import SwiftUI
import ChotkiCore

/// A chotki, for counting the Jesus Prayer.
///
/// The app is named for this. It counts and nothing else: no timing, no record
/// kept, no score. Losing count is not an event worth reporting.
struct PrayerRopeView: View {
    @ObservedObject var model: AppModel
    @State private var count: Int
    @State private var target = 33
    @State private var selection = "jesus-prayer"
    private let sound = SoundPlayer.shared
    @FocusState private var focused: Bool

    private let targets = [33, 50, 100]

    init(model: AppModel, startingAt count: Int = 0) {
        self.model = model
        _count = State(initialValue: count)
    }

    var body: some View {
        VStack(spacing: 0) {
            prayerChooser

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

            knots
                .padding(.horizontal, 22).padding(.bottom, 16)

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

            Text("Click, or press space.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .padding(.top, 7).padding(.bottom, 14)

            Rectangle().fill(Theme.lineSoft).frame(height: 1)

            // The words fill the lower half. A sequence is long, so this
            // scrolls while the count and the rope stay put above it.
            ScrollView {
                RopeWords(selection: selection)
                    .padding(.horizontal, 22).padding(.vertical, 14)
            }
            .scrollContentBackgroundHidden()
            .frame(maxHeight: .infinity)

            Rectangle().fill(Theme.lineSoft).frame(height: 1)

            HStack(spacing: 8) {
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
                Spacer()
                Button { count = 0 } label: {
                    Text("Start again")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22).padding(.bottom, 16)
        }
    }

    /// Which prayer is being said. The rope is for repeating one prayer, so
    /// this is a choice made once and then left alone.
    private var prayerChooser: some View {
        HStack {
            Picker("", selection: $selection) {
                ForEach(PrayerBook.shared.forRope(), id: \.id) { prayer in
                    Text(prayer.title).tag(prayer.id)
                }
                Divider()
                // A rule said through while counting, rather than one prayer
                // repeated. Both are ways the rope is used.
                ForEach(PrayerBook.shared.sequences, id: \.id) { sequence in
                    Text(sequence.title).tag(sequence.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .font(.system(size: 11))
            .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14).padding(.bottom, 2)
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
