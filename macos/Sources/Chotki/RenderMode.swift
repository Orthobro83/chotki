import SwiftUI
import AppKit
import ChotkiCore

/// Renders the interface to PNG files without opening a window.
///
/// A development affordance for checking layout: it works on a throwaway copy
/// of the database so nothing real is touched, and it never reads the screen.
@MainActor
enum RenderMode {

    static func run(prefix: String) {
        do {
            let store = try seededStore()
            let model = AppModel(
                store: store, notifier: NullNotifier(), launchAtLogin: NullLaunchAtLogin()
            )

            // Content views directly: ImageRenderer does not draw ScrollView
            // contents, so the scroll chrome is bypassed.
            // Populate the liturgical cache synchronously so shading is
            // representative; the app does this asynchronously at launch.
            try? model.liturgical.loadSnapshot(around: model.today)

            render(
                ZStack {
                    RuleBackdrop()
                    RuleTabViewContent(model: model)
                },
                to: "\(prefix)-rule.png"
            )
            render(ReadingViewContent(model: model),
                   to: "\(prefix)-reading.png")
            render(ProgressTabViewContent(model: model),
                   to: "\(prefix)-progress.png")
            render(LibraryViewContent(model: model),
                   to: "\(prefix)-library.png")
            if let morning = model.rules.first(where: { $0.hasPrayers }) {
                render(PrayerViewContent(model: model, ruleID: morning.id),
                       to: "\(prefix)-prayers.png")
            }

            render(RopeWords(model: model, selection: "morning").padding(20), to: "\(prefix)-ropewords.png")

            // The rope follows the prayer: shown for a counted one, hidden for a
            // rule that is read through, shown when nothing is chosen.
            for (selection, name) in [("jesus-prayer", "rope"), ("morning", "rope-read"), (nil, "rope-alone")] {
                model.prayers = PrayerScreen(selection: selection, count: 21)
                render(PrayerRopeView(model: model).frame(height: Theme.popoverHeight),
                       to: "\(prefix)-\(name).png")
            }

            FileHandle.standardOutput.write(Data("rendered\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("render failed: \(error)\n".utf8))
        }
        NSApp.terminate(nil)
    }

    /// A copy of the real database, so the liturgical cache is realistic, plus a
    /// few rules to show. The original is never opened for writing.
    /// A throwaway store holding sample rules and nothing personal.
    ///
    /// Only the liturgical cache is taken from the real database — the calendar
    /// is the same for everyone. Rules, activations and occurrences are made up
    /// here, so a screenshot can never carry someone's actual practice into a
    /// public README.
    private static func seededStore() throws -> any Store {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-render-\(UUID().uuidString).sqlite")
        let store = try SQLiteStore(path: temp.path)
        let today = CalendarDate(Date(), in: .current)

        if ProcessInfo.processInfo.environment["CHOTKI_RENDER_LIVE"] == "1" {
            // Inspecting real state: copy the whole database, including the WAL,
            // which holds anything not yet checkpointed.
            if let real = try? StoreLocation.databasePath(),
               FileManager.default.fileExists(atPath: real) {
                let copy = FileManager.default.temporaryDirectory
                    .appendingPathComponent("chotki-live-\(UUID().uuidString).sqlite")
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.copyItem(
                        atPath: real + suffix, toPath: copy.path + suffix
                    )
                }
                return try SQLiteStore(path: copy.path)
            }
            return store
        }

        // Carry across the calendar only.
        if let real = try? StoreLocation.databasePath(),
           FileManager.default.fileExists(atPath: real) {
            let source = try SQLiteStore(path: real)
            let settings = (try? source.loadSettings()) ?? .default
            for reckoning in Reckoning.allCases {
                let days = (try? source.liturgicalDays(
                    reckoning: reckoning,
                    from: today.adding(days: -40), through: today.adding(days: 40)
                )) ?? []
                for day in days { try store.saveLiturgicalDay(day) }
            }
            var clean = AppSettings.default
            clean.jurisdiction = settings.jurisdiction
            clean.observances = ObservanceSettings(fasting: .observed, feasts: .shown)
            clean.hasCompletedFirstRun = true
            try store.saveSettings(clean)
        }

        // A believable rule, kept mostly but not perfectly.
        let sample: [(String, TimeOfDay?, Recurrence, RuleCategory)] = [
            ("Morning prayers", TimeOfDay(hour: 6, minute: 30), .daily, .prayer),
            ("The Wednesday and Friday fast", nil,
             .weekly(days: [.wednesday, .friday]), .fasting),
            ("Read the day's Gospel", TimeOfDay(hour: 12, minute: 0), .daily, .reading),
            ("Jesus prayer — 50 knots", nil, .daily, .prayer),
            ("Evening prayers", TimeOfDay(hour: 21, minute: 30), .daily, .prayer)
        ]

        for (title, time, recurrence, category) in sample {
            // Prefer the real template, so the sample carries its prayers.
            let template = RuleLibrary.shared.templates.first { $0.title == title }
            let rule = template?.makeRule(source: "the library") ?? Rule(
                title: title, source: "the library", recurrence: recurrence,
                timeOfDay: time, category: category.rawValue
            )
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: today.adding(days: -40)))

            for offset in 0...40 {
                let date = today.adding(days: -offset)
                // Evening prayers slip on Fridays; one stretch of the prayer
                // rope stood down; everything else held.
                if title == "Evening prayers" && date.weekday == .friday { continue }
                if title == "Jesus prayer — 50 knots" && (12...15).contains(offset) {
                    try store.save(Occurrence(ruleID: rule.id, date: date, status: .skipped))
                    continue
                }
                // Today: only the morning is done so far.
                if offset == 0 && title != "Morning prayers" { continue }
                let status: OccurrenceStatus = offset % 13 == 0 ? .completedLate : .completed
                try store.save(Occurrence(ruleID: rule.id, date: date, status: status))
            }
        }
        return store
    }

    /// Renders the real window, through AppKit rather than ImageRenderer.
    ///
    /// `ImageRenderer` cannot draw the contents of a ScrollView, nor AppKit
    /// controls like a Picker's menu button. That covers most of this app: the
    /// library, the glossary, the prayers and the whole window are scrolled, and
    /// the harness has silently drawn them as empty panels — which is how a
    /// missing feature once got signed off here.
    ///
    /// Putting the view in a real window and asking the view hierarchy to draw
    /// itself gets all of it. The window is positioned far off any screen and
    /// never ordered in front of anything: this draws the view, it does not
    /// capture the display.
    static func runWindow(prefix: String) {
        do {
            let store = try seededStore()
            let model = AppModel(
                store: store, notifier: NullNotifier(), launchAtLogin: NullLaunchAtLogin()
            )
            try? model.liturgical.loadSnapshot(around: model.today)

            let size = NSSize(width: 940, height: 660)
            let host = NSHostingView(rootView: MainWindowView(model: model))
            host.frame = NSRect(origin: .zero, size: size)

            let window = NSWindow(
                contentRect: host.frame,
                styleMask: [.titled, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.contentView = host
            window.setFrameOrigin(NSPoint(x: -30_000, y: -30_000))
            window.orderFrontRegardless()

            func shot(_ name: String, _ arrange: () -> Void) {
                draw(host, name, prefix: prefix, arrange)
            }

            shot("window-rule") { }
            shot("window-library-drawer") { model.libraryOnRule = true }
            shot("window-library-scrolled") { scrollDown(host, by: 420) }
            shot("window-prayers") {
                model.libraryOnRule = false
                model.prayers = PrayerScreen(selection: "morning")
                model.screen = .prayerRope
            }
            // A drawn menu button shows only its selected title, so the chooser's
            // contents were the one thing a screenshot could not confirm. Ask the
            // control itself, while the prayers screen is still up.
            describeMenus(in: host)

            shot("window-terms-back") { model.openGlossary("publican") }

            // The popover is the surface most people use, and until now none of
            // it could be drawn: every screen in it is inside a ScrollView.
            model.screen = .main
            model.libraryOnRule = false
            let popover = NSHostingView(rootView: RootView(model: model))
            popover.frame = NSRect(
                x: 0, y: 0, width: Theme.popoverWidth, height: Theme.popoverHeight
            )
            window.contentView = popover
            window.setContentSize(popover.frame.size)

            draw(popover, "popover-rule", prefix: prefix) { }
            draw(popover, "popover-library-drawer", prefix: prefix) { model.libraryOnRule = true }
            draw(popover, "popover-library-scrolled", prefix: prefix) {
                scrollDown(popover, by: 420)
            }
            draw(popover, "popover-prayers", prefix: prefix) {
                model.libraryOnRule = false
                model.prayers = PrayerScreen(selection: "jesus-prayer", count: 12)
                model.screen = .prayerRope
            }
            draw(popover, "popover-terms-back", prefix: prefix) { model.openGlossary("amen") }

            FileHandle.standardOutput.write(Data("rendered\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("window render failed: \(error)\n".utf8))
        }
        NSApp.terminate(nil)
    }

    /// Arrange, let SwiftUI settle, then ask the view to draw itself.
    private static func draw(
        _ host: NSView, _ name: String, prefix: String, _ arrange: () -> Void
    ) {
        arrange()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
        FileHandle.standardOutput.write(Data("\(name)\n".utf8))
    }

    /// Scrolls the tallest scroll view in the hierarchy, so that anything which
    /// only happens part-way down — a pinned header, content passing under it —
    /// can actually be seen. SwiftUI's ScrollView is an NSScrollView underneath.
    @discardableResult
    private static func scrollDown(_ view: NSView, by amount: CGFloat) -> Bool {
        var found: [NSScrollView] = []
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView { found.append(scroll) }
            for subview in view.subviews { walk(subview) }
        }
        walk(view)

        // The tallest content is the one worth scrolling: in the window the day
        // column holds the library, while the calendar beside it barely moves.
        guard let scroll = found.max(by: {
            ($0.documentView?.bounds.height ?? 0) < ($1.documentView?.bounds.height ?? 0)
        }) else { return false }

        scroll.contentView.scroll(to: NSPoint(x: 0, y: amount))
        scroll.reflectScrolledClipView(scroll.contentView)
        return true
    }

    /// Prints what any pop-up menu in the hierarchy actually offers.
    private static func describeMenus(in view: NSView) {
        if let popup = view as? NSPopUpButton {
            let titles = popup.itemArray.map { item -> String in
                if item.isSeparatorItem { return "──" }
                return item.title.isEmpty ? "(blank)" : item.title
            }
            let line = "menu: " + titles.joined(separator: " | ") + "\n"
            FileHandle.standardOutput.write(Data(line.utf8))
        }
        for subview in view.subviews { describeMenus(in: subview) }
    }

    private static func render(_ view: some View, to path: String) {
        // A ScrollView needs a definite height to lay out; the real popover
        // gets one from its contentSize, so give the renderer the same. The
        // ground goes on outside the frame, so a view shorter than the popover
        // leaves dark space rather than white bands.
        let renderer = ImageRenderer(
            content: view
                .frame(width: Theme.popoverWidth, height: Theme.popoverHeight, alignment: .top)
                .background(Theme.ground)
        )
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

/// Stand-ins so rendering never schedules or registers anything.
private struct NullNotifier: Notifier {
    var supportsActions: Bool { false }
    func requestAuthorization() async throws -> Bool { false }
    func show(_ request: NotificationRequest) async throws {}
    func cancel(ids: [String]) async {}
    var actionEvents: AsyncStream<NotificationActionEvent> { AsyncStream { $0.finish() } }
}

private struct NullLaunchAtLogin: LaunchAtLogin {
    var isEnabled: Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}
