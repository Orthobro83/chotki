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

            render(RopeWords(selection: "morning").padding(20), to: "\(prefix)-ropewords.png")

            // The rope follows the prayer: shown for a counted one, hidden for a
            // rule that is read through, shown when nothing is chosen.
            for (selection, name) in [("jesus-prayer", "rope"), ("morning", "rope-read"), ("none", "rope-alone")] {
                render(PrayerRopeView(model: model, startingAt: 21, showing: selection)
                        .frame(height: Theme.popoverHeight),
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
