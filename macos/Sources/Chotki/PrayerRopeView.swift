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
    private let sound = SoundPlayer.shared
    @FocusState private var focused: Bool

    private let targets = [33, 50, 100]

    init(model: AppModel, startingAt count: Int = 0) {
        self.model = model
        _count = State(initialValue: count)
    }

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.top, 26).padding(.bottom, 18)

            knots
                .padding(.horizontal, 22).padding(.bottom, 20)

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
                .padding(.top, 7)

            Spacer(minLength: 12)

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
