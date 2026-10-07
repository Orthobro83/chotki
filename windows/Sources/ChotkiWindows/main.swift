import Foundation
import ChotkiCore
import WindowsUI

#if !os(Windows) || !arch(x86_64)
#error("ChotkiWindows requires x86_64 Windows.")
#endif

// Synthetic verification uses no live data or platform-service requests.
enum BootstrapError: Error {
    case verification(String)
}

func verifyBootstrap() throws {
    let store = try SQLiteStore.inMemory()
    // SQLite stores ISO-8601 timestamps to milliseconds; use an exact fixture
    // timestamp so whole-value equality tests data rather than clock precision.
    let rule = Rule(title: "Windows bootstrap fixture", recurrence: .daily,
                    createdAt: Date(timeIntervalSince1970: 1_780_000_000))
    try store.save(rule)
    try store.saveSettings(.default)
    let loaded = try store.rule(id: rule.id)
    guard loaded == rule else {
        throw BootstrapError.verification("SQLite rule round trip")
    }
    let restored = try SQLiteStore.inMemory()
    try restored.importJSON(store.exportJSON())
    guard try restored.rule(id: rule.id) == rule,
          try restored.loadSettings() == .default else {
        throw BootstrapError.verification("JSON backup round trip")
    }
    guard Psalter.all.count == 151 else {
        throw BootstrapError.verification("Bundled Psalter resource")
    }
    print("Chotki Windows x86_64 framework ready: SQLite, settings, JSON backup and 151 bundled psalms verified.")
    try verifyShippedCalendar()
}

do {
    try WindowsAssets.loadFonts()
    if CommandLine.arguments.contains("--calendar-network-test") {
        try verifyCalendarNetwork()
    } else if CommandLine.arguments.contains("--self-test") {
        try verifyBootstrap()
    } else {
        let automated = CommandLine.arguments.contains("--ui-smoke")
        let notificationSmoke=CommandLine.arguments.contains("--notification-smoke")
        let lifecycle=CommandLine.arguments.contains("--lifecycle-smoke")
        let review=automated || notificationSmoke || lifecycle || CommandLine.arguments.contains("--review")
        if lifecycle { ch_lifecycle_review(1) }
        if (!review || lifecycle) && ch_single_instance()==0 { ch_exit(0) }
        ch_review_mode(review && !lifecycle ? 1 : 0)
        let app = try WindowsApp(review:review)
        ch_start_hidden((( !review && app.settings.hasCompletedFirstRun) || lifecycle) && CommandLine.arguments.contains("--startup") ? 1 : 0)
        app.notificationSmoke=notificationSmoke
        WindowsApp.prepareTrayMark()
        // The native loop retains only an opaque pointer. Keep its Swift owner
        // alive until the loop and all synchronous window callbacks have ended.
        let nativeOwner = Unmanaged.passRetained(app)
        defer { nativeOwner.release() }
        let context = nativeOwner.toOpaque()
        let status = ch_run({ context, id, event in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<WindowsApp>.fromOpaque(context).takeUnretainedValue().handle(control: id, event: event)
            }
        }, context, notificationSmoke ? 2 : automated ? 1 : 0)
        if status != 0 { throw BootstrapError.verification("Windows UI exit \(status)") }
    }
} catch {
    print("Chotki Windows failed: \(error)")
    ch_exit(1)
}
