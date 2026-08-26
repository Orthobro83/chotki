import SwiftUI
import ChotkiCore

/// The prayers a rule carries, in the order they are said.
struct PrayersView: View {
    @Bindable var model: Model
    let ruleID: UUID

    private var rule: Rule? { model.rules.first { $0.id == ruleID } }

    private var prayers: [Prayer] {
        (rule?.prayerIDs ?? []).compactMap { id in
            PrayerBook.bundled.first { $0.id == id }
        }
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
                    ForEach(prayers) { prayer in PrayerBlock(prayer: prayer) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(Chotki.ground)
        .navigationTitle(rule?.title ?? "Prayers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrayerBlock: View {
    let prayer: Prayer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prayer.title)
                .font(.system(size: 13))
                .foregroundStyle(Chotki.gold)

            if let rubric = prayer.rubric {
                Text(rubric).font(.system(size: 12)).italic().foregroundStyle(Chotki.faint)
            }

            ForEach(Array(prayer.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: 16))
                    .foregroundStyle(Chotki.parchment)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Where the wording comes from, so it can be checked. Every text
            // here is public domain and none of it has had a priest's eye on it.
            Text(prayer.source)
                .font(.system(size: 11)).foregroundStyle(Chotki.faint)
                .padding(.top, 2)
        }
    }
}

/// The rope: a count, and the prayer said on it.
///
/// The tone belongs to phase 6 with the rest of the sound. What matters here is
/// that the count is a value the record could hold, not an animation.
struct RopeView: View {
    @Bindable var model: Model
    @State private var screen = PrayerScreen()

    var body: some View {
        VStack(spacing: 18) {
            Picker("Prayer", selection: $screen.chosen) {
                ForEach(PrayerScreen.choices, id: \.self) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .pickerStyle(.menu)
            .tint(Chotki.gold)

            Text("\(screen.count)")
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(Chotki.gold)
                .contentTransition(.numericText(value: Double(screen.count)))
                .animation(.snappy(duration: 0.2), value: screen.count)

            Text("of \(screen.target)").font(.footnote).foregroundStyle(Chotki.muted)

            Button {
                let wasLast = screen.count == screen.target
                withAnimation(.snappy(duration: 0.18)) { screen.advance() }
                // The bell marks the end of a round; the tick marks a knot.
                // Neither is applause — the app does not congratulate anyone
                // for praying, and the bell is the sound a rope makes, not a
                // reward for having used one.
                if wasLast, model.settings.chimeOnCompletion {
                    Sound.shared.playBell()
                } else if model.settings.tickEachKnot {
                    Sound.shared.playTick()
                }
            } label: {
                Text("Count").font(.system(size: 20)).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Chotki.gold)

            HStack {
                ForEach([33, 50, 100], id: \.self) { target in
                    Button("\(target)") { screen.target = target; screen.count = 0 }
                        .buttonStyle(.bordered)
                        .tint(screen.target == target ? Chotki.gold : Chotki.muted)
                }
                Button("Start again") { screen.count = 0 }
                    .buttonStyle(.borderless).tint(Chotki.muted)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Chotki.ground)
        .navigationTitle("The rope")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// What the rope is showing. A plain value so the interface holds no logic.
struct PrayerScreen {
    struct Choice: Hashable { let id: String; let title: String }

    static let choices: [Choice] = [Choice(id: "rope", title: "The rope alone")]
        + PrayerBook.bundled.filter(\.isForRope).map { Choice(id: $0.id, title: $0.title) }

    var chosen: Choice = choices.first!
    var count: Int = 0
    var target: Int = 33

    mutating func advance() {
        count += 1
        if count > target { count = 1 }
    }
}
