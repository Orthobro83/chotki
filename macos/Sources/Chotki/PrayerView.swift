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
                ForEach(Array(rule.prayers.enumerated()), id: \.element.id) { index, prayer in
                    prayerBlock(prayer)
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

    private func prayerBlock(_ prayer: Prayer) -> some View {
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
            ForEach(prayer.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.custom("Cardo", size: 15))
                    .foregroundStyle(Theme.parchment)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    /// Said plainly, because the difference between "these are the prayers" and
    /// "these are some of the prayers" matters to someone learning a rule.
    private var note: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Text("These are the prayers common to almost every form of this rule. Prayer books differ, and the full rule is settled with your priest.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
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

struct PrayerView: View {
    @ObservedObject var model: AppModel
    let ruleID: UUID

    var body: some View {
        ScrollView { PrayerViewContent(model: model, ruleID: ruleID) }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
    }
}
