import SwiftUI
import ChotkiCore

/// What has been kept, in words first.
///
/// The order is deliberate and load-bearing: the sentences come before the
/// figure, because "evening prayers slipped twice, both Fridays" is something a
/// person can act on and a percentage is not. The figure can be hidden entirely
/// in settings, and nothing here is coloured as a warning — there is no red in
/// this view by design.
struct ProgressTabViewContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let report = model.report()

        VStack(alignment: .leading, spacing: 0) {
            Text("Your progress up to \(Format.longDate(model.progressThrough))")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 8)

            summary(report)

            if model.settings.showConsistencyNumber, let overall = report.overall {
                figure(overall)
            }

            if report.hasAnythingDue {
                Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 4)
                perRule(report)

                Button { model.openDetachedReport?() } label: {
                    Label("Open in a window", systemImage: "macwindow")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: prose, which leads

    private func summary(_ report: ProgressReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(report.summary, id: \.self) { line in
                Text(line)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.parchment)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: the figure, which does not

    private func figure(_ overall: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int((overall * 100).rounded()))%")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.gold)
                Text("kept, over the 30 days to then")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.top, 14)
    }

    // MARK: per rule

    private func perRule(_ report: ProgressReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("by rule")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .padding(.top, 10).padding(.bottom, 5)

            ForEach(report.perRule.filter(\.hasAnythingDue)) { score in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(score.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.parchmentDim)
                    Spacer(minLength: 6)
                    if score.streak > 1 {
                        // Stated as a fact, never as something at risk.
                        Text("\(score.streak) in a row")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.goldDim)
                    }
                    Text(kept(score))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Phrased as what was kept out of what came round — never as a shortfall.
    private func kept(_ score: RuleScore) -> String {
        "\(score.kept + score.keptLate) of \(score.scoreable)"
    }
}

struct ProgressTabView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView { ProgressTabViewContent(model: model) }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
    }
}
