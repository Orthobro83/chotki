import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func renderSettings() {
        title("Settings", subtitle: "Your choices travel with your record.")
        choice(600, ["You", "Church and calendar", "Your record"], selected: settingsSection,
               x: 260, y: 153, width: 500)
        switch settingsSection {
        case 0:
            control(310, 0, "What should we call you?", 260, 205, 500)
            control(311, 3, settings.displayName, 260, 244, 500)
            control(312, 0, "Spiritual father's name", 260, 293, 500)
            control(313, 3, settings.spiritualFatherName, 260, 332, 500)
            control(431, 1, "Clear", 780, 332, 110)
            ch_enable(431, settings.spiritualFatherName.isEmpty ? 0 : 1)
            control(430, 1, "Save Names", 260, 382, 180)
            control(602, 0, "Clock", 260, 437, 200)
            choice(603, ClockStyle.allCases.map(\.displayName), selected: ClockStyle.allCases.firstIndex(of: settings.clockStyle) ?? 0,
                   x: 560, y: 434, width: 330)
            checkbox(604, "Show the consistency figure in Progress", checked: settings.showConsistencyNumber,
                     x: 260, y: 488, width: 650)
        case 1:
            control(610, 0, "Your church", 260, 205, 770)
            let church = settings.namedChurch.flatMap { name in Jurisdiction.known.firstIndex { $0.name == name } }.map { $0 + 1 } ?? 0
            choice(611, [Welcome.noChurchAffiliation] + Jurisdiction.known.map(\.name), selected: church,
                   x: 260, y: 244, width: 770)
            control(612, 0, "Calendar", 260, 293, 300)
            choice(613, Reckoning.allCases.map(\.displayName), selected: Reckoning.allCases.firstIndex(of: settings.jurisdiction.reckoning) ?? 0,
                   x: 560, y: 290, width: 470)
            control(614, 0, "Fasting", 260, 345, 300)
            choice(615, ["Hidden", "Shown", "Observed"], selected: Observance.allCases.firstIndex(of: settings.observances.fasting) ?? 1,
                   x: 560, y: 342, width: 230)
            control(616, 0, "Feasts", 260, 397, 300)
            choice(617, ["Hidden", "Shown", "Observed"], selected: Observance.allCases.firstIndex(of: settings.observances.feasts) ?? 1,
                   x: 560, y: 394, width: 230)
            checkbox(618, "Show old-style dates", checked: settings.showOldStyleDates, x: 260, y: 443, width: 650)
            let notes = ([settings.calendarDifferenceNote].compactMap { $0 } + settings.jurisdiction.practice.notes).joined(separator: "\n\n")
            control(619, 0, notes.replacingOccurrences(of: "\n", with: "\r\n"), 260, 495, 770, 135)
        default:
            control(620, 0, "Keep a copy of your record", 260, 215, 770)
            control(621, 1, "Export a backup…", 260, 270, 280)
            control(622, 1, "Restore from a backup…", 560, 270, 330)
            control(623, 0, "Restoring merges into what is already here; nothing is removed.\r\n\r\nA dated copy is also written automatically each day. The ten most recent copies are kept beside your Windows record.", 260, 335, 770, 120)
            control(624, 4, "Backup folder:\r\n\(recordFiles.backups.path)", 260, 475, 770, 95)
        }
    }

    func saveSettings(_ change: (inout AppSettings) -> Void) throws {
        var updated = settings
        change(&updated)
        let former = settings.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = updated.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !former.isEmpty && former != next {
            for var rule in try store.rules(includeArchived: true) where rule.givenByPriest == true {
                let source = rule.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if source.isEmpty || source == "the library" { rule.source = former; try store.save(rule) }
            }
        }
        if updated.hasCompletedFirstRun && updated.firstRunOn == nil {
            updated.firstRunOn = CalendarDate(Date(), in: .current)
        }
        let jurisdictionChanged = updated.jurisdiction != settings.jurisdiction
        let calendarChanged = updated.jurisdiction.reckoning != settings.jurisdiction.reckoning
        if calendarChanged { updated.reckoningChangedOn = CalendarDate(Date(), in: .current) }
        try store.saveSettings(updated)
        settings = updated
        if jurisdictionChanged { try resetCalendarService() }
        notice = calendarChanged
            ? "The calendar is now the \(updated.jurisdiction.reckoning.displayName). What you have already kept is untouched."
            : "Settings saved."
    }

    func chooseBackupFile(save: Bool) throws -> URL? {
        var path = [CChar](repeating: 0, count: 131_072)
        let suggested = save ? "chotki-\(CalendarDate(Date(), in: .current).iso).json" : ""
        let result = suggested.withCString { ch_file_dialog(save ? 1 : 0, $0, &path, Int32(path.count)) }
        if result == 0 { return nil }
        guard result == 1 else { throw RuleInputError(message: "The backup file chooser could not be opened.") }
        let value = String(decoding: path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return URL(fileURLWithPath: value)
    }

    /// Choices save immediately; name fields have an explicit Save button.
    func handleSettings(control id: Int32, event: Int32) -> Bool {
        let choices: [Int32] = [600,603,611,613,615,617]
        let buttons: [Int32] = [430,431,604,618,621,622]
        guard event == 1 && choices.contains(id) || event == 0 && buttons.contains(id) else { return false }
        do {
            // Commit typed names before a choice redraw, so draft names are never lost.
            if settingsSection == 0 && id != 431 && (text(311) != settings.displayName || text(313) != settings.spiritualFatherName) {
                let name = text(311), father = text(313)
                try saveSettings { $0.displayName = name; $0.spiritualFatherName = father }
            }
            switch id {
            case 600: settingsSection = max(0, Int(ch_selected(600))); notice = ""
            case 430:
                let name = text(311), father = text(313)
                try saveSettings { $0.displayName = name; $0.spiritualFatherName = father }
            case 431:
                let name = text(311)
                try saveSettings { $0.displayName = name; $0.spiritualFatherName = "" }
            case 603:
                let style = ClockStyle.allCases[max(0, Int(ch_selected(id)))]
                try saveSettings { $0.clockStyle = style }
            case 604: let value = ch_checked(id) == 1; try saveSettings { $0.showConsistencyNumber = value }
            case 611:
                let index = Int(ch_selected(id))
                let name = index > 0 ? Jurisdiction.known[index-1].name : nil
                try saveSettings { $0.chooseChurch(named: name) }
            case 613:
                let value = Reckoning.allCases[max(0, Int(ch_selected(id)))]
                try saveSettings { $0.jurisdiction.reckoning = value }
            case 615,617:
                let value = Observance.allCases[max(0, Int(ch_selected(id)))]
                try saveSettings {
                    if id == 615 { $0.observances.fasting = value } else { $0.observances.feasts = value }
                }
            case 618: let value = ch_checked(id) == 1; try saveSettings { $0.showOldStyleDates = value }
            case 621,622:
                guard let url = try chooseBackupFile(save: id == 621) else { return true }
                if id == 621 { try exportRecord(to: url) } else { try restoreRecord(from: url) }
            default: break
            }
            try render()
        } catch {
            actionError = error.localizedDescription
            notice = "Could not save that choice or backup. \(error.localizedDescription)"
            notice.withCString { ch_update(202, $0) }
        }
        return true
    }
}
