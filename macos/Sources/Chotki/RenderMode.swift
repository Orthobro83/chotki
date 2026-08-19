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

            // The whole shell, to confirm it is a fixed size no matter which
            // screen is showing.
            render(RootView(model: model), to: "\(prefix)-shell-main.png")
            model.screen = .settings
            render(RootView(model: model), to: "\(prefix)-shell-settings.png")
            model.screen = .main

            render(ReadingViewContent(model: model).background(Theme.ground), to: "\(prefix)-reading.png")

            render(OnboardingView(model: model).background(Theme.ground), to: "\(prefix)-onboarding.png")
            render(PrayerRopeView(model: model).background(Theme.ground), to: "\(prefix)-rope.png")

            render(ProgressTabViewContent(model: model).background(Theme.ground), to: "\(prefix)-progress.png")

            render(RuleTabViewContent(model: model).background(Theme.ground), to: "\(prefix)-rule.png")

            render(LibraryViewContent(model: model).background(Theme.ground), to: "\(prefix)-library.png")
            render(SettingsViewContent(model: model).background(Theme.ground), to: "\(prefix)-settings.png")

            FileHandle.standardOutput.write(Data("rendered\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("render failed: \(error)\n".utf8))
        }
        NSApp.terminate(nil)
    }

    /// A copy of the real database, so the liturgical cache is realistic, plus a
    /// few rules to show. The original is never opened for writing.
    private static func seededStore() throws -> any Store {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-render-\(UUID().uuidString).sqlite")
        if let real = try? StoreLocation.databasePath(),
           FileManager.default.fileExists(atPath: real) {
            // The write-ahead log holds anything not yet checkpointed, which is
            // most of it on a freshly written database. Copying the .sqlite
            // alone silently loses recent data.
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.copyItem(
                    atPath: real + suffix, toPath: temp.path + suffix
                )
            }
        }
        let store = try SQLiteStore(path: temp.path)

        let today = CalendarDate(Date(), in: .current)
        let seeds: [(String, TimeOfDay?)] = [
            ("Morning prayers", TimeOfDay(hour: 6, minute: 30)),
            ("Read the day's Gospel", TimeOfDay(hour: 12, minute: 0)),
            ("Jesus prayer — 50 knots", nil),
            ("Evening prayers", TimeOfDay(hour: 21, minute: 30))
        ]
        for (title, time) in seeds {
            let rule = Rule(title: title, recurrence: .daily, timeOfDay: time)
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: today.adding(days: -40)))

            // A believable history: mostly kept, evening prayers slipping on
            // Fridays, one stretch stood down.
            for offset in 1...40 {
                let date = today.adding(days: -offset)
                if title == "Evening prayers" && date.weekday == .friday { continue }
                if title == "Jesus prayer — 50 knots" && offset >= 12 && offset <= 15 {
                    try store.save(Occurrence(ruleID: rule.id, date: date, status: .skipped))
                    continue
                }
                let status: OccurrenceStatus = (offset % 11 == 0) ? .completedLate : .completed
                try store.save(Occurrence(ruleID: rule.id, date: date, status: status))
            }
            if title == "Morning prayers" {
                try store.save(Occurrence(ruleID: rule.id, date: today, status: .completed))
            }
        }
        return store
    }

    private static func render(_ view: some View, to path: String) {
        // A ScrollView needs a definite height to lay out; the real popover
        // gets one from its contentSize, so give the renderer the same.
        let renderer = ImageRenderer(
            content: view.frame(width: Theme.popoverWidth, height: Theme.popoverHeight)
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
