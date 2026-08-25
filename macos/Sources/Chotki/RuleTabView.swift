import SwiftUI
import ChotkiCore

struct RuleTabViewContent: View {
    @ObservedObject var model: AppModel
    /// Holds the calendar on screen along with the day while the library is
    /// browsed. Wants the height to spare: pinned, the calendar and the day
    /// together take the top half of the pane and the library reads through
    /// what is left.
    var pinsCalendar: Bool = false

    var body: some View {
        if model.libraryOnRule {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !pinsCalendar { calendar }
                Section {
                    InlineLibrary(model: model)
                } header: {
                    VStack(spacing: 0) {
                        if pinsCalendar { calendar }
                        DayPanel(model: model)
                    }
                    // Opaque, or the library shows through as it passes under.
                    // Carried up past the top because SwiftUI runs a scroll view
                    // beneath the window's transparent titlebar — safe only
                    // because a pinned calendar is the topmost thing there is.
                    .background(Theme.ground.padding(.top, pinsCalendar ? -120 : 0))
                }
            }
        } else {
            VStack(spacing: 0) {
                calendar
                DayPanel(model: model)
            }
        }
    }

    private var calendar: some View {
        VStack(spacing: 0) {
            MonthGridView(model: model)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

/// The day, and the library beneath it when it is open.
///
/// While the library is open the day is pinned to the top and the library scrolls
/// under it. What you are weighing a new rule against is the date, what you have
/// already promised for it and at what times — so that is the one thing that must
/// not scroll away while you weigh it.
///
/// Pinned only while the library is open. With it closed there is nothing to
/// scroll under the day, and the cross behind the rules would be covered by the
/// opaque background the pinning needs.
struct DayAndLibrary: View {
    @ObservedObject var model: AppModel
    /// Gutter for the window, which insets the day from the divider.
    var inset: CGFloat = 0
    /// Carries the pinned background up past the top of the column.
    ///
    /// SwiftUI runs a scroll view underneath the window's transparent titlebar,
    /// so library rows slide through the strip above the pinned day and it stops
    /// looking like the top of anything. Only safe where the day is the first
    /// thing in its column: in the popover the month grid sits above it, and
    /// this would cover it.
    var masksAbove: Bool = false

    var body: some View {
        if model.libraryOnRule {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    InlineLibrary(model: model)
                        .padding(.horizontal, inset)
                } header: {
                    DayPanel(model: model)
                        .padding(.horizontal, inset)
                        // Opaque, and applied outside the inset so the library
                        // does not show through the gutters as it passes under.
                        .background(Theme.ground.padding(.top, masksAbove ? -120 : 0))
                }
            }
        } else {
            DayPanel(model: model)
                .padding(.horizontal, inset)
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
            if let thanksgiving = model.thanksgiving {
                thanksgivingLine(thanksgiving)
            }
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
            footer
        }
        .animation(.easeInOut(duration: 0.45), value: model.thanksgiving)
        .onChange(of: model.selectedDate) { _ in model.clearThanksgiving() }
    }

    /// One line, between two hairlines, when the last thing on the day is
    /// settled. It fades in, sits, and goes. No sound — the chime belongs to
    /// the prayer rope, and would lose its meaning if the app rang all day.
    private func thanksgivingLine(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Theme.goldDim.opacity(0.4)).frame(width: 14, height: 1)
            Text(text)
                .font(.custom("Cardo", size: 14))
                .foregroundStyle(Theme.gold)
            Rectangle().fill(Theme.goldDim.opacity(0.4)).frame(height: 1)
        }
        .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 4)
        .transition(.opacity)
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
            // Opens underneath rather than navigating away, so the calendar
            // and the day's list stay in view while you consider taking
            // something else on. The full library is still a screen of its own.
            Button { model.libraryOnRule.toggle() } label: {
                Label("Library", systemImage: "square.grid.2x2")
            }
            .foregroundStyle(model.libraryOnRule ? Theme.parchment : Theme.gold)
            Spacer()
            Button { model.screen = .prayerRope } label: {
                Image(systemName: "circle.hexagonpath")
            }
            .help("Prayers")
            Button { model.openGlossary(nil) } label: {
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
    /// A single soft swell around the box at the moment it is ticked. Nothing
    /// is said — a phrase repeated five times a day becomes wallpaper, and
    /// using it as a checkbox noise would cheapen it.
    @State private var breathing = false

    var body: some View {
        HStack(spacing: 9) {
            // The box, and only the box, marks a rule kept.
            //
            // The whole row used to be the target, which fixed a real problem —
            // an unchecked box filled with `Color.clear` is not hit-testable at
            // all, so only its 1pt outline responded — and created a worse one:
            // the prayers link and the edit pencil sit inside that row, so
            // reaching for either of them also ticked the rule off.
            //
            // The answer to a 14pt target is padding around it, not a tap
            // gesture over everything else. The box draws at 14pt and responds
            // across 26.
            ZStack {
                if breathing {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Theme.gold.opacity(0.35), lineWidth: 3)
                        .frame(width: 22, height: 22)
                        .blur(radius: 2)
                }
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
            .padding(6)
            .contentShape(Rectangle())
            .onTapGesture {
                let wasKept = entry.isKept
                model.toggleKept(entry)
                if !wasKept, !entry.isDispensed { breathe() }
            }
            .help(
                entry.isDispensed
                    ? "The Church lifts this today"
                    : (entry.isKept ? "Click to mark as not kept" : "Click to mark as kept")
            )
            .padding(.trailing, -6)

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
                    Text("Stood down")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                }
            }

            Spacer(minLength: 6)

            // "all day" rather than "anytime": a fast is not optional, and
            // "anytime" reads as though it were.
            Text(entry.rule.timeOfDay.map { Format.time($0, model.settings.clockStyle) } ?? "All day")
                .font(.system(size: 11))
                .foregroundStyle(entry.isKept ? Theme.faint : Theme.muted)

            // Always shown when a rule carries prayers, not only on hover: it
            // is the way to the words, which is the point of the rule.
            // Whenever the app holds the text the rule names. Asking only
            // about prayers left the reading rules — the day's Gospel, Epistle
            // and the saint's life — with no way through at all, on both
            // platforms, for the same reason.
            switch entry.rule.reference {
            case .prayers:
                Button { model.screen = .prayers(entry.rule.id) } label: {
                    Image(systemName: "text.alignleft").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hovering ? Theme.gold : Theme.goldDim)
                .help("Read the prayers")
            case .reading:
                Button { model.tab = .reading } label: {
                    Image(systemName: "text.alignleft").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hovering ? Theme.gold : Theme.goldDim)
                .help("Read the day's readings")
            case .psalter:
                Button { model.screen = .psalter } label: {
                    Image(systemName: "text.alignleft").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hovering ? Theme.gold : Theme.goldDim)
                .help("Read today's kathisma")
            case .none:
                EmptyView()
            }

            // Always drawn, never only on hover. Appearing on hover made the
            // row reflow under the cursor, so the prayers icon beside it moved
            // out from under a click that was already on its way.
            Button { model.screen = .editor(entry.rule.id) } label: {
                Image(systemName: "pencil").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(hovering ? Theme.muted : Theme.faint)
            .help("Edit this rule")
        }
        .padding(.horizontal, 4).padding(.vertical, 1)
        .rowBackground(hovering)
        // Deliberately no tap gesture on the row. Everything else here either
        // does its own thing — the prayers, the pencil — or does nothing at all.
        .onHover { hovering = $0 }
        .contextMenu {
            if entry.isDispensed {
                Text("Lifted by the Church today")
            } else {
                switch entry.rule.reference {
                case .prayers:
                    Button("Read the prayers") { model.screen = .prayers(entry.rule.id) }
                    Divider()
                case .reading:
                    Button("Read the day's readings") { model.tab = .reading }
                    Divider()
                case .psalter:
                    Button("Read today's kathisma") { model.screen = .psalter }
                    Divider()
                case .none:
                    EmptyView()
                }
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


    private func breathe() {
        withAnimation(.easeOut(duration: 0.18)) { breathing = true }
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.easeIn(duration: 0.35)) { breathing = false }
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
    var pinsCalendar: Bool = false

    var body: some View {
        ZStack {
            // Behind the rules rather than beside them, so a short list leaves
            // something to rest on instead of a blank panel.
            RuleBackdrop()

            ScrollView { RuleTabViewContent(model: model, pinsCalendar: pinsCalendar) }
                .scrollContentBackgroundHidden()
        }
        .frame(maxHeight: .infinity)
    }
}
