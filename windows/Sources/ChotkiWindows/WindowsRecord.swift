import Foundation
import ChotkiCore
import WindowsUI

/// Platform paths and file operations; the portable backup format stays in core.
final class WindowsRecordFiles {
    let directory: URL
    private let temporary: Bool

    init(review: Bool) throws {
        temporary = review
        if review {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Chotki-review-\(UUID().uuidString)", isDirectory: true)
        } else {
            guard let local = ProcessInfo.processInfo.environment["LOCALAPPDATA"] else {
                throw BootstrapError.verification("LOCALAPPDATA is unavailable")
            }
            directory = URL(fileURLWithPath: local).appendingPathComponent("Chotki", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        if temporary { try? FileManager.default.removeItem(at: directory) }
    }

    var backups: URL { directory.appendingPathComponent("backups", isDirectory: true) }

    static func writeDailyBackup(store: SQLiteStore, directory: URL, on day: CalendarDate, keeping limit: Int = 10) throws {
        // A fresh install must never replace a useful backup with an empty one.
        guard try !store.rules(includeArchived: true).isEmpty else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("chotki-\(day.iso).json")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        try store.exportJSON().write(to: destination, options: .atomic)
        // Only our dated backup files participate in retention. Leave other files alone.
        let existing = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.range(of: #"^chotki-\d{4}-\d{2}-\d{2}\.json$"#, options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in existing.dropFirst(max(1, limit)) { try FileManager.default.removeItem(at: old) }
    }
}

extension WindowsApp {
    func writeDailyBackup(on day: CalendarDate? = nil) {
        do {
            try WindowsRecordFiles.writeDailyBackup(store: store, directory: recordFiles.backups,
                                                   on: day ?? CalendarDate(Date(), in: .current))
        } catch {
            // Backup failure cannot prevent startup or make a successful rule edit fail.
            notice = "The automatic backup could not be written. \(error.localizedDescription)"
        }
    }

    /// Timer, foreground activation and resume share the core day-selection decision.
    func heartbeat(now: CalendarDate? = nil) throws -> Bool {
        let today = now ?? CalendarDate(Date(), in: .current)
        let previousNotice = notice
        writeDailyBackup(on: today)
        if notice != previousNotice { notice.withCString { ch_update(editor == nil ? 202 : 553, $0) } }
        guard today != lastKnownToday, editor == nil, !glossaryDetouring else { return false }
        let next = DayRollover.selection(showing: selectedDate, wasToday: lastKnownToday, isToday: today)
        lastKnownToday = today
        selectedDate = next
        weekAnchor = next; visibleMonth = next
        selectedRow = 0
        return page == .home || page == .progress
    }

    func exportRecord(to url: URL) throws {
        try store.exportJSON().write(to: url, options: .atomic)
        notice = "Backup written to \(url.lastPathComponent)."
    }

    func restoreRecord(from url: URL) throws {
        try store.importJSON(Data(contentsOf: url))
        settings = try store.loadSettings() ?? settings
        try resetCalendarService()
        try repairObservances()
        selectedRow = 0
        writeDailyBackup()
        notice = "Restored from \(url.lastPathComponent). Your existing record is still here."
    }
}
