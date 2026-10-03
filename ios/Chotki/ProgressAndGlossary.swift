import SwiftUI
import ChotkiCore

/// What was kept, said in words first, with the Climacus plate held at the foot.
///
/// No red anywhere, no "failed", no broken streak, and no congratulations.
/// The words come first. The figure is optional. Today is outside the window.
struct ProgressView_: View {
    @Bindable var model: Model

    private var report: ProgressReport { model.report() }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your progress up to \(Format.longDate(report.through))")
                        .font(Chotki.reading(16))
                        .foregroundStyle(Chotki.parchment)
                        .accessibilityIdentifier("Progress heading")

                    if !report.hasAnythingDue {
                        Text("Nothing has come due yet. This fills in as the days pass.")
                            .font(Chotki.reading(15))
                            .foregroundStyle(Chotki.parchmentDim)
                    } else {
                        ForEach(Array(report.summary.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(Chotki.reading(15))
                                .foregroundStyle(Chotki.parchmentDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if model.settings.showConsistencyNumber, let overall = report.overall {
                        Text("\(Int((overall * 100).rounded()))% over the last thirty days")
                            .font(Chotki.reading(14))
                            .foregroundStyle(Chotki.goldDim)
                            .padding(.top, 4)
                    }

                    let scored = report.perRule.filter(\.hasAnythingDue)
                    if !scored.isEmpty {
                        Text("By rule")
                            .font(Chotki.reading(13))
                            .foregroundStyle(Chotki.gold)
                            .padding(.top, 10)
                        ForEach(scored) { score in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(score.title)
                                    .font(Chotki.reading(15))
                                    .foregroundStyle(Chotki.parchment)
                                Text(keptLine(score))
                                    .font(Chotki.reading(13))
                                    .foregroundStyle(Chotki.faint)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 280)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ClimacusPlate()
        }
        .background(Chotki.ground)
    }

    private func keptLine(_ score: RuleScore) -> String {
        var line = "\(score.kept) kept"
        if score.keptLate > 0 { line += ", \(score.keptLate) a little late" }
        if score.stoodDown > 0 { line += ", \(score.stoodDown) stood down" }
        return line
    }
}

private let climacusQuote =
    "Those who have really determined to serve Christ, with the help of spiritual fathers and their own self-knowledge, will strive before all else to choose a place, a way of life, a habitation, and exercises suitable for them."

private struct ClimacusPlate: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = UIImage(named: "s1641005") ?? fresco() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(960 / 670, contentMode: .fit)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 4) {
                    Text("“")
                        .font(Chotki.reading(36))
                        .foregroundStyle(Chotki.goldDim)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(climacusQuote + "”")
                            .font(Chotki.reading(14.5))
                            .italic()
                            .foregroundStyle(Chotki.parchment)
                        Text("— Saint John Climacus, from The Ladder of Divine Ascent, 7th century AD.")
                            .font(Chotki.reading(11))
                            .foregroundStyle(Chotki.muted)
                    }
                }
                Text("Icon of St. Anthony the Great, St. Paul of Thebes, St. Sabbas the Sanctified, and St. John Climacus.")
                    .font(.system(size: 11))
                    .foregroundStyle(Chotki.parchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Icon caption")
            }
            .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .allowsHitTesting(false)
    }

    private func fresco() -> UIImage? {
        guard let url = Bundle.main.url(forResource: "s1641005", withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

/// The terms, in alphabetical order, narrowed by what has been typed so far.
///
/// A tap opens the explanation under the term. The same tap closes it.
/// Arriving from a word opens that term already and scrolls to it. The match
/// is the leading characters of the term or of another name it goes by:
/// "theo" finds Theotokos, and "okos" does not.
struct GlossaryView_: View {
    @Bindable var model: Model
    var slug: String?
    @State private var query = ""
    @State private var expanded: Set<String> = []

    private var glossary: Glossary {
        Glossary.shared(for: model.settings.jurisdiction.tradition)
    }

    private var shown: [GlossaryEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return glossary.entries }
        return glossary.entries.filter { entry in
            entry.term.lowercased().hasPrefix(needle)
                || entry.aliases.contains { $0.lowercased().hasPrefix(needle) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search terms", text: $query)
                .font(Chotki.reading(17))
                .foregroundStyle(Chotki.parchment)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Chotki.panel)
                .padding(12)
                .accessibilityLabel("Search terms")

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(shown, id: \.slug) { entry in
                            TermRow(entry: entry, open: expanded.contains(entry.slug)) {
                                if expanded.contains(entry.slug) {
                                    expanded.remove(entry.slug)
                                } else {
                                    expanded.insert(entry.slug)
                                }
                            }
                            .id(entry.slug)
                        }
                    }
                }
                .task(id: slug) {
                    guard let slug else { return }
                    expanded.insert(slug)
                    try? await Task.sleep(for: .milliseconds(60))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(slug, anchor: .top)
                    }
                }
            }
        }
        .background(Chotki.ground)
        .navigationTitle("Glossary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Smaller than the prayers, serif, and set to the left.
struct GlossaryOfTerms: View {
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            Text("Glossary of terms")
                .font(Chotki.reading(10.2))
                .foregroundStyle(Chotki.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Glossary of terms")
    }
}

private struct TermRow: View {
    let entry: GlossaryEntry
    var open: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.term)
                    .font(Chotki.reading(17))
                    .foregroundStyle(Chotki.parchment)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if open {
                    if let pronunciation = entry.pronunciation {
                        Text(pronunciation)
                            .font(Chotki.reading(13))
                            .foregroundStyle(Chotki.faint)
                            .padding(.top, 2)
                    }
                    Text(entry.full)
                        .font(Chotki.reading(17))
                        .foregroundStyle(Chotki.parchment)
                        .lineSpacing(17 * 0.45)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.term)
    }
}

/// Morning until noon, afternoon until five, evening after.
func greetingLine(_ name: String, at date: Date = Date()) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    let part = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Good \(part)" : "Good \(part), \(trimmed)"
}

struct PhoneTitle<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(Chotki.reading(26))
                .fontWeight(.medium)
                .foregroundStyle(Chotki.parchment)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
