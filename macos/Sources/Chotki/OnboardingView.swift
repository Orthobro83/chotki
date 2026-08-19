import SwiftUI
import ChotkiCore

/// First run. Offers a few rules and nothing more.
///
/// The whole point is restraint: taking on twelve things in week one and
/// abandoning ten of them is the standard way this goes wrong, so this suggests
/// three, lets you take none of them, and never presents the full library here.
struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @State private var chosen: Set<String> = []

    /// A small, ordinary beginning. Not a minimum, and not a standard.
    private var suggested: [RuleTemplate] {
        let library = RuleLibrary.shared.scoped(to: model.settings.jurisdiction.tradition)
        return ["morning-prayers", "evening-prayers", "daily-gospel"]
            .compactMap { library.template(id: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A place to keep your rule")
                    .font(.custom("Cardo", size: 20))
                    .foregroundStyle(Theme.gold)
                Text("Start with one or two things you can actually keep. You can add more whenever you are ready, and pause anything without it counting against you.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.parchmentDim)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 14)

            Rectangle().fill(Theme.line).frame(height: 1)

            ForEach(suggested) { template in
                Button {
                    if chosen.contains(template.id) { chosen.remove(template.id) }
                    else { chosen.insert(template.id) }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(chosen.contains(template.id) ? Theme.gold : Color.clear)
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(chosen.contains(template.id) ? Theme.gold : Theme.faint, lineWidth: 1)
                            if chosen.contains(template.id) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Theme.ground)
                            }
                        }
                        .frame(width: 14, height: 14)
                        .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.parchment)
                            Text(template.summary)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.faint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 18).padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(Theme.line).frame(height: 1)

            HStack(spacing: 14) {
                Button {
                    for id in chosen {
                        if let template = RuleLibrary.shared.template(id: id) {
                            model.take(on: template)
                        }
                    }
                    model.update { $0.hasCompletedFirstRun = true }
                    model.notice = nil
                } label: {
                    Text(chosen.isEmpty ? "Start with nothing for now" : "Begin")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.goldDim))
                }
                .buttonStyle(.plain)

                Text("Nothing here is required. The library has more when you want it.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
    }
}
