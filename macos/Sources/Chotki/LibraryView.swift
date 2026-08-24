import SwiftUI
import ChotkiCore

/// Rules you can take on, grouped by category.
///
/// Nothing here is on by default and nothing switches itself on. Taking a rule
/// on copies it, so it becomes yours to rename and retime — the library is a
/// starting point, not a set of obligations.
struct LibraryViewContent: View {
    @ObservedObject var model: AppModel

    private var library: RuleLibrary {
        RuleLibrary.shared.scoped(to: model.settings.jurisdiction.tradition)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Take on what you are ready for. Two or three is a good beginning.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)

            ForEach(library.byCategory(), id: \.0) { category, templates in
                // Capitalised as they are defined in core. Text that came from
                // the calendar is never re-cased either way.
                Text(category.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 3)

                ForEach(templates) { template in
                    TemplateRow(model: model, template: template, taken: isTaken(template))
                }
            }

            if !model.customEntries.isEmpty { custom }

            Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 12)
            Button { model.screen = .editor(nil) } label: {
                Label("Write your own rule", systemImage: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.gold)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
    
    }

    /// His own rules, kept so they can be taken up again without being written
    /// out a second time.
    private var custom: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Custom")
                .font(.system(size: 11))
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 3)

            // Descriptive, not instructing: it says what is usually so, and
            // leaves the decision where it belongs.
            Text("Custom routines are usually taken on the advice of your priest.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.bottom, 4)

            ForEach(model.customEntries) { rule in
                CustomRow(model: model, rule: rule)
            }
        }
    }

    private func isTaken(_ template: RuleTemplate) -> Bool {
        model.rules.contains { $0.title == template.title }
    }
}

/// One rule of his own in the library.
///
/// The cross removes it from this list only. It is drawn always rather than on
/// hover — a control that appears under the cursor makes the row reflow and
/// moves whatever was beside it out from under a click already on its way.
struct CustomRow: View {
    @ObservedObject var model: AppModel
    let rule: Rule
    @State private var hovering = false

    private var isOnTheRule: Bool { model.isOnTheRule(rule) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .font(.system(size: 12))
                    .foregroundStyle(isOnTheRule ? Theme.muted : Theme.parchment)
                Text(rule.timeOfDay.map(Format.time) ?? "All day")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                if let note = rule.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint.opacity(0.85))
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            if isOnTheRule {
                Text("On your rule")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.goldDim)
            } else {
                Button { model.takeUp(rule) } label: {
                    Text("Take on")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.goldDim))
                }
                .buttonStyle(.plain)
            }

            Button { model.setAside(rule) } label: {
                Image(systemName: "xmark").font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(hovering ? Theme.muted : Theme.faint)
            .help("Remove from the library. The rule and everything it has kept stay as they are.")
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(hovering ? Theme.panel : .clear)
        .onHover { hovering = $0 }
    }
}

struct TemplateRow: View {
    @ObservedObject var model: AppModel
    let template: RuleTemplate
    let taken: Bool
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                    .font(.system(size: 12))
                    .foregroundStyle(taken ? Theme.muted : Theme.parchment)
                Text(template.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
                if let trigger = template.requiredTrigger,
                   !model.settings.observances.setting(for: trigger).drivesRules,
                   !taken {
                    Text("Taking this on will start observing \(ObservanceSettings.name(for: trigger)).")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.goldDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = template.note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint.opacity(0.85))
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !template.glossarySlugs.isEmpty, hovering {
                    HStack(spacing: 6) {
                        ForEach(template.glossarySlugs.prefix(3), id: \.self) { slug in
                            Button { model.openGlossary(slug) } label: {
                                Text(slug.replacingOccurrences(of: "-", with: " "))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.goldDim)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 4)

            if taken {
                Text("On your rule")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.goldDim)
            } else {
                Button { model.take(on: template) } label: {
                    Text("Take on")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.goldDim))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(hovering ? Theme.panel : .clear)
        .onHover { hovering = $0 }
    }
}

/// The library opened underneath the day, on the rule screen.
///
/// Deciding what to take on is a judgement about how much is already there. Sent
/// to a screen of its own you are choosing in the abstract; opened below the
/// day, the calendar and the list of what you have already promised are a scroll
/// away rather than a navigation away.
///
/// It sits inside the day's own scroll rather than in a pane of its own, so it
/// grows from exactly where the button was pressed and nothing has to jump to
/// make room for it.
struct InlineLibrary: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)

            HStack(spacing: 10) {
                Text("Library")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.parchment)
                Spacer()
                Button {
                    model.libraryOnRule = false
                    model.screen = .library
                } label: {
                    Text("Open in full")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
                Button { model.libraryOnRule = false } label: {
                    Image(systemName: "xmark").font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.faint)
                .help("Close the library")
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.panel)

            LibraryViewContent(model: model)
        }
        .background(Theme.ground)
    }
}

/// Scroll chrome only. Content is `LibraryViewContent` so it can be rendered
/// directly — ImageRenderer does not draw ScrollView contents.
struct LibraryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView { LibraryViewContent(model: model) }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
    }
}
