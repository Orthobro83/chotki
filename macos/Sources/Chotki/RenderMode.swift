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
    /// few rules to show. The original is never opened at all — see
    /// `readOnlyCopy(of:)`, and why that had to be written.
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
           FileManager.default.fileExists(atPath: real),
           let source = try? readOnlyCopy(of: real) {
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
            // The welcome is a real screen and needs rendering like any other,
            // so it can be asked for. Every other render wants it out of the way.
            clean.hasCompletedFirstRun =
                ProcessInfo.processInfo.environment["CHOTKI_RENDER_FIRSTRUN"] != "1"
            try store.saveSettings(clean)
        }

        // Someone who already keeps rules is not on their first run, and the
        // app marks it complete for them — so the welcome can only be drawn
        // against an empty record, which is the only state it ever appears in.
        if ProcessInfo.processInfo.environment["CHOTKI_RENDER_FIRSTRUN"] == "1" {
            return store
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

        // Made-up answers, so the journal and its overlay have something to
        // draw. Invented here like every other sample: a reflection is the most
        // personal thing this app holds, and a screenshot must never be able to
        // carry a real one.
        try store.seedReflections()
        // On the rule, so the day list shows it with its way through to the
        // section and its pencil, which is the thing to look at.
        if let template = RuleLibrary.shared.templates.first(where: { $0.id == "reflection" }) {
            let rule = template.makeRule(source: "the library")
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: today.adding(days: -40)))
        }
        let invented: [(Weekday, Int, String)] = [
            (.sunday, 7, "It came up first thing, before I had said anything at all. Sat with it rather than moving on."),
            (.sunday, 14, "Less this week. Or I noticed it less, which is not the same thing."),
            (.sunday, 42, "Three weeks of writing nothing, and then this. The resistance was to the writing itself."),
            (.monday, 8, "Quieter than it has been. Kept the phone in the other room and the silence was not empty."),
            (.wednesday, 10, "Put off the call again. Third day."),
            (.wednesday, 45, "The same call. Noted then too, and did nothing about it."),
            (.friday, 12, "Late, and the cost was the hour I did not give."),
            (.saturday, 11, "Vigil. Confession after.")
        ]
        for (weekday, back, text) in invented {
            let date = today.adding(days: -back)
            // Land it on the weekday it belongs to, whatever today happens to be.
            let landed = date.adding(days: weekday.rawValue - date.weekday.rawValue)
            try store.save(ReflectionEntry(
                answering: Reflection.bundled(for: weekday), on: landed, text: text))
        }
        return store
    }

    /// A throwaway copy of the real database, opened instead of the original.
    ///
    /// **`SQLiteStore(path:)` migrates on open.** So reading the liturgical
    /// cache straight out of the live file wrote to it — every render run
    /// silently applied whatever migrations the working copy had that the
    /// installed app did not. It was caught when schema 7 turned up in Ryan's
    /// record before the build carrying it had ever been installed. Nothing was
    /// lost, because a migration only adds; the next one that rewrites a column
    /// would not have been so forgiving.
    ///
    /// The comment above this function used to say the original is never opened
    /// for writing. It says it again now, and this time it is true.
    ///
    /// `-wal` and `-shm` come too: without them a file-level copy silently
    /// loses whatever has not been checkpointed, which here is most of it.
    private static func readOnlyCopy(of path: String) throws -> SQLiteStore {
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-cache-\(UUID().uuidString).sqlite")
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.copyItem(
                atPath: path + suffix, toPath: copy.path + suffix
            )
        }
        return try SQLiteStore(path: copy.path)
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
            // Far enough to reach Custom, which sits at the foot of the library.
            shot("window-library-bottom") { scrollDown(host, by: 4000) }

            // Narrow enough that the calendar and the day cannot sit side by
            // side. This is the shape the window was squashed into before it
            // learned to rearrange. Taken here because the sidebar's selection
            // is @State: once it leaves Rule, nothing outside the view can send
            // it back.
            func resize(to width: CGFloat) {
                host.frame = NSRect(x: 0, y: 0, width: width, height: 660)
                window.setContentSize(NSSize(width: width, height: 660))
            }
            shot("window-narrow") {
                model.libraryOnRule = false
                scrollDown(host, by: 0)
                resize(to: 665)
            }
            shot("window-narrow-library") { model.libraryOnRule = true }
            shot("window-narrow-scrolled") { scrollDown(host, by: 420) }
            shot("window-min-width") {
                model.libraryOnRule = false
                resize(to: 620)
            }
            resize(to: 940)
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
            shot("window-terms-list") { model.openGlossary(nil) }
            shot("window-settings") { model.screen = .settings }
            describeMenus(in: host)
            // The calendar set away from what the chosen jurisdiction keeps.
            shot("window-settings-other-calendar") {
                model.update { $0.jurisdiction.reckoning = .revisedJulian }
            }
            shot("window-settings-twelve-hour") {
                model.update { $0.clockStyle = .twelveHour }
            }


            // Reflections, which the sidebar can reach but `model.screen`
            // cannot — so it gets a window of its own, opened straight onto it.
            resize(to: 940)
            // `.main` routes to `.stay`, so the fresh window keeps the section
            // it was opened on. Leaving the previous shot's screen in place
            // makes `onReceive` reroute it the instant it subscribes — which is
            // how the first attempt at this drew Settings and called it
            // Reflections.
            model.screen = .main
            let journal = NSHostingView(
                rootView: MainWindowView(model: model, initialSection: .reflections))
            journal.frame = NSRect(x: 0, y: 0, width: 940, height: 660)
            window.contentView = journal
            window.setContentSize(journal.frame.size)

            draw(journal, "window-reflections", prefix: prefix) { }
            draw(journal, "window-reflections-scrolled", prefix: prefix) {
                scrollDown(journal, by: 900)
            }
            // The foot of the section: what closes the week, and the file bar.
            draw(journal, "window-reflections-bottom", prefix: prefix) {
                scrollDown(journal, by: 6000)
            }

            // Both of these are raised by @State inside the view, so nothing
            // outside can open them. They get windows of their own rather than
            // borrowing this one: reusing it left the hosting view unconstrained
            // and it drew the whole section at its natural height — a strip
            // 12,810 pixels tall, which is not a screenshot of anything.
            inOwnWindow(
                ReflectionsView(model: model, initialReading: .sunday),
                size: NSSize(width: 780, height: 560),
                "window-reflections-reading", prefix: prefix)

            // Opened from a Friday rule, which should land on Friday rather
            // than at the top. A ScrollViewReader scroll may simply not appear
            // in a drawn view — if this shot shows Sunday, that is not evidence
            // the scroll is broken, only that the harness could not see it.
            model.reflectionsOpenAt = .friday
            inOwnWindow(
                ReflectionsView(model: model),
                size: NSSize(width: 780, height: 560),
                "window-reflections-opened-on-friday", prefix: prefix)
            model.reflectionsOpenAt = nil

            // The explainer behind the help mark. It animates down, which a
            // still cannot show — but whether the text is there, wraps, and
            // carries its link is exactly what a still is for.
            inOwnWindow(
                ReflectionsView(model: model, initialExplaining: true),
                size: NSSize(width: 780, height: 560),
                "window-reflections-explainer", prefix: prefix)

            window.contentView = host
            window.setContentSize(NSSize(width: 940, height: 660))

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

            // The welcome exists only on a first run, which is the record
            // `CHOTKI_RENDER_FIRSTRUN` seeds. Against any other it would be the
            // rule screen wearing the wrong filename, so it is not drawn at all.
            //
            // The notice is cleared because the settings renders above leave one
            // standing, and it pushed the popover 52pt past its own height. The
            // welcome is what someone sees before anything has happened to them:
            // it is the one screen that must carry nothing into it.
            if ProcessInfo.processInfo.environment["CHOTKI_RENDER_FIRSTRUN"] == "1" {
                draw(popover, "popover-welcome", prefix: prefix) {
                    model.screen = .main
                    model.libraryOnRule = false
                    model.notice = nil
                }
            }

            FileHandle.standardOutput.write(Data("rendered\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("window render failed: \(error)\n".utf8))
        }
        NSApp.terminate(nil)
    }

    /// Draws one view in an off-screen window of its own.
    ///
    /// Needed for anything a view raises through its own `@State`, which
    /// nothing outside it can reach. Sharing the main window for this left the
    /// hosting view unconstrained and it grew to its natural height.
    private static func inOwnWindow<Root: View>(
        _ root: Root, size: NSSize, _ name: String, prefix: String
    ) {
        // The explicit frame is the point. As the root of a window, a ScrollView
        // has nothing above it telling it how tall to be, so it reports its
        // content height and the hosting view grows to match — which drew the
        // explainer as a strip 12,786 pixels tall. In the app the split view's
        // detail column does this constraining.
        // The ground and the dark appearance come from the window in the app —
        // `MainWindowView` paints the detail column — so a view hosted on its
        // own has to be given both, or it draws dark text on white.
        let host = NSHostingView(
            rootView: root
                .frame(width: size.width, height: size.height)
                .background(Theme.ground)
        )
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: -30_000, y: -30_000))
        window.orderFrontRegardless()
        draw(host, name, prefix: prefix) { }
        window.orderOut(nil)
    }

    /// Arrange, let SwiftUI settle, then ask the view to draw itself.
    private static func draw(
        _ host: NSView, _ name: String, prefix: String, _ arrange: () -> Void
    ) {
        arrange()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        host.layoutSubtreeIfNeeded()
        guard let rep = retinaRep(for: host) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(name).png"))
        FileHandle.standardOutput.write(Data("\(name)\n".utf8))
    }

    /// A bitmap at twice the point size, so this path matches the other one.
    ///
    /// `bitmapImageRepForCachingDisplay` hands back the view's backing store,
    /// and an off-screen window has no screen behind it to make that Retina —
    /// so every render through AppKit came out at 1x while the `ImageRenderer`
    /// path beside it was already at 2x, which is what the README's screenshots
    /// are. Building the rep by hand and then telling it its size in *points*
    /// is what makes it a 2x representation; `cacheDisplay` draws into it
    /// scaled to suit.
    private static func retinaRep(for host: NSView) -> NSBitmapImageRep? {
        let size = host.bounds.size
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = size
        return rep
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

        // `scroll(to:)` does not clamp: ask for more than there is and it goes
        // straight past the end into blank space, which looks exactly like a
        // view that failed to draw.
        let travel = (scroll.documentView?.bounds.height ?? 0) - scroll.contentView.bounds.height
        scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, min(amount, travel))))
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
