import SwiftUI
import AppKit
import ChotkiCore

/// What the sidebar offers. The popover's three tabs plus the things that are
/// cramped at 400 points.
enum MainSection: String, CaseIterable, Hashable {
    case rule = "Rule"
    case reading = "Reading"
    case prayers = "Prayers"
    case progress = "Progress"
    case library = "Library"
    case terms = "Terms"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .rule: return "calendar"
        case .reading: return "book"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .library: return "square.grid.2x2"
        case .prayers: return "hands.sparkles"
        case .terms: return "text.book.closed"
        case .settings: return "gearshape"
        }
    }
}

/// The full window. Same model, same content, given room — the month grid and
/// the day's rules sit side by side instead of stacked in a column.
/// Where a navigation request from shared content lands in the window.
///
/// Extracted from the view so it can be tested: shared content navigates by
/// setting `model.screen`, which is the popover's mechanism, and a screen the
/// window forgets to handle is a control that silently does nothing there while
/// working perfectly in the popover.
enum WindowRoute: Equatable {
    case section(MainSection)
    case editor(UUID?)
    case prayers(UUID)
    case glossary(String?)
    /// Already where it needs to be.
    case stay

    static func route(for screen: Screen) -> WindowRoute {
        switch screen {
        case .main: return .stay
        case .library: return .section(.library)
        case .settings: return .section(.settings)
        case .glossary(let slug): return .glossary(slug)
        case .editor(let ruleID): return .editor(ruleID)
        case .prayerRope: return .section(.prayers)
        case .prayers(let ruleID): return .prayers(ruleID)
        }
    }
}

/// A rule being edited in the window, as a sheet.
private struct EditorTarget: Identifiable {
    let ruleID: UUID?
    var id: String { ruleID?.uuidString ?? "new" }
}

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @State private var section: MainSection = .rule
    @State private var editing: EditorTarget?
    @State private var reading: EditorTarget?
    @State private var pendingSlug: String?

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, id: \.self, selection: $section) { item in
                Label(item.rawValue, systemImage: item.symbol)
                    .font(.system(size: 13))
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 168, ideal: 180, max: 220)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.ground)
        }
        .navigationTitle(section.rawValue)
        // Buttons inside shared content navigate by setting `model.screen`,
        // which is the popover's mechanism. The window has a sidebar instead,
        // so it translates those requests rather than ignoring them — without
        // this, Add, Library, Terms, Settings and the edit pencil are all dead
        // in the window while working perfectly in the popover.
        .onReceive(model.$screen) { screen in
            switch WindowRoute.route(for: screen) {
            case .stay:
                return
            case .section(let target):
                section = target
            case .glossary(let slug):
                pendingSlug = slug
                section = .terms
            case .editor(let ruleID):
                editing = EditorTarget(ruleID: ruleID)
            case .prayers(let ruleID):
                reading = EditorTarget(ruleID: ruleID)
            }
            model.screen = .main
        }
        .sheet(item: $reading) { target in
            VStack(spacing: 0) {
                Header(title: "Prayers") { reading = nil }
                if let ruleID = target.ruleID {
                    PrayerView(model: model, ruleID: ruleID)
                }
            }
            .frame(width: 460, height: 620)
            .background(Theme.ground)
        }
        .sheet(item: $editing) { target in
            VStack(spacing: 0) {
                Header(title: target.ruleID == nil ? "New rule" : "Edit rule") { editing = nil }
                RuleEditorView(model: model, ruleID: target.ruleID) { editing = nil }
            }
            .frame(width: 430, height: 580)
            .background(Theme.ground)
        }
    }

    @ViewBuilder private var detail: some View {
        switch section {
        case .rule: ruleSection
        case .reading: scrolling { ReadingViewContent(model: model) }
        case .progress: scrolling { ProgressTabViewContent(model: model) }
        case .library: scrolling { LibraryViewContent(model: model) }
        case .prayers: PrayerRopeView(model: model)
        case .terms:
            // Re-created when a different term is requested, so the glossary
            // seeds itself on the new slug.
            GlossaryView(model: model, initialSlug: pendingSlug)
                .id(pendingSlug ?? "all")
        case .settings: scrolling { SettingsViewContent(model: model) }
        }
    }

    /// The one layout that genuinely benefits from the extra width: calendar
    /// beside the day rather than above it.
    private var ruleSection: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                MonthGridView(model: model)
                    .frame(width: 340)
            }
            .frame(width: 340)
            .scrollContentBackgroundHidden()

            Rectangle().fill(Theme.line).frame(width: 1)

            ZStack {
                // The window has far more empty panel than the popover, so the
                // marks matter more here — and this is the surface that opens
                // by default.
                RuleBackdrop(crossHeight: 150, markSize: 34)

                ScrollView {
                    DayPanel(model: model)
                        .padding(.horizontal, 6)
                }
                .scrollContentBackgroundHidden()
            }
        }
    }

    private func scrolling<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackgroundHidden()
    }
}

/// Keeps a single main window rather than opening one per request.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Chotki"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 520)
        window.center()
        window.delegate = self
        window.contentView = NSHostingView(rootView: MainWindowView(model: model))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    var isOpen: Bool { window?.isVisible ?? false }
}
