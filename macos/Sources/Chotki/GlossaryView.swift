import SwiftUI
import ChotkiCore

/// The terms, searchable and scoped to the tradition the user has chosen.
struct GlossaryView: View {
    @ObservedObject var model: AppModel
    let initialSlug: String?

    @State private var query = ""
    @State private var openSlug: String?

    private var glossary: Glossary {
        Glossary.shared.scoped(to: model.settings.jurisdiction.tradition)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search terms", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(Theme.parchment)
            Rectangle().fill(Theme.lineSoft).frame(height: 1)

            ScrollView {
                if let slug = openSlug ?? initialSlug, let entry = glossary.entry(slug: slug) {
                    detail(entry)
                } else {
                    list
                }
            }
            .frame(maxHeight: 470)
            .scrollContentBackgroundHidden()
        }
        .onAppear { openSlug = initialSlug }
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
                    Text(category.displayName.lowercased())
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 2)
                    ForEach(matching) { entry in
                        Button { openSlug = entry.slug } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.term)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.parchment)
                                Text(entry.short)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.faint)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 5)
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
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.term)
                    .font(.custom("Cardo", size: 18))
                    .foregroundStyle(Theme.gold)
                if let pronunciation = entry.pronunciation {
                    Text(pronunciation)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                }
            }

            Text(entry.full)
                .font(.system(size: 12))
                .foregroundStyle(Theme.parchmentDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            let related = glossary.related(to: entry)
            if !related.isEmpty {
                Rectangle().fill(Theme.lineSoft).frame(height: 1).padding(.vertical, 2)
                Text("see also")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                ForEach(related) { other in
                    Button { openSlug = other.slug } label: {
                        Text(other.term)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.goldDim)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
