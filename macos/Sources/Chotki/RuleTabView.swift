import SwiftUI
import ChotkiCore

struct RuleTabViewContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            MonthGridView(model: model)
            Rectangle().fill(Theme.line).frame(height: 1)
            DayPanel(model: model)
        }
    }
}

/// The selected day: what it is in the calendar, what is on the rule for it,
/// and the actions. Shared by the popover and the window, which stack it
/// differently but show the same thing.
struct DayPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            dayHeader
            entries
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
            footer
        }
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(Format.longDate(model.selectedDate))
                .font(.system(size: 13))
                .foregroundStyle(Theme.parchment)
            Spacer()
            if let day = model.liturgical.cachedDay(for: model.selectedDate),
               model.settings.observances.fasting.isVisible,
               day.isFast {
                // Describing what the calendar marks, never instructing.
                TermText(
                    model: model, text: day.fastLevelDescription,
                    size: 11, colour: Theme.violet
                )
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
            Button { model.screen = .prayerRope } label: {
                Image(systemName: "circle.hexagonpath")
            }
            .help("Prayer rope")
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

}

struct EntryRow: View {
    @ObservedObject var model: AppModel
    let entry: DayEntry
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 9) {
            // Indicator only. The whole row is the target — a 14pt box is a
            // mean thing to ask someone to hit, and an unchecked box drawn with
            // a clear fill is not hit-testable at all: only its 1pt outline was
            // clickable, which is why this appeared to do nothing.
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(entry.showsAsSatisfied ? Theme.gold : Color.clear)
                RoundedRectangle(cornerRadius: 3)
                    .stroke(entry.showsAsSatisfied ? Theme.gold : (hovering ? Theme.muted : Theme.faint), lineWidth: 1)
                if entry.showsAsSatisfied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.ground)
                }
            }
            .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.rule.title)
                    .font(.system(size: 12))
                    .foregroundStyle(entry.showsAsSatisfied ? Theme.muted : Theme.parchment)
                    .strikethrough(entry.showsAsSatisfied, color: Theme.faint)
                if let dispensation = entry.dispensation {
                    // The Church lifted it. Said plainly, so the day teaches
                    // something rather than the rule seeming to have broken.
                    Text("Not observed during \(dispensation)")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.goldDim)
                        .fixedSize(horizontal: false, vertical: true)
                } else if entry.isStoodDown {
                    // Neutral wording: stood down, not skipped or missed.
                    Text("stood down")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                }
            }

            Spacer(minLength: 6)

            // "all day" rather than "anytime": a fast is not optional, and
            // "anytime" reads as though it were.
            Text(entry.rule.timeOfDay.map(Format.time) ?? "all day")
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
        .contentShape(Rectangle())
        .onTapGesture { model.toggleKept(entry) }
        .allowsHitTesting(true)
        .onHover { hovering = $0 }
        .help(entry.isDispensed ? "The Church lifts this today" : (entry.isKept ? "Click to mark as not kept" : "Click to mark as kept"))
        .contextMenu {
            if entry.isDispensed {
                Text("Lifted by the Church today")
            } else {
                Button(entry.isKept ? "Clear this day" : "Mark as kept") { model.toggleKept(entry) }
                if !entry.isKept {
                    Button("Mark as kept, late") { model.markKeptLate(entry) }
                }
                Button("Stand down for this day") {
                    model.setStatus(.skipped, for: entry.rule, on: entry.date)
                }
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
        ZStack {
            // Behind the rules rather than beside them, so a short list leaves
            // something to rest on instead of a blank panel.
            RuleBackdrop()

            ScrollView { RuleTabViewContent(model: model) }
                .scrollContentBackgroundHidden()
        }
        .frame(maxHeight: .infinity)
    }
}
