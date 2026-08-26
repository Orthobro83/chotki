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
    /// Shared with the row so a tapped rule can become the screen it opens.
    var transition: Namespace.ID
    /// Raised by the tab, which owns the sheet.
    var openLibrary: () -> Void

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
                    EmptyDay(open: openLibrary)
                } else {
                    List {
                        ForEach(entries, id: \.id) { entry in
                            EntryRow(model: model, entry: entry, transition: transition)
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

/// Nothing due, and the way to change that.
///
/// The words alone sent someone to a small icon in a corner they had not
/// noticed. The library is named in the sentence, so the library is drawn under
/// it, at a size that reads as the thing to press. The corner button stays
/// where it is: it is how the library is reached on every other day, and a
/// control that moves depending on whether the day is empty is worse than one
/// that does not.
private struct EmptyDay: View {
    /// Opens the same sheet the toolbar does.
    var open: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("Nothing on the rule for this day.")
                .foregroundStyle(Chotki.muted)
            Text("Take something on from the library when you are ready.")
                .font(.footnote)
                .foregroundStyle(Chotki.faint)

            Button(action: open) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(Chotki.gold)
                    .frame(width: 88, height: 88)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .accessibilityLabel("Library")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(24)
    }
}

private struct EntryRow: View {
    @Bindable var model: Model
    let entry: DayEntry
    var transition: Namespace.ID

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

            // The way to the words, which is the point of the rule. Its own
            // control, never the whole row.
            if entry.rule.hasPrayers {
                NavigationLink(value: Route.prayers(ruleID: entry.rule.id)) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 15))
                        .foregroundStyle(Chotki.goldDim)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Read the prayers for \(entry.rule.title)")
                .zoomSource(id: entry.rule.id, in: transition)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The zoom that carries a tapped thing into the screen it opens.
///
/// Guarded rather than assumed: it arrived in iOS 18 and the floor here is 17,
/// so on 17 the push is the ordinary one. A transition is not worth excluding a
/// device over.
extension View {
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
