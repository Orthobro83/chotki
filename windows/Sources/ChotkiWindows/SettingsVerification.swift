import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func answerFileChooser(_ url: URL?, result: Int32 = 1) {
        (url?.path ?? "").withCString { ch_test_file_dialog($0, url == nil ? 0 : result) }
    }

    func requireRecordUnchanged(_ before: Backup, _ message: String) throws {
        // Recurrence weekdays are Sets; encoded JSON array ordering is not stable.
        // Compare decoded values rather than bytes from separate encodes.
        let after = try store.exportBackup()
        try require(before.rules == after.rules && before.activations == after.activations
                    && before.occurrences == after.occurrences && before.settings == after.settings, message)
    }

    func verifySettingsControls() throws {
        let originalSettings = settings
        settingsSection = 0
        try press(105)
        let priestRule = try fixture("Attribution before clearing")
        var unrecorded = priestRule
        unrecorded.source = "the library"
        try store.save(unrecorded)
        let priorFather = settings.spiritualFatherName
        enter(311, "Вера"); enter(313, "Fr. New")
        try press(90); try press(90)
        try require(text(311)=="Вера" && text(313)=="Fr. New", "Sidebar collapse lost typed names")
        try choose(603, 1)
        try require(settings.displayName == "Вера" && settings.spiritualFatherName == "Fr. New", "Clock change lost typed names")
        try require(settings.clockStyle == .twelveHour, "Clock choice")
        try require(try store.rule(id: priestRule.id)?.source == priorFather, "Name change lost prior priest attribution")
        try press(431)
        try require(settings.spiritualFatherName.isEmpty && ch_click(431) == 0, "Clear father control")
        try press(604)
        try require(settings.showConsistencyNumber != originalSettings.showConsistencyNumber, "Consistency switch")
        try require(try store.loadSettings() == settings, "Settings did not persist")
        try captureReview("settings")
        try require(ruleSummary(priestRule).contains("6:30 AM"), "Clock setting did not reach rule summaries")
        try selectCustom(priestRule.id); try press(411)
        try require(text(531) == "6 AM", "Clock setting did not reach editor hour choices")
        try press(551); try press(104)
        try require(!text(301).contains("Consistency:"), "Hidden consistency figure still appeared in Progress")
        try press(105); try press(604); try press(104)
        try require(text(301).contains("Consistency:"), "Visible consistency figure was missing from Progress")
        try press(105)

        let occurrencesBefore = try store.occurrences(ruleID: nil, from: nil, through: nil)
        try choose(600, 1)
        try choose(611, 1)
        try require(settings.namedChurch == Jurisdiction.known[0].name && settings.jurisdiction == Jurisdiction.known[0], "Church choice did not use shared jurisdiction")
        try require(settings.reckoningChangedOn == CalendarDate(Date(), in: .current), "Calendar change lacked scoring cutoff")
        try choose(613, 1)
        try require(settings.calendarDifferenceNote != nil, "Parish calendar difference note missing")
        for (i, church) in Jurisdiction.known.enumerated() {
            try choose(611, i+1)
            try require(settings.namedChurch == church.name && settings.jurisdiction == church, "Church choice \(church.name)")
        }
        try choose(611, 0)
        try require(settings.namedChurch == nil && settings.jurisdiction == .default, "Unnamed church must follow OCA without naming it")
        for (i, value) in Observance.allCases.enumerated() {
            try choose(615, i); try choose(617, i)
            try require(settings.observances.fasting == value && settings.observances.feasts == value, "Observance choices")
        }
        let oldStyle = settings.showOldStyleDates
        try press(618)
        try require(settings.showOldStyleDates != oldStyle, "Old-style date switch")
        try require(try store.occurrences(ruleID: nil, from: nil, through: nil) == occurrencesBefore, "Settings rewrote kept history")
        try require(try store.loadSettings() == settings, "Calendar choices did not persist")
        try captureReview("calendar-settings")

        // Exercise actual Settings button routes with a synthetic chooser response.
        // The OS dialog's physical interaction remains an acceptance gate.
        try choose(600, 2)
        let backupURL = recordFiles.directory.appendingPathComponent("Верный record backup.json")
        let exported = try store.exportBackup()
        answerFileChooser(backupURL); try press(621)
        try require(FileManager.default.fileExists(atPath: backupURL.path), "Unicode export path")
        let donor = try SQLiteStore.inMemory()
        try donor.importJSON(Data(contentsOf: backupURL))
        try require(try donor.rules(includeArchived: true).count == exported.rules.count,
                    "Export lost archived rules")
        try require(try donor.loadSettings() == settings, "Export lost settings")
        let retained = try fixture("Rule created after export")
        answerFileChooser(backupURL); try press(622)
        try require(try store.rule(id: retained.id) != nil, "Restore removed an existing rule")
        try require(try store.rules(includeArchived: true).count == exported.rules.count + 1, "Restore duplicated or removed rules")
        answerFileChooser(backupURL); try press(622)
        try require(try store.rules(includeArchived: true).count == exported.rules.count + 1, "Repeated restore is not idempotent")
        let beforeCancel = try store.exportBackup()
        answerFileChooser(nil); try press(621)
        answerFileChooser(nil); try press(622)
        try requireRecordUnchanged(beforeCancel, "Cancelling a chooser changed the record")
        let invalid = recordFiles.directory.appendingPathComponent("invalid.json")
        try Data("invalid backup".utf8).write(to: invalid)
        answerFileChooser(invalid); _ = ch_click(622)
        try require(actionError != nil, "Invalid backup failed silently")
        try requireRecordUnchanged(beforeCancel, "Invalid JSON changed the record")
        // Valid JSON with a dangling foreign key must also leave the entire record alone.
        let added = Rule(title: "Incomplete restore fixture", recurrence: .daily)
        let dangling = Backup(rules: [added], activations: [Activation(ruleID: UUID(), from: selectedDate)], occurrences: [])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(dangling).write(to: invalid)
        answerFileChooser(invalid); _ = ch_click(622)
        try require(actionError != nil, "Invalid relationship failed silently")
        try requireRecordUnchanged(beforeCancel, "Invalid relationship partly imported the backup")
        let missingParent = recordFiles.directory.appendingPathComponent("missing/export.json")
        answerFileChooser(missingParent); _ = ch_click(621)
        try require(actionError != nil && !FileManager.default.fileExists(atPath: missingParent.path), "Export failure was not visible")
        answerFileChooser(backupURL, result: -1); _ = ch_click(621)
        try require(actionError != nil, "Dialog failure was treated as cancellation")
        notice = "Synthetic review · Backup controls passed"; try render()
        try captureReview("record")

        // Daily retention is exercised on local temporary files, never the user's record.
        let archive = recordFiles.directory.appendingPathComponent("retention", isDirectory: true)
        let empty = try SQLiteStore.inMemory()
        let start = CalendarDate(year: 2026, month: 8, day: 1)!
        try WindowsRecordFiles.writeDailyBackup(store: empty, directory: archive, on: start)
        try require(!FileManager.default.fileExists(atPath: archive.path), "Empty install wrote an automatic backup")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        let unrelated = archive.appendingPathComponent("keep-this.json")
        try Data("unrelated".utf8).write(to: unrelated)
        for offset in 0..<12 {
            try WindowsRecordFiles.writeDailyBackup(store: store, directory: archive, on: start.adding(days: offset))
        }
        let files = try FileManager.default.contentsOfDirectory(at: archive, includingPropertiesForKeys: nil)
        try require(files.count == 11 && FileManager.default.fileExists(atPath: unrelated.path), "Retention removed unrelated files or kept the wrong number")
        try require(!FileManager.default.fileExists(atPath: archive.appendingPathComponent("chotki-2026-08-02.json").path)
                    && FileManager.default.fileExists(atPath: archive.appendingPathComponent("chotki-2026-08-03.json").path), "Retention kept the wrong days")
        let latest = archive.appendingPathComponent("chotki-2026-08-12.json")
        let snapshot = try Data(contentsOf: latest)
        _ = try fixture("Later same-day change")
        try WindowsRecordFiles.writeDailyBackup(store: store, directory: archive, on: start.adding(days: 11))
        try require(try Data(contentsOf: latest) == snapshot, "Daily backup was overwritten on the same day")
        let recovery = try SQLiteStore.inMemory()
        try recovery.importJSON(snapshot)
        try require(try recovery.rule(id: retained.id) != nil, "Automatic copy could not restore")

        let date = selectedDate, lastToday = lastKnownToday
        page = .home; lastKnownToday = start; selectedDate = start
        _ = try heartbeat(now: start.adding(days: 1))
        try require(selectedDate == start.adding(days: 1), "Open window did not follow midnight")
        selectedDate = start.adding(days: -3)
        _ = try heartbeat(now: start.adding(days: 2))
        try require(selectedDate == start.adding(days: -3), "Midnight lost a deliberately selected past day")
        editor = RuleDraft(nil, on: selectedDate, father: "")
        _ = try heartbeat(now: start.adding(days: 3))
        try require(lastKnownToday == start.adding(days: 2), "Midnight changed the date underneath an open editor")
        editor = nil; selectedDate = date; lastKnownToday = lastToday
        try store.saveSettings(originalSettings); settings = originalSettings
        settingsSection = 0; actionError = nil
        print("Settings/record UI passed: church and calendar choices, scoring cutoff, clock, names/attribution, history preservation, Unicode export, merge/idempotent restore, cancellation/errors, daily retention/recovery and midnight selection.")
    }
}
