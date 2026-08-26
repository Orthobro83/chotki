import SwiftUI
import ChotkiCore

/// The day, and what is on the rule for it.
///
/// **Only the box marks a rule kept.** Carried straight from the other two
/// platforms, where making the whole row the target fixed an unclickable
/// checkbox and broke everything sitting beside it — the prayers link and the
/// edit control both ticked the rule off. The answer to a small target is
/// padding around it, not a bigger target.
struct DayView: View {
    @Bindable var model: Model

    private var entries: [DayEntry] { model.entries(on: model.selectedDate) }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Half, and no more. The rules below must always have room.
                MonthGrid(model: model, maxHeight: proxy.size.height / 2)

                Text(Format.longDate(model.selectedDate))
                    .font(.system(size: 17))
                    .foregroundStyle(Chotki.parchment)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .accessibilityLabel("The day")
                    // The header changes with the selection rather than
                    // snapping, so the eye follows what moved.
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.22), value: model.selectedDate)

                if entries.isEmpty {
                    EmptyDay()
                } else {
                    List {
                        ForEach(entries, id: \.id) { entry in
                            EntryRow(model: model, entry: entry)
                                .listRowBackground(Chotki.ground)
                                .listRowSeparatorTint(Chotki.line)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .background(Chotki.ground)
    }
}

private struct EmptyDay: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Nothing on the rule for this day.")
                .foregroundStyle(Chotki.muted)
            Text("Take something on from the library when you are ready.")
                .font(.footnote)
                .foregroundStyle(Chotki.faint)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(24)
    }
}

private struct EntryRow: View {
    @Bindable var model: Model
    let entry: DayEntry

    var body: some View {
        HStack(spacing: 10) {
            // The box, and only the box. It draws small and responds across the
            // 44pt the platform asks for.
            Button {
                withAnimation(.snappy(duration: 0.25)) { model.toggleKept(entry) }
            } label: {
                Image(systemName: entry.showsAsSatisfied ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(entry.showsAsSatisfied ? Chotki.gold : Chotki.faint)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    // Settles rather than pops: this is an acknowledgement, not
                    // a reward, and the app does not applaud anyone for praying.
                    .symbolEffect(.bounce, options: .speed(2), value: entry.isKept)
            }
            .buttonStyle(.plain)
            .disabled(entry.isDispensed)
            .accessibilityLabel("Mark \(entry.rule.title) kept")

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.rule.title)
                    .foregroundStyle(entry.showsAsSatisfied ? Chotki.muted : Chotki.parchment)
                    .strikethrough(entry.showsAsSatisfied, color: Chotki.faint)

                if let dispensation = entry.dispensation {
                    // The Church lifted it. Said plainly, so the day teaches
                    // something rather than the rule seeming to have broken.
                    Text("Not observed during \(dispensation)")
                        .font(.caption).foregroundStyle(Chotki.goldDim)
                } else if entry.isStoodDown {
                    Text("Stood down").font(.caption).foregroundStyle(Chotki.faint)
                }
            }

            Spacer(minLength: 0)

            // "All day" rather than "anytime": a fast is not optional, and
            // "anytime" reads as though it were.
            Text(entry.rule.timeOfDay.map { Format.time($0, model.settings.clockStyle) } ?? "All day")
                .font(.system(size: 13))
                .foregroundStyle(entry.isKept ? Chotki.faint : Chotki.muted)
        }
        .padding(.vertical, 2)
    }
}
