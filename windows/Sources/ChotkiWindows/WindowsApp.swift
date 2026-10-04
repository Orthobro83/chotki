import Foundation
import ChotkiCore
import WindowsUI

/// Windows orchestration only. Rule, calendar, scoring and rope decisions stay in core.
@MainActor
final class WindowsApp {
    enum Page: Int, CaseIterable { case home = 100, library, prayers, reading, progress, settings, glossary }
    let store: SQLiteStore
    let review: Bool
    let recordFiles: WindowsRecordFiles
    var liturgical: LiturgicalService
    var calendarTask: Task<Void, Never>?
    var calendarGeneration: Int32 = 0
    var calendarRequest = ""
    var calendarRedraws = 0
    var calendarExpanded = false
    var visibleMonth = CalendarDate(Date(), in: .current)
    var weekAnchor = CalendarDate(Date(), in: .current)
    var calendarDates: [CalendarDate] = []
    var sidebarCollapsed = false
    var expandedRuleID: UUID?
    var flippedRuleID: UUID?
    var readingBand: Int?
    var readingToken: Int32 = 0
    var readingTarget: CompletionTarget?
    var showPsalter = false
    var lastKnownToday = CalendarDate(Date(), in: .current)
    var settingsSection = 0
    var settings: AppSettings
    var page: Page = .home
    var selectedDate = CalendarDate(Date(), in: .current)
    var rope = PrayerScreen(minimumInterval: 1)
    var selectedRow = 0
    var notice = ""
    var editor: RuleDraft?
    var customLibrary = false
    var verifying = false
    var actionError: String?
    private var rendering = false

    init(review: Bool) throws {
        self.review = review
        recordFiles = try WindowsRecordFiles(review: review)
        if review { store = try .inMemory() }
        else {
            store = try SQLiteStore(path: recordFiles.directory.appendingPathComponent("chotki.sqlite").path)
        }
        settings = try store.loadSettings() ?? .default
        liturgical = LiturgicalService(store: store,
            client: review ? OrthocalClient(http: ReviewCalendarFetcher()) : OrthocalClient(),
            jurisdiction: settings.jurisdiction)
        try liturgical.loadSnapshot(around: selectedDate)
        if review {
            settings.displayName = "Review"
            let rule = Rule(title: "Jesus Prayer", recurrence: .daily, prayerIDs: ["jesus-prayer"])
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: selectedDate.adding(days: -7)))
        }
        try repairObservances()
        writeDailyBackup()
    }

    var practice: Practice {
        get throws {
            Practice(rules: try store.rules(includeArchived: false),
                     activations: try store.activations(ruleID: nil),
                     occurrences: try store.occurrences(ruleID: nil, from: nil, through: nil),
                     settings: settings, liturgical: liturgical)
        }
    }
    var templates: [RuleTemplate] { RuleLibrary.shared.scoped(to: settings.jurisdiction.tradition).templates }
    var prayers: [Prayer] { PrayerBook.shared.scoped(to: settings.jurisdiction.tradition).prayers }
    var terms: [GlossaryEntry] { Glossary.shared(for: settings.jurisdiction.tradition).entries.sorted { $0.term < $1.term } }

    func control(_ id: Int32, _ kind: Int32, _ text: String, _ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32 = 34) {
        text.withCString { ch_control(id, kind, $0, x, y, w, h) }
    }
    func list(_ texts: [String], selected: Int = 0) {
        control(300, 2, "", 260, 165, 360, 395)
        for text in texts { text.withCString { ch_list_add(300, $0) } }
        if !texts.isEmpty { ch_select(300, Int32(min(selected, texts.count - 1))) }
    }
    func body(_ text: String, x: Int32 = 650, width: Int32 = 380) {
        control(301, 4, text.replacingOccurrences(of: "\n", with: "\r\n"), x, 165, width, 395)
    }
    func title(_ text: String, subtitle: String) {
        control(200, 5, text, contentLeft, 24, contentWidth, 38)
        control(201, 0, subtitle, contentLeft, 76, contentWidth)
    }
    func render() throws {
        rendering = true
        defer { rendering = false }
        ch_clear()
        readingTarget=nil
        renderSidebar()
        control(202, 0, notice, contentLeft, max(0,ch_height()-35), contentWidth, 32)
        if editor != nil {
            for item in Page.allCases { ch_enable(Int32(item.rawValue), 0) }
            renderEditor(); return
        }
        switch page {
        case .home:
            try renderHome()
        case .library:
            title("Library", subtitle: "Taking a rule on is always your choice.")
            choice(320, ["From the Library", "Custom"], selected: customLibrary ? 1 : 0, x: 650, y: 112, width: 380)
            if customLibrary {
                let own = try customEntries
                selectedRow = own.isEmpty ? 0 : min(selectedRow, own.count-1)
                list(try own.map { try ruleIsActive($0) ? "On your rule · \($0.title)" : $0.title }, selected: selectedRow)
                if own.indices.contains(selectedRow) { body(ruleSummary(own[selectedRow])) }
                control(411, 1, "Edit", 475, 580, 145)
                control(412, 1, "Set Aside", 650, 580, 150)
                let paused = own.indices.contains(selectedRow) ? try practice.isPaused(own[selectedRow]) : true
                control(413, 1, paused ? "Resume" : "Pause", 820, 580, 210)
            } else {
                list(templates.map(\.title), selected: selectedRow)
                if templates.indices.contains(selectedRow) { body(templates[selectedRow].summary) }
            }
            control(410, 1, "Take On This Rule", 260, 580, 200)
            control(414, 1, "Write Your Own Rule", 260, 620, 240)
        case .prayers:
            renderPrayers()
        case .reading:
            try renderReading()
        case .progress:
            title("Progress", subtitle: "Through yesterday · The last 30 days")
            let report = try practice.report(today: CalendarDate(Date(), in: .current))
            var text = report.summary.joined(separator: "\n\n")
            if settings.showConsistencyNumber, let value = report.overall { text += "\n\nConsistency: \(Int((value * 100).rounded()))%" }
            text += report.perRule.map { "\n\n\($0.title): \($0.kept + $0.keptLate) kept" }.joined()
            body(text, x: 260, width: 770)
        case .settings:
            renderSettings()
        case .glossary:
            title("Glossary", subtitle: "Words used in prayer and the church calendar")
            list(terms.map(\.term), selected: selectedRow)
            if terms.indices.contains(selectedRow) { body(terms[selectedRow].full) }
        }
    }

    func handle(control id: Int32, event: Int32) {
        guard !rendering else { return }
        do {
            if id == -4 {
                let names = page == .settings && settingsSection == 0 && editor == nil ? (text(311),text(313)) : nil
                if editor != nil { captureEditor() }
                try render()
                if let names { enter(311,names.0); enter(313,names.1) }
                return
            }
            if id == -6 { try completeReading(token:event); return }
            if id == -3 {
                guard event == calendarGeneration else { return }
                calendarRedraws += 1
                if editor == nil && [.home,.reading,.progress].contains(page) { try render() }
                return
            }
            if id == -2 {
                if try heartbeat() { try render() }
                return
            }
            if id != -1 { actionError = nil }
            if id == 0 { try render(); return }
            if id == -1 { try verifyControls(); ch_close(0); return }
            if editor != nil && ((500...552).contains(id)) {
                if event == 768 { // Native edit control: EN_CHANGE.
                    notice = ""; ch_update(553, ""); return
                }
                if id == 550 && event == 0 { try saveEditor() }
                else if id == 551 && event == 0 { editor = nil; notice = "" }
                else if id == 552 && event == 0 { try removeEditor() }
                else if event == 1 && [511,512,513,531,532,541].contains(id) || event == 0 && [524,530,533].contains(id) {
                    captureEditor(); notice = ""
                } else { return }
                try render(); return
            }
            if id == 300 && event == 50 {
                guard editor == nil && page == .home else { return }
                selectedRow = max(0, Int(ch_selected(300)))
                try showRuleMenu(); return
            }
            if page == .prayers && id == 321 && event == 1 {
                let index=Int(ch_selected(321)); rope.choose(index==0 ? "morning" : index==1 ? "evening" : prayers[max(0,index-2)].id)
                try render(); return
            }
            if page == .prayers && id == 779 && event == 0 { showPsalter.toggle(); try render(); return }
            if id == 90 && event == 0 {
                let names = page == .settings && settingsSection == 0 && editor == nil ? (text(311),text(313)) : nil
                if editor != nil { captureEditor() }
                sidebarCollapsed.toggle(); try render()
                if let names { enter(311,names.0); enter(313,names.1) }
                return
            }
            if page == .home && event == 0 && (800...841).contains(id) {
                let index=Int(id-800)
                if calendarDates.indices.contains(index) { setHomeDate(calendarDates[index]) }
                try render(); return
            }
            if page == .home && event == 0 && (1000..<4000).contains(id) {
                let entries=try practice.entries(on: selectedDate), index=Int(id%1000)
                guard entries.indices.contains(index) else { return }
                selectedRow=index
                let entry=entries[index]
                if id < 2000 { try openHomeEntry(entry) }
                else if id < 3000 { try toggleHomeKept(entry) }
                else { expandedRuleID=expandedRuleID == entry.rule.id ? nil : entry.rule.id }
                try render(); return
            }
            if page == .reading && handleReading(control:id,event:event) { return }
            if page == .settings && handleSettings(control: id, event: event) {
                return
            }
            if let target = Page(rawValue: Int(id)), event == 0 {
                editor = nil; page = target; selectedRow = 0; notice = ""; readingTarget=nil; showPsalter=false
                if page == .reading { readingBand=nil; showPsalter=false }
                if page == .prayers { selectedRow = prayers.firstIndex { $0.id == rope.selection } ?? 0 }
            } else if id == 320, event == 1 {
                customLibrary = ch_selected(320) == 1; selectedRow = 0
            } else if id == 300, event == 1 {
                selectedRow = max(0, Int(ch_selected(300)))
                if page == .prayers, !showPsalter, prayers.indices.contains(selectedRow) { rope.choose(prayers[selectedRow].id) }
            } else if event == 0 {
                switch id {
                case 400, 401:
                    let entries = try practice.entries(on: selectedDate)
                    guard entries.indices.contains(selectedRow) else { return }
                    let entry = entries[selectedRow]
                    guard !entry.isDispensed else { return }
                    if id == 400 && entry.isKept { try store.removeOccurrence(ruleID: entry.rule.id, date: selectedDate) }
                    else { try store.save(Occurrence(ruleID: entry.rule.id, date: selectedDate, status: id == 401 ? .skipped : .completed, completedAt: id == 400 ? Date() : nil)) }
                    if try practice.isSettled(on: selectedDate) { notice = "Glory to God for all things" }
                case 402,746,747: page = .library; selectedRow = 0
                case 711,712:
                    if calendarExpanded {
                        let first=CalendarDate(year:visibleMonth.year,month:visibleMonth.month,day:1)!
                        visibleMonth=id == 711 ? first.adding(days:-1) : first.adding(days:first.lastDayOfMonth)
                    } else { weekAnchor=weekAnchor.adding(days:id == 711 ? -7 : 7) }
                case 713: calendarExpanded.toggle(); if calendarExpanded { visibleMonth=selectedDate }
                case 403: setHomeDate(selectedDate.adding(days:-1))
                case 404: setHomeDate(CalendarDate(Date(),in:.current))
                case 405: setHomeDate(selectedDate.adding(days:1))
                case 406: try showRuleMenu(); return
                case 410:
                    try takeSelectedRule()
                case 411:
                    if let rule = try selectedCustomRule() { openEditor(rule) }
                case 412:
                    if let rule = try selectedCustomRule() {
                        try store.save(CustomLibrary.settingAside(rule)); selectedRow = 0
                        notice = "\(rule.title) is no longer offered here. Its record is unchanged."
                    }
                case 413:
                    if let rule = try selectedCustomRule() { try togglePause(rule) }
                case 414: openEditor()
                case 450...455, 460...462: try homeRuleAction(id)
                case 420:
                    if rope.advance(), let selection=rope.selection {
                        for entry in try practice.entries(on:selectedDate) where !entry.isKept && !entry.isDispensed && !entry.isStoodDown && ReadingCompletion.matches(entry.rule,prayer:selection,counted:true) {
                            try store.save(Occurrence(ruleID:entry.rule.id,date:entry.date,status:.completed,completedAt:Date()))
                        }
                    }
                case 421: rope.startAgain()
                case 422...424: rope.aim(at: PrayerScreen.targets[Int(id)-422])
                default: return
                }
            } else { return }
            if (420...424).contains(id) {
                // Counting must preserve the reader's scroll position and focus.
                "\(rope.count) of \(rope.target) knots".withCString { ch_update(201, $0) }
            } else { try render() }
        } catch {
            actionError = error.localizedDescription
            if id == -1 { print("UI verification failed: \(error)"); ch_close(1) }
            else {
                notice = error.localizedDescription
                if verifying && !(error is RuleInputError) { print("Control \(id) failed: \(notice)") }
                notice.withCString { ch_update(editor == nil ? 202 : 553, $0) }
            }
        }
    }
    func text(_ id: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: max(1, Int(ch_text(id, nil, 0))))
        _ = ch_text(id, &buffer, Int32(buffer.count))
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    func verifyControls() throws {
        guard review else { throw BootstrapError.verification("UI checks require a synthetic review") }
        verifying = true
        defer { verifying = false }
        guard ch_click(2000) == 1, try practice.entries(on: selectedDate).first?.isKept == true else { throw BootstrapError.verification("Home mark control") }
        guard ch_click(2000) == 1, try practice.entries(on: selectedDate).first?.isKept == false else { throw BootstrapError.verification("Home unmark control") }
        guard ch_click(402) == 1, page == .library else { throw BootstrapError.verification("Home Add route") }
        guard ch_click(410) == 1, try store.rules(includeArchived: false).count == 2 else { throw BootstrapError.verification("Library take-on control") }
        guard ch_click(102) == 1, page == .prayers else { throw BootstrapError.verification("Prayer route") }
        guard ch_click(420) == 1, rope.count == 1 else { throw BootstrapError.verification("Prayer count") }
        guard ch_click(421) == 1, rope.count == 0 else { throw BootstrapError.verification("Prayer reset") }
        for target in [Page.reading, .progress, .settings, .glossary] {
            guard ch_click(Int32(target.rawValue)) == 1, page == target else {
                throw BootstrapError.verification("Navigation to \(target)")
            }
        }
        try verifyRuleControls()
        try verifySettingsControls()
        try verifyHomeControls()
        page = .home; selectedRow = 0; notice = "Synthetic review · Control checks passed"; try render()
        if let path = ProcessInfo.processInfo.environment["CHOTKI_REVIEW_CAPTURE"] {
            guard path.withCString({ ch_capture($0) }) == 1 else { throw BootstrapError.verification("Window capture") }
        }
        print("UI controls passed: all seven pages, Home mark/unmark, Add route, Library activation, prayer count/reset.")
    }
}
