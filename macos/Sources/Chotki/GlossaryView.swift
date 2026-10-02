import SwiftUI
import ChotkiCore

/// The terms, searchable and scoped to the tradition the user has chosen.
struct GlossaryView: View {
    @ObservedObject var model: AppModel
    let initialSlug: String?

    @State private var query = ""
    @State private var openSlug: String?
    /// The incoming slug seeds the view once. Without this the back button
    /// cleared `openSlug` only to fall straight back to `initialSlug`, so
    /// "All terms" did nothing whenever you arrived from a term link.
    @State private var hasSeeded = false

    private var glossary: Glossary {
        Glossary.shared(for: model.settings.jurisdiction.tradition)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search terms", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 24).padding(.vertical, 12)
                .foregroundStyle(Theme.parchment)
            Rectangle().fill(Theme.lineSoft).frame(height: 1)

            ScrollView {
                Group {
                    if let slug = openSlug, let entry = glossary.entry(slug: slug) {
                        detail(entry)
                    } else {
                        list
                    }
                }.frame(maxWidth: 800, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading).chotkiScrollContent()
            }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
            .softVerticalScrollEdges()
        }
        .onAppear {
            guard !hasSeeded else { return }
            hasSeeded = true
            openSlug = initialSlug
        }
    }

    private var matchingSlugs: Set<String> {
        Set((query.isEmpty ? glossary.entries : glossary.search(query)).map(\.slug))
    }

    private var list: some View {
        let visible = matchingSlugs
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(glossary.byCategory, id: \.0) { category, entries in
                let matching = entries.filter { visible.contains($0.slug) }
                if !matching.isEmpty {
                    Text(category.displayName)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 5)
                    ForEach(matching) { entry in
                        Button { openSlug = entry.slug } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.term)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.parchment)
                                Text(entry.short)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.bottom, 10)
    }

    private func detail(_ entry: GlossaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { openSlug = nil } label: {
                Label("All terms", systemImage: "chevron.left")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.term)
                    .font(Theme.reading(24))
                    .foregroundStyle(Theme.gold)
                if let pronunciation = entry.pronunciation {
                    Text(pronunciation)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.faint)
                }
            }

            Text(entry.full)
                .font(Theme.reading(15))
                .foregroundStyle(Theme.parchmentDim)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            let related = glossary.related(to: entry)
            if !related.isEmpty {
                Rectangle().fill(Theme.lineSoft).frame(height: 1).padding(.vertical, 2)
                Text("See also")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                ForEach(related) { other in
                    Button { openSlug = other.slug } label: {
                        Text(other.term)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.goldDim)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.vertical, 18)
    }
}
