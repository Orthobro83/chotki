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
                Text(category.displayName.lowercased())
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 3)

                ForEach(templates) { template in
                    TemplateRow(model: model, template: template, taken: isTaken(template))
                }
            }

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

    private func isTaken(_ template: RuleTemplate) -> Bool {
        model.rules.contains { $0.title == template.title }
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
                            Button { model.screen = .glossary(slug) } label: {
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
                Text("on your rule")
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
