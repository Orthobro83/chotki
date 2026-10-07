import SwiftUI
import AppKit
import ChotkiCore

enum MainSection: String, CaseIterable, Hashable {
    case rule = "Home", prayers = "Prayers", reading = "Reading", progress = "Progress"
    case library = "Library", glossary = "Glossary", settings = "Settings"
    var symbol: String {
        switch self {
        case .rule: return "calendar"
        case .prayers: return "circle.hexagonpath"
        case .reading: return "book"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .library: return "square.grid.2x2"
        case .glossary: return "text.book.closed"
        case .settings: return "gearshape"
        }
    }
    static let groups: [(String, [MainSection])] = [
        ("The Day", [.rule]), ("To Read", [.prayers, .reading]),
        ("The Record", [.progress, .library]), ("Reference", [.glossary, .settings])
    ]
    var dueDestination: DueDestination? {
        switch self {
        case .rule: return .home
        case .prayers: return .prayers
        case .reading: return .reading
        default: return nil
        }
    }
}

enum WindowRoute: Equatable {
    case section(MainSection), editor(UUID?), prayers(UUID), glossary(String?), stay
    static func route(for screen: Screen) -> WindowRoute {
        switch screen {
        case .main: return .stay
        case .library: return .section(.library)
        case .settings: return .section(.settings)
        case .glossary(let slug): return .glossary(slug)
        case .editor(let id): return .editor(id)
        case .prayers(let id): return .prayers(id)
        case .prayerRope, .psalter: return .section(.prayers)
        }
    }
}

private struct EditorTarget: Identifiable {
    let ruleID: UUID?
    var id: String { ruleID?.uuidString ?? "new" }
}

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @State private var section: MainSection
    @State private var collapsed = false
    @State private var previousSection: MainSection?
    @State private var editing: EditorTarget?
    @State private var prayerRuleID: UUID?
    @State private var pendingSlug: String?
    @State private var psalter = false
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel, initialSection: MainSection = .rule, initiallyCollapsed: Bool = false) {
        self.model = model
        _section = State(initialValue: initialSection)
        _collapsed = State(initialValue: initiallyCollapsed)
    }
    private var motion: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.28) }

    var body: some View {
        Group {
            if model.settings.hasCompletedFirstRun {
                installed
            } else {
                FirstRunView(model: model)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .background(ChotkiBackdrop()).preferredColorScheme(.dark)
        .overlay { if model.settings.shouldAskForSpiritualFather(on: model.today) { FatherPrompt(model: model) } }
        .overlay { ColdOpenCurtain(model: model) }
        .animation(motion, value: section).animation(motion, value: collapsed)
        .onReceive(model.$tab.dropFirst()) { tab in
            guard model.navigationSurface == .window else { return }
            // Tab changes are navigation requests from shared content.
            if let target = MainSection(rawValue: tab.rawValue) { go(to: target) }
        }
        .onReceive(model.$screen) { screen in
            guard model.navigationSurface == .window else { return }
            switch WindowRoute.route(for: screen) {
            case .stay: return
            case .section(let target):
                psalter = screen == .psalter
                if target == .prayers { prayerRuleID = nil }
                go(to: target)
            case .glossary: return
            case .editor(let id): editing = EditorTarget(ruleID: id)
            case .prayers(let id): prayerRuleID = id; psalter = false; go(to: .prayers)
            }
        }
        .sheet(item: $editing) { target in
            VStack(spacing: 0) {
                Header(title: target.ruleID == nil ? "New Rule" : "Edit Rule") { editing = nil; model.editorDraft = nil; model.screen = .main }
                RuleEditorView(model: model, ruleID: target.ruleID) { editing = nil; model.editorDraft = nil; model.screen = .main }
            }.frame(width: 520, height: 680).background(ChotkiBackdrop()).preferredColorScheme(.dark)
        }
    }

    private var installed: some View {
        HStack(spacing: 0) {
            // Higher priority, and a fixed width, so a wide day never takes
            // the sidebar's space and slides it out of the window.
            sidebar.layoutPriority(1)
            Rectangle().fill(Theme.lineSoft).frame(width: 1).layoutPriority(1)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(section == .rule ? model.greeting : section.rawValue)
                        .font(Theme.reading(28)).foregroundStyle(Theme.parchment)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if model.isReviewSample {
                        Button { model.previewDueAlert() } label: { Image(systemName: "bell.badge") }
                            .buttonStyle(.plain).foregroundStyle(Theme.gold)
                            .help("Preview Due Alert")
                            .accessibilityLabel("Preview Due Alert")
                    }
                    if section == .rule {
                        Button { go(to: .library) } label: { Image(systemName: "plus") }
                            .buttonStyle(.plain).foregroundStyle(Theme.gold).help("Open the Library")
                    }
                }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 18)
                detail.id(section)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 10)), removal: .opacity))
                NoticeLine(model: model)
            }
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .glossaryDetour(model: model, backTitle: "Back to \(section.rawValue)", enabled: model.navigationSurface == .window)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { collapsed.toggle() } label: {
                Image(systemName: "sidebar.left").font(.system(size: 16)).frame(width: 30, height: 32)
            }.buttonStyle(.plain).foregroundStyle(Theme.muted)
                .help(collapsed ? "Expand Sidebar" : "Collapse Sidebar")
                .accessibilityLabel(collapsed ? "Expand Sidebar" : "Collapse Sidebar")
                .keyboardShortcut("s", modifiers: [.command, .control])
            ForEach(MainSection.groups, id: \.0) { heading, items in
                if !collapsed {
                    Text(heading).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted)
                        .padding(.leading, 10).padding(.top, 16).padding(.bottom, 3)
                } else { Spacer().frame(height: 12) }
                ForEach(items, id: \.self) { item in
                    Button {
                        if item == .reading {
                            model.readingFocus = nil
                            model.readingRequest = UUID()
                        }
                        psalter = false
                        prayerRuleID = nil
                        model.screen = .main
                        go(to: item)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).frame(width: 18)
                            if !collapsed { Text(item.rawValue); Spacer(minLength: 0) }
                        }.font(.system(size: 13)).padding(.horizontal, 10).frame(height: 36)
                            .foregroundStyle(section == item ? Theme.parchment : Theme.muted)
                            .background {
                                if section == item {
                                    RoundedRectangle(cornerRadius: 8).fill(Theme.panel)
                                        .matchedGeometryEffect(id: "sidebar-selection", in: selection)
                                }
                            }
                            .duePulse(until: item.dueDestination.flatMap { model.attentionUntil[$0] })
                    }.buttonStyle(.plain).help(item.rawValue).accessibilityLabel(item.rawValue)
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                }
            }
            Spacer(minLength: 0)
        }.padding(10).frame(width: collapsed ? 58 : 188)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxHeight: .infinity, alignment: .top).background(Theme.ground.opacity(0.24))
    }

    private func go(to target: MainSection) {
        guard section != target else { return }
        previousSection = section
        section = target
    }

    @ViewBuilder private var detail: some View {
        switch section {
        case .rule: RuleTabView(model: model, onOpenLibrary: { go(to: .library) })
        case .prayers:
            if psalter {
                VStack(spacing: 0) {
                    Header(title: "The Psalter") { psalter = false }
                    PsalterView(model: model)
                }
            } else if let prayerRuleID {
                VStack(spacing: 0) {
                    Header(title: "Prayers") { self.prayerRuleID = nil; model.screen = .main }
                    PrayerView(model: model, ruleID: prayerRuleID)
                }
            } else { PrayerRopeView(model: model, diameter: 240) }
        case .reading: ReadingView(model: model)
        case .progress: ProgressTabView(model: model)
        case .library: LibraryView(model: model)
        case .settings: SettingsView(model: model)
        case .glossary:
            VStack(spacing: 0) {
                if let previousSection {
                    Header(title: "Back to \(previousSection.rawValue)") {
                        section = previousSection
                        self.previousSection = nil
                    }
                }
                GlossaryView(model: model, initialSlug: pendingSlug).id(pendingSlug ?? "all")
            }
        }
    }
}

/// Keeps a single main window rather than opening one per request.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var model: AppModel?

    func show(model: AppModel) {
        self.model = model
        model.navigationSurface = .window
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Chotki"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        window.contentView = MainWindowController.hostingView(model: model)
        applyMinimumSize(to: window)
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
    /// A tall explanation once stretched the window to the full height of the
    /// screen. Clearing the sizing options fixes that for every section.
    static func hostingView(model: AppModel) -> NSHostingView<MainWindowView> {
        let host = WindowHostingView(rootView: MainWindowView(model: model))
        host.sizingOptions = []
        host.clipsToBounds = true
        return host
    }

    /// Content size, not the frame. The expanded sidebar is 188 points, and
    /// the week beside it needs the rest of 620 to stay whole. Below 540
    /// points of content the day is a title and a sliver.
    static let minimumContentSize = NSSize(width: 620, height: 540)

    var isOpen: Bool { window?.isVisible ?? false }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minimum = sender.frameRect(forContentRect: NSRect(origin: .zero, size: Self.minimumContentSize)).size
        return NSSize(width: max(frameSize.width, minimum.width), height: max(frameSize.height, minimum.height))
    }

    func windowDidResize(_ notification: Notification) {
        guard let window else { return }
        applyMinimumSize(to: window)
        let minimum = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.minimumContentSize)).size
        var frame = window.frame
        let width = max(frame.width, minimum.width)
        let height = max(frame.height, minimum.height)
        guard abs(width - frame.width) > 0.5 || abs(height - frame.height) > 0.5 else { return }
        frame.size = NSSize(width: width, height: height)
        window.setFrame(frame, display: true)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model?.navigationSurface = .window
    }

    private func applyMinimumSize(to window: NSWindow) {
        window.contentMinSize = Self.minimumContentSize
        window.minSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.minimumContentSize)).size
    }
}

/// Hosts the main window without letting SwiftUI decide how big it is.
///
/// The hosting view wants constraint layout and reports the SwiftUI ideal
/// size. That size is the home row, the week, and a picture scaled to pan —
/// wider than the window. With no autoresizing mask the view keeps that
/// width, and dragging the window smaller leaves the extra off the leading
/// edge, sidebar included. No intrinsic size, and the ordinary width-and-height
/// mask, make the view the window's size instead.
final class WindowHostingView<Content: View>: NSHostingView<Content> {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override class var requiresConstraintBasedLayout: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        followTheWindow()
    }

    override func layout() {
        followTheWindow()
        super.layout()
        followTheWindow()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        followTheWindow()
    }

    private func followTheWindow() {
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.width, .height]
        clipsToBounds = true
    }
}
