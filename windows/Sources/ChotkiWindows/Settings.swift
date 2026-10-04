import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func renderSettings() {
        title("Settings",subtitle:"Your choices travel with your record.")
        let width=min(720,contentWidth)-44
        let notes=([settings.calendarDifferenceNote].compactMap { $0 }+settings.jurisdiction.practice.notes).joined(separator:"\n\n")
        let notesHeight=max(20,notes.withCString { ch_measure_text($0,width,0) })
        ch_home_begin(contentLeft,124,contentWidth,max(120,ch_height()-164),1320+notesHeight)
        var y:Int32=0, labelID:Int32=22000
        func label(_ text:String,muted:Bool=true) {
            let h=max(20,text.withCString { ch_measure_text($0,width,0) })
            control(labelID,0,text,14,y,width,h); if muted { ch_style(labelID,64) }
            labelID += 1; y += h+4
        }
        func section(_ text:String) { y += 18; label(text) }
        func toggle(_ id:Int32,_ text:String,_ value:Bool,_ help:String?=nil) {
            control(id,27,text,14,y,width,32); ch_check(id,value ? 1 : 0); y += 35
            if let help { label(help) }
        }
        func picker(_ id:Int32,_ text:String,_ values:[String],_ selected:Int,width pickerWidth:Int32=170) {
            control(labelID,0,text,14,y+6,width-pickerWidth-14,24); labelID += 1
            choice(id,values,selected:selected,x:14+width-pickerWidth,y:y,width:pickerWidth); y += 42
        }
        section("You")
        label("My Name")
        control(311,3,settings.displayName,14,y,width,32); y += 42
        label("My Spiritual Father's Name")
        control(313,3,settings.spiritualFatherName,14,y,width,32); y += 38
        control(431,18,"Clear",14,y,74,26); ch_enable(431,settings.spiritualFatherName.isEmpty ? 0 : 1)
        control(430,18,"Save Names",100,y,120,26); y += 32
        section("Your Church")
        let church=settings.namedChurch.flatMap { name in Jurisdiction.known.firstIndex { $0.name==name } }.map { $0+1 } ?? 0
        choice(611,[Welcome.noChurchAffiliation]+Jurisdiction.known.map(\.name),selected:church,x:14,y:y,width:width); y += 42
        choice(613,Reckoning.allCases.map(\.displayName),selected:Reckoning.allCases.firstIndex(of:settings.jurisdiction.reckoning) ?? 0,x:14,y:y,width:width); y += 42
        control(619,0,notes,14,y,width,notesHeight); ch_style(619,64); y += notesHeight+6
        section("The Calendar")
        picker(615,"Fasting",["Hidden","Shown","Observed"],Observance.allCases.firstIndex(of:settings.observances.fasting) ?? 1,width:116)
        picker(617,"Feasts",["Hidden","Shown","Observed"],Observance.allCases.firstIndex(of:settings.observances.feasts) ?? 1,width:116)
        toggle(618,"Show old-style dates",settings.showOldStyleDates,"Shows the Julian date alongside the civil one.")
        picker(603,"Clock",ClockStyle.allCases.map(\.displayName),ClockStyle.allCases.firstIndex(of:settings.clockStyle) ?? 0)
        section("Reminders")
        toggle(605,"Notifications",settings.reminders.notificationsEnabled,"Turning these off silences the app. It does not change what is due, or how anything is counted.")
        picker(606,"Warn me",ReminderLead.choices.map(\.label),ReminderLead.choices.firstIndex(of:settings.reminders.defaultLead) ?? 0)
        ch_enable(606,settings.reminders.notificationsEnabled ? 1 : 0)
        section("Prayer Rope")
        toggle(607,"Chime when a knot is complete",settings.chimeOnCompletion)
        toggle(608,"Click on each knot",settings.tickEachKnot,"A soft click confirms a press landed, for praying with your eyes closed.")
        section("Your Record")
        let half=(width-16)/2
        control(621,18,"Export a backup…",14,y,half,32)
        control(622,18,"Restore from a backup…",30+half,y,half,32); y += 40
        label("A copy is also written automatically each day in your Chotki backups folder. Restoring merges into what is already here; nothing is removed. The ten most recent daily copies are kept.")
        label("Backup folder: \(recordFiles.backups.path)")
        section("General")
        toggle(609,"Show in the taskbar",settings.showInDock,"With this off, Chotki lives in the notification area. The tray icon is there either way.")
        toggle(625,"Open at login",settings.launchAtLogin)
        toggle(604,"Show the consistency figure",settings.showConsistencyNumber,"With this off, progress is reported in words only.")
        ch_home_end()
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

    /// Persist edits without rebuilding the focused name field.
    func handleSettings(control id: Int32, event: Int32) -> Bool {
        if event==768 && (id==311 || id==313) {
            do {
                let value=text(id)
                try saveSettings { if id==311 { $0.displayName=value } else { $0.spiritualFatherName=value } }
                ch_enable(431,settings.spiritualFatherName.isEmpty ? 0 : 1)
                ch_update(202,"")
            } catch { actionError=error.localizedDescription; notice=error.localizedDescription; notice.withCString { ch_update(202,$0) } }
            return true
        }
        let choices: [Int32] = [603,606,611,613,615,617]
        let buttons: [Int32] = [430,431,604,605,607,608,609,618,621,622,625]
        guard event == 1 && choices.contains(id) || event == 0 && buttons.contains(id) else { return false }
        do {
            // Commit typed names before a choice redraw, so draft names are never lost.
            if id != 431 && (text(311) != settings.displayName || text(313) != settings.spiritualFatherName) {
                let name = text(311), father = text(313)
                try saveSettings { $0.displayName = name; $0.spiritualFatherName = father }
            }
            switch id {
            case 430:
                let name = text(311), father = text(313)
                try saveSettings { $0.displayName = name; $0.spiritualFatherName = father }
            case 431:
                let name = text(311)
                try saveSettings { $0.displayName = name; $0.spiritualFatherName = "" }
            case 603:
                let style = ClockStyle.allCases[max(0, Int(ch_selected(id)))]
                try saveSettings { $0.clockStyle = style }
            case 606:
                let lead=ReminderLead.choices[max(0,Int(ch_selected(id)))]
                try saveSettings { $0.reminders.defaultLead=lead }
            case 607: let value=ch_checked(id)==1; try saveSettings { $0.chimeOnCompletion=value }
            case 608: let value=ch_checked(id)==1; try saveSettings { $0.tickEachKnot=value }
            case 609: let value=ch_checked(id)==1; try saveSettings { $0.showInDock=value }
            case 625:
                let value=ch_checked(id)==1
                guard ch_startup(value ? 1 : 0)==0 else { throw RuleInputError(message:"Windows could not change the login setting.") }
                do { try saveSettings { $0.launchAtLogin=value } }
                catch { _=ch_startup(settings.launchAtLogin ? 1 : 0); throw error }
            case 604: let value = ch_checked(id) == 1; try saveSettings { $0.showConsistencyNumber = value }
            case 605: let value = ch_checked(id) == 1; try saveSettings { $0.reminders.notificationsEnabled = value }
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
