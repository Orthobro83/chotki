import SwiftUI
import ChotkiCore

enum Tab: String, CaseIterable {
    case rule = "Home"
    case prayers = "Prayers"
    case reading = "Reading"
    case progress = "Progress"
    var dueDestination: DueDestination? {
        switch self {
        case .rule: return .home
        case .prayers: return .prayers
        case .reading: return .reading
        case .progress: return nil
        }
    }
}

struct RootView: View {
    @ObservedObject var model: AppModel
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            if !model.settings.hasCompletedFirstRun {
                FirstRunView(model: model)
            } else {
            switch underlyingScreen {
            case .main:
                HStack {
                    Text(model.tab == .rule ? model.greeting : model.tab.rawValue).font(Theme.reading(20))
                    Spacer()
                    if model.isReviewSample {
                        Button { model.previewDueAlert() } label: { Image(systemName: "bell.badge") }
                            .help("Preview Due Alert")
                            .accessibilityLabel("Preview Due Alert")
                    }
                    Button { model.openMainWindow?() } label: { Image(systemName: "macwindow") }
                        .help("Open Full Window")
                    Menu {
                        Button("Library") { model.screen = .library }
                        Button("Glossary") { model.openGlossary(nil) }
                        Button("Settings") { model.screen = .settings }
                    } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 20)
                }.buttonStyle(.plain).foregroundStyle(Theme.parchment).padding(14)
                tabBar
                Divider().overlay(Theme.line)
                content
                    .frame(maxHeight: .infinity, alignment: .top)
            case .library:
                Header(title: "Rule Library") { model.screen = .main }
                LibraryView(model: model)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .settings:
                Header(title: "Settings") { model.screen = .main }
                SettingsView(model: model)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .glossary(let slug):
                Header(title: "Glossary") { model.screen = model.glossaryReturn }
                GlossaryView(model: model, initialSlug: slug)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .editor(let ruleID):
                Header(title: ruleID == nil ? "New Rule" : "Edit Rule") { model.editorDraft = nil; model.screen = .main }
                RuleEditorView(model: model, ruleID: ruleID) { model.editorDraft = nil; model.screen = .main }
                    .frame(maxHeight: .infinity, alignment: .top)
            case .prayers(let ruleID):
                Header(title: "Prayers") { model.screen = .main }
                PrayerView(model: model, ruleID: ruleID)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .psalter:
                Header(title: "The Psalter") { model.screen = .main }
                PsalterView(model: model)
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
        .background(ChotkiBackdrop())
        .preferredColorScheme(.dark)
        .glossaryDetour(model: model, backTitle: "Back to \(model.tab.rawValue)", enabled: model.navigationSurface == .companion)
        .overlay { if model.settings.shouldAskForSpiritualFather(on: model.today) { FatherPrompt(model: model) } }
        // The popover is the only thing on screen when the Dock icon is off.
        // The curtain waits until this window is actually visible, so a hidden
        // popover cannot spend the one cold open.
        .overlay { ColdOpenCurtain(model: model) }
    }

    private var underlyingScreen: Screen {
        if case .glossary = model.screen { return model.glossaryReturn }
        return model.screen
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { candidate in
                Button {
                    // The tab itself is not a reading rule, so it does not
                    // leave the last rule's section open.
                    if candidate == .reading {
                        model.readingFocus = nil
                        model.readingRequest = UUID()
                    }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { model.tab = candidate }
                } label: {
                    Text(candidate.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(model.tab == candidate ? Theme.parchment : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .duePulse(until: candidate.dueDestination.flatMap { model.attentionUntil[$0] })
                        .overlay(alignment: .bottom) {
                            if model.tab == candidate {
                                Capsule().fill(Theme.gold).frame(height: 2)
                                    .matchedGeometryEffect(id: "tab-selection", in: selection)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.tab {
        case .rule: RuleTabView(model: model, compact: true)
        case .prayers: PrayerRopeView(model: model)
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
