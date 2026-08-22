import SwiftUI
import ChotkiCore

enum Tab: String, CaseIterable {
    case rule = "Rule"
    case reading = "Reading"
    case progress = "Progress"
}

struct RootView: View {
    @ObservedObject var model: AppModel
    @State private var tab: Tab = .rule

    var body: some View {
        VStack(spacing: 0) {
            if !model.settings.hasCompletedFirstRun {
                OnboardingView(model: model)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
            switch model.screen {
            case .main:
                tabBar
                Divider().overlay(Theme.line)
                content
                    .frame(maxHeight: .infinity, alignment: .top)
            case .library:
                Header(title: "Rule library") { model.screen = .main }
                LibraryView(model: model)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .settings:
                Header(title: "Settings") { model.screen = .main }
                SettingsView(model: model)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .glossary(let slug):
                Header(title: "Terms") { model.screen = .main }
                GlossaryView(model: model, initialSlug: slug)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .editor(let ruleID):
                Header(title: ruleID == nil ? "New rule" : "Edit rule") { model.screen = .main }
                RuleEditorView(model: model, ruleID: ruleID) { model.screen = .main }
                    .frame(maxHeight: .infinity, alignment: .top)
            case .prayers(let ruleID):
                Header(title: "Prayers") { model.screen = .main }
                PrayerView(model: model, ruleID: ruleID)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .prayerRope:
                Header(title: "Prayers") { model.screen = .main }
                PrayerRopeView(model: model)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            }

            if let notice = model.notice {
                Divider().overlay(Theme.line)
                HStack(alignment: .top, spacing: 8) {
                    Text(notice)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.parchmentDim)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button { model.notice = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 9))
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.panel)
            }

            if let error = model.loadError {
                Divider().overlay(Theme.line)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.ochre)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: Theme.popoverWidth, height: Theme.popoverHeight)
        .background(Theme.ground)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { candidate in
                Button {
                    tab = candidate
                } label: {
                    Text(candidate.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(tab == candidate ? Theme.parchment : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(tab == candidate ? Theme.gold : .clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .rule: RuleTabView(model: model)
        case .reading: ReadingView(model: model)
        case .progress: ProgressTabView(model: model)
        }
    }
}

struct Header: View {
    let title: String
    let back: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.parchment)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}


