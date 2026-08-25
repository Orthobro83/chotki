import SwiftUI
import ChotkiCore

/// The prayers a rule carries, in the order they are said.
///
/// Set in the serif and given room: this is the one screen in the app whose
/// whole purpose is to be read slowly, so it is spaced for reading rather than
/// for scanning.
struct PrayerViewContent: View {
    @ObservedObject var model: AppModel
    let ruleID: UUID

    private var rule: Rule? { model.rules.first { $0.id == ruleID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let rule, rule.hasPrayers {
                // Scanned across the whole rule, not prayer by prayer — it is
                // read in one sitting.
                let found = Glossary
                    .shared(for: model.settings.jurisdiction.tradition)
                    .scanOnce(across: rule.prayers.map(\.paragraphs))

                ForEach(Array(rule.prayers.enumerated()), id: \.element.id) { index, prayer in
                    prayerBlock(prayer, matches: found[index])
                    if index < rule.prayers.count - 1 {
                        Rectangle().fill(Theme.lineSoft).frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
                note
            } else {
                empty
            }
        }
        .padding(.vertical, 12)
    }

    private func prayerBlock(_ prayer: Prayer, matches: [[TermMatch]]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(prayer.title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.gold)
            if let rubric = prayer.rubric {
                Text(rubric)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrayerProse(
                model: model, paragraphs: prayer.paragraphs,
                size: 15, spacing: 5, matches: matches
            )
            PrayerAttribution(prayer: prayer)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    /// Said plainly, because the difference between "these are the prayers" and
    /// "these are some of the prayers" matters to someone learning a rule.
    private var note: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Text("These are the prayers common to almost every form of this rule. Prayer books differ, and the full rule is settled with your priest or spiritual father.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text("Where to read more")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)

            // References, not the source of the wording above. Almost all
            // publish modern translations, which are under copyright however
            // freely they can be read.
            VStack(alignment: .leading, spacing: 5) {
                ForEach(PrayerSources.further) { source in
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(source.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.goldDim)
                                Text(source.organisation)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.faint)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 16).padding(.top, 6)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Text("No prayers are attached to this rule.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Text("Rules you write yourself carry none unless you add them.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24).padding(.vertical, 40)
    }
}

/// The fine print under a prayer: where its wording comes from, and where to
/// read that source. Deliberately quiet — it should be findable, not intrusive.
struct PrayerAttribution: View {
    let prayer: Prayer

    var body: some View {
        Group {
            if let link = prayer.sourceURL, let url = URL(string: link) {
                Link(destination: url) {
                    Text("Source · \(prayer.source)")
                        .underline()
                }
                .buttonStyle(.plain)
            } else {
                Text("Source · \(prayer.source)")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.faint)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 3)
    }
}

struct PrayerView: View {
    @ObservedObject var model: AppModel
    let ruleID: UUID

    var body: some View {
        ScrollView { PrayerViewContent(model: model, ruleID: ruleID) }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
    }
}
