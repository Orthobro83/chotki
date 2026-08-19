import SwiftUI
import AppKit
import ChotkiCore

/// What the sidebar offers. The popover's three tabs plus the things that are
/// cramped at 400 points.
enum MainSection: String, CaseIterable, Hashable {
    case rule = "Rule"
    case reading = "Reading"
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
        case .terms: return "text.book.closed"
        case .settings: return "gearshape"
        }
    }
}

/// The full window. Same model, same content, given room — the month grid and
/// the day's rules sit side by side instead of stacked in a column.
struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @State private var section: MainSection = .rule

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
    }

    @ViewBuilder private var detail: some View {
        switch section {
        case .rule: ruleSection
        case .reading: scrolling { ReadingViewContent(model: model) }
        case .progress: scrolling { ProgressTabViewContent(model: model) }
        case .library: scrolling { LibraryViewContent(model: model) }
        case .terms: GlossaryView(model: model, initialSlug: nil)
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

            ScrollView {
                DayPanel(model: model)
                    .padding(.horizontal, 6)
            }
            .scrollContentBackgroundHidden()
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
