import SwiftUI
import ChotkiCore

struct RuleTabViewContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            MonthGridView(model: model)
            Rectangle().fill(Theme.line).frame(height: 1)
            dayHeader
            entries
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
            footer
        }
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(longDate(model.selectedDate))
                .font(.system(size: 13))
                .foregroundStyle(Theme.parchment)
            Spacer()
            if let day = model.liturgical.cachedDay(for: model.selectedDate),
               model.settings.observances.fasting.isVisible,
               day.isFast {
                // Describing what the calendar marks, never instructing.
                Text(day.fastLevelDescription.lowercased())
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.violet)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.violet.opacity(0.45)))
            }
        }
        .padding(.horizontal, 14).padding(.top, 11).padding(.bottom, 7)
    }

    @ViewBuilder private var entries: some View {
        let items = model.entries(on: model.selectedDate)
        if items.isEmpty {
            VStack(spacing: 5) {
                Text("Nothing on the rule for this day.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                Text("Take something on from the library when you are ready.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        } else {
            VStack(spacing: 0) {
                ForEach(items) { entry in
                    EntryRow(model: model, entry: entry)
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button { model.screen = .editor(nil) } label: {
                Label("Add", systemImage: "plus")
            }
            Button { model.screen = .library } label: {
                Label("Library", systemImage: "square.grid.2x2")
            }
            Spacer()
            Button { model.screen = .glossary(nil) } label: {
                Image(systemName: "text.book.closed")
            }
            Button { model.screen = .settings } label: {
                Image(systemName: "gearshape")
            }
        }
        .buttonStyle(.plain)
        .labelStyle(.titleAndIcon)
        .font(.system(size: 12))
        .foregroundStyle(Theme.gold)
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private func longDate(_ date: CalendarDate) -> String {
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let months = ["January", "February", "March", "April", "May", "June",
                      "July", "August", "September", "October", "November", "December"]
        return "\(weekdays[date.weekday.rawValue - 1]) \(date.day) \(months[date.month - 1])"
    }
}

struct EntryRow: View {
    @ObservedObject var model: AppModel
    let entry: DayEntry
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            Button { model.toggleKept(entry) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(entry.isKept ? Theme.gold : .clear)
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(entry.isKept ? Theme.gold : Theme.faint, lineWidth: 1)
                    if entry.isKept {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.ground)
                    }
                }
                .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help(entry.isKept ? "Mark as not kept" : "Mark as kept")

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.rule.title)
                    .font(.system(size: 12))
                    .foregroundStyle(entry.isKept ? Theme.muted : Theme.parchment)
                    .strikethrough(entry.isKept, color: Theme.faint)
                if entry.isStoodDown {
                    // Neutral wording: stood down, not skipped or missed.
                    Text("stood down")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                }
            }

            Spacer(minLength: 6)

            Text(entry.rule.timeOfDay.map(format) ?? "anytime")
                .font(.system(size: 11))
                .foregroundStyle(entry.isKept ? Theme.faint : Theme.muted)

            if hovering {
                Button { model.screen = .editor(entry.rule.id) } label: {
                    Image(systemName: "pencil").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 4).padding(.vertical, 5)
        .rowBackground(hovering)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(entry.isKept ? "Mark as not kept" : "Mark as kept") { model.toggleKept(entry) }
            Button("Stand down for today") {
                model.setStatus(.skipped, for: entry.rule, on: entry.date)
            }
            Divider()
            Button("Edit rule…") { model.screen = .editor(entry.rule.id) }
            if model.isPaused(entry.rule) {
                Button("Resume this rule") { model.resume(entry.rule) }
            } else {
                Button("Pause this rule") { model.standDown(entry.rule) }
            }
        }
    }

    private func format(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}

extension View {
    /// `scrollContentBackground` is macOS 13+, which is our floor, but keep the
    /// call in one place so the deployment target is easy to move.
    @ViewBuilder func scrollContentBackgroundHidden() -> some View {
        self.scrollContentBackground(.hidden)
    }
}

/// The scrolling chrome. Content lives in `RuleTabViewContent` so it can also be
/// rendered directly — ImageRenderer does not draw ScrollView contents.
struct RuleTabView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView { RuleTabViewContent(model: model) }
            .frame(maxHeight: 520)
            .scrollContentBackgroundHidden()
    }
}
