import SwiftUI
import ChotkiCore

/// What was kept, described rather than scored.
///
/// No red anywhere, no "failed", no broken streak, and no comparison against a
/// target or a better past self. The words come first and the figure is
/// optional — someone who does not want a number should not be given one.
struct ProgressView_: View {
    @Bindable var model: Model

    private var report: ProgressReport { model.report() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your progress up to \(Format.longDate(report.through))")
                    .font(.system(size: 17)).foregroundStyle(Chotki.parchment)

                if !report.hasAnythingDue {
                    Text("Nothing has come due yet. This fills in as the days pass.")
                        .foregroundStyle(Chotki.muted)
                } else {
                    ForEach(Array(report.summary.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .foregroundStyle(Chotki.parchment)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if model.settings.showConsistencyNumber, let overall = report.overall {
                        Text("\(Int((overall * 100).rounded()))% of what came due")
                            .font(.footnote).foregroundStyle(Chotki.muted)
                    }
                }

                // A day still in progress is not something to score, so today
                // is deliberately outside the window above.
                Text("Today is not counted — a day still in progress is not a day missed.")
                    .font(.system(size: 11)).foregroundStyle(Chotki.faint)
                    .padding(.top, 6)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Chotki.ground)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The words a newcomer stops at.
///
/// Not a tab on iPhone — five is what the platform shows without an overflow —
/// so it is reached by tapping a term in the text, and from Settings for
/// browsing. Reachable, which is what parity asks; not prominent, which is a
/// per-platform arrangement.
struct GlossaryView_: View {
    @Bindable var model: Model
    var slug: String?
    @State private var query = ""

    private var glossary: Glossary {
        Glossary.shared(for: model.settings.jurisdiction.tradition)
    }

    private var shown: [GlossaryEntry] {
        query.isEmpty ? glossary.entries : glossary.search(query)
    }

    var body: some View {
        Group {
            if let slug, let entry = glossary.entry(slug: slug) {
                Detail(entry: entry, glossary: glossary)
            } else {
                List {
                    ForEach(shown, id: \.slug) { entry in
                        NavigationLink(value: Route.term(slug: entry.slug)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.term).foregroundStyle(Chotki.parchment)
                                Text(entry.short).font(.caption).foregroundStyle(Chotki.faint)
                            }
                        }
                        .listRowBackground(Chotki.ground)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .searchable(text: $query, prompt: "Search terms")
                .navigationTitle("Glossary")
            }
        }
        .background(Chotki.ground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct Detail: View {
        let entry: GlossaryEntry
        let glossary: Glossary

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let pronunciation = entry.pronunciation {
                        Text(pronunciation).font(.footnote).italic()
                            .foregroundStyle(Chotki.muted)
                    }
                    Text(entry.full)
                        .foregroundStyle(Chotki.parchment)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    let related = glossary.related(to: entry)
                    if !related.isEmpty {
                        Text("See also").font(.footnote).foregroundStyle(Chotki.gold)
                            .padding(.top, 6)
                        ForEach(related, id: \.slug) { other in
                            NavigationLink(value: Route.term(slug: other.slug)) {
                                Text(other.term).foregroundStyle(Chotki.goldDim)
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(entry.term)
        }
    }
}
