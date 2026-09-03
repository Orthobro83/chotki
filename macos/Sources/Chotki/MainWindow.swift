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
    case reflections = "Reflections"
    case library = "Library"
    case glossary = "Glossary"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .rule: return "calendar"
        case .reading: return "book"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .reflections: return "square.and.pencil"
        case .library: return "square.grid.2x2"
        case .prayers: return "hands.sparkles"
        case .glossary: return "text.book.closed"
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
    /// The service texts, as a sheet over the Reading. `nil` is the list; an
    /// id opens straight into that text, which is what a link from elsewhere
    /// in the app would want.
    case serviceTexts(String?)
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
        // The Psalter lives under Prayers in the window, as the rope does.
        case .psalter: return .section(.prayers)
        // Under Reading in the window, as they are in the popover.
        case .serviceTexts: return .serviceTexts(nil)
        case .serviceText(let id): return .serviceTexts(id)
        case .reflections: return .section(.reflections)  // the weekday is read by the view
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
    @State private var section: MainSection

    /// `initialSection` exists for the render harness.
    ///
    /// The sidebar's selection is `@State`, so nothing outside this view can
    /// move it — which is why the harness has to build its shots in one
    /// careful order and can never go back. A section it cannot reach at all
    /// is a section that gets signed off unseen, which has happened here
    /// before. This lets it open a window already on the screen it wants.
    init(model: AppModel, initialSection: MainSection = .rule) {
        self.model = model
        _section = State(initialValue: initialSection)
    }

    /// Where the sidebar was before the current section, so Terms can go back to
    /// it. Cleared when it is used, otherwise pressing back on Terms would
    /// return to Terms.
    @State private var previousSection: MainSection?
    @State private var editing: EditorTarget?
    @State private var reading: EditorTarget?
    @State private var pendingSlug: String?
    @State private var services: ServiceSheet?

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, id: \.self, selection: sidebarSelection) { item in
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
                go(to: target)
            case .glossary(let slug):
                pendingSlug = slug
                go(to: .glossary)
            case .editor(let ruleID):
                editing = EditorTarget(ruleID: ruleID)
            case .prayers(let ruleID):
                reading = EditorTarget(ruleID: ruleID)
            case .serviceTexts(let id):
                go(to: .reading)
                services = ServiceSheet(openTextID: id)
            }
            model.screen = .main
        }
        .sheet(item: $services) { target in
            ServiceSheetView(model: model, openTextID: target.openTextID) { services = nil }
                .frame(width: 520, height: 680)
                .background(Theme.ground)
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

    /// Records where the reader was before moving, so a detour can be undone.
    private var sidebarSelection: Binding<MainSection> {
        Binding(get: { section }, set: { go(to: $0) })
    }

    private func go(to target: MainSection) {
        guard target != section else { return }
        previousSection = section
        section = target
    }

    @ViewBuilder private var detail: some View {
        switch section {
        case .rule: ruleSection
        case .reading: scrolling { ReadingViewContent(model: model) }
        case .progress: scrolling { ProgressTabViewContent(model: model) }
        // Its own ScrollView rather than `scrolling`, because the overlay has
        // to sit over the whole pane instead of inside the scrolled content.
        case .reflections: ReflectionsView(model: model)
        case .library: scrolling { LibraryViewContent(model: model) }
        case .prayers: PrayerRopeView(model: model)
        case .glossary:
            VStack(spacing: 0) {
                // A term is nearly always opened from somewhere — a word in a
                // prayer, the day's fasting note — and the way back matters more
                // here than on a section the reader chose deliberately.
                if let previousSection {
                    SectionBackRow(title: previousSection.rawValue) {
                        let target = previousSection
                        self.previousSection = nil
                        section = target
                    }
                }
                // Re-created when a different term is requested, so the glossary
                // seeds itself on the new slug.
                GlossaryView(model: model, initialSlug: pendingSlug)
                    .id(pendingSlug ?? "all")
            }
        case .settings: scrolling { SettingsViewContent(model: model) }
        }
    }

    /// Side by side needs room for both: the calendar will not shrink below its
    /// grid, so everything taken off the window comes out of the day, and past a
    /// point the rule titles wrap one letter to a line.
    private static let sideBySideWidth: CGFloat = 660

    /// Calendar beside the day when there is room for both, above it when there
    /// is not — which is how the popover shows it at 400 points.
    private var ruleSection: some View {
        GeometryReader { proxy in
            if proxy.size.width < Self.sideBySideWidth {
                // Stacked, the calendar is pinned along with the day: the window
                // has the height for both, and losing the calendar is the thing
                // the layout was rearranged to avoid.
                RuleTabView(model: model, pinsCalendar: true)
            } else {
                sideBySideRule
            }
        }
    }

    private var sideBySideRule: some View {
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
                    DayAndLibrary(model: model, inset: 6, masksAbove: true)
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

/// Back to the section the reader came from, shown above the glossary.
private struct SectionBackRow: View {
    let title: String
    let back: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: back) {
                Label("Back to \(title)", systemImage: "chevron.left")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.lineSoft).frame(height: 1) }
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
        // The stacked layout needs about what the popover needs, plus the
        // sidebar. Below this it is squashed however it is arranged.
        window.minSize = NSSize(width: 620, height: 480)
        window.center()
        window.delegate = self
        window.contentView = MainWindowController.hostingView(model: model)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    /// The window's content view, with SwiftUI's sizing detached from it.
    ///
    /// **The window's size belongs to whoever set it, not to what is inside.**
    /// `NSHostingView` defaults to `.standardBounds`, which lets AppKit ask
    /// SwiftUI for an intrinsic size and resize the window to satisfy it. A
    /// `ScrollView` asked for its intrinsic height answers with the height of
    /// *all* its content, not the height it is being shown at — so anything
    /// that invalidates the layout while a tall section is open makes the
    /// window jump.
    ///
    /// That is exactly what opening the Reflections explainer did: one help
    /// mark, and the window stretched to the full height of the screen. Clearing
    /// the options fixes it for every section rather than for that one.
    static func hostingView(model: AppModel) -> NSHostingView<MainWindowView> {
        let host = NSHostingView(rootView: MainWindowView(model: model))
        host.sizingOptions = []
        return host
    }

    var isOpen: Bool { window?.isVisible ?? false }
}
