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
    var calendarTouched: Date?
    var weekAnchor = CalendarDate(Date(), in: .current)
    var calendarDates: [CalendarDate] = []
    var sidebarCollapsed = false
    var revealExpandedCard=false
    var expandedRuleID: UUID?
    var flippedRuleID: UUID?
    var readerLinks: [Int32: ReaderLink] = [:]
    var readerLinkOwners: [Int32: [Int32]] = [:]
    var nextReaderLink: Int32 = 1
    var glossarySlug: String?
    var glossaryQuery = ""
    var glossaryDetouring = false
    var glossaryResized = false
    var reviewedSourceURL: String?
    var expandedReadingBands: Set<Int> = []
    // A rule route focuses one section; the Reading tab can expand several.
    var readingBand: Int? {
        get { expandedReadingBands.sorted().first }
        set { expandedReadingBands = newValue.map { [$0] } ?? [] }
    }
    var appointedKathisma: Int?
    var manualKathisma: Int?
    var readingCompletions: [Int32: CompletionTarget] = [:]
    var readingToken: Int32 = 0
    var readingTarget: CompletionTarget?
    var rulePrayerID:UUID?
    var showPsalter = false
    var lastKnownToday = CalendarDate(Date(), in: .current)
    var settings: AppSettings
    var page: Page = .home
    var selectedDate = CalendarDate(Date(), in: .current)
    var rope = PrayerScreen(minimumInterval: 1)
    var selectedRow = 0
    var notice = ""
    var editor: RuleDraft?
    var customLibrary = false
    var libraryCaution = false
    var onboarding=false
    var welcomeName=""
    var fatherPromptNaming=false
    var fatherPromptName=""
    var welcomeChurch=0
    var verifying = false
    var notificationSmoke=false
    var nativeNotificationAttempts=0
    var nativeSmokeNotification:PlannedNotification?
    var notificationsStarted=false
    var notificationStatus:Int32=0
    var reminderTicker=ReminderTicker()
    var reminderVerification=false
    var reminderRuleIDs:Set<UUID>?
    var reminderTestNow:Date?
    var deliveredNotifications:[String:PlannedNotification]=[:]
    var attentionUntil:[DueDestination:Date]=[:]
    var audioStatus:Int32=0
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
        onboarding = !review && !settings.hasCompletedFirstRun
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
        let tick=WAV.encode(ToneRenderer.render(.tick)),bell=WAV.encode(ToneRenderer.render(.bell))
        audioStatus=tick.withUnsafeBytes { tickBytes in bell.withUnsafeBytes { bellBytes in
            ch_sound_prepare(tickBytes.bindMemory(to:UInt8.self).baseAddress,Int32(tick.count),bellBytes.bindMemory(to:UInt8.self).baseAddress,Int32(bell.count),review ? 1 : 0)
        } }
        try repairObservances()
        if !review, try practice.shouldMarkFirstRunComplete {
            settings.hasCompletedFirstRun=true
            settings.firstRunOn=settings.firstRunOn ?? selectedDate
            try store.saveSettings(settings); onboarding=false
        }
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
        // The opening owns the visible surface until its completion callback.
        // Calendar arrivals still update the model, then render after the fade.
        if ch_opening_active() != 0 { return }
        rendering = true
        ch_render_begin()
        defer { ch_render_end(); rendering = false }
        glossaryDetouring = false
        readerLinks.removeAll(); readerLinkOwners.removeAll()
        ch_taskbar(settings.showInDock ? 1 : 0)
        ch_tray_enabled(settings.reminders.notificationsEnabled ? 1 : 0)
        ch_clear()
        readingTarget=nil; readingCompletions.removeAll()
        if onboarding { renderOnboarding(); return }
        if !verifying && settings.shouldAskForSpiritualFather(on:lastKnownToday) { renderFatherPrompt(); return }
        renderSidebar()
        applyAttention()
        try refreshReminders(now:reminderTestNow ?? Date())
        if ch_report_visible()==1 { try renderDetachedProgress(show:false) }
        control(202, 0, notice, contentLeft, max(0,ch_height()-35), contentWidth, 32)
        if editor != nil {
            renderEditor(); return
        }
        switch page {
        case .home:
            try renderHome()
        case .library:
            try renderLibrary()
        case .prayers:
            try renderPrayers()
        case .reading:
            try renderReading()
        case .progress:
            try renderProgress()
        case .settings:
            renderSettings()
        case .glossary:
            renderGlossary()
        }
    }

    func handle(control id: Int32, event: Int32) {
        guard !rendering else { return }
        do {
            if event == 0 && (Int32(CH_TRAY_OPEN)...Int32(CH_TRAY_QUIT)).contains(id) {
                actionError = nil; try handleTray(id); return
            }
            if onboarding && handleOnboarding(id,event:event) { return }
            if try handleFatherPrompt(id,event:event) { return }
            if id == -10 { try render(); return }
            if id == -9 { try checkNativeNotificationSmoke(); return }
            if id == -8 { try handleNotificationTicket(event); return }
            if id == -7 { try followReaderLink(event); return }
            if handleGlossary(id, event: event) { return }
            if id == -4 {
                if glossaryDetouring {
                    glossaryResized = true
                    ch_glossary_resize(contentLeft, 16, contentWidth, ch_height()-32)
                    return
                }
                let names = page == .settings && editor == nil ? (text(311),text(313)) : nil
                if editor != nil { captureEditor() }
                try render()
                if let names { enter(311,names.0); enter(313,names.1) }
                return
            }
            if id == -6 { if !glossaryDetouring { try completeReading(token:event) }; return }
            if id == -3 {
                guard event == calendarGeneration else { return }
                calendarRedraws += 1
                if page == .reading && readingTarget != nil {
                    // A cache refresh updates the heading without disposing the
                    // live native reader, its layout or the user's place.
                    if let day = liturgical.cachedDay(for: selectedDate) {
                        (day.title ?? "").withCString { ch_update(760, $0) }
                    }
                    return
                }
                if editor == nil && !glossaryDetouring && ([.home,.reading,.progress].contains(page) || (page == .prayers && showPsalter && readingCompletions.isEmpty)) { try render() }
                return
            }
            if id == -11 && page == .home && !calendarExpanded {
                weekAnchor=weekAnchor.adding(days: Int(event)); calendarTouched=Date(); ch_calendar_browse(1); try render(); return
            }
            if id == -12 {
                if page == .home { setHomeDate(CalendarDate(Date(),in:.current)); calendarTouched=nil; ch_calendar_browse(0); try render() }; return
            }
            if id == -2 {
                let changed=try heartbeat()
                try refreshReminders()
                if changed, !glossaryDetouring { try render() }
                return
            }
            if id != -1 { actionError = nil }
            if id == 0 { try render(); try startNotifications(); if notificationSmoke { try beginNativeNotificationSmoke() }; return }
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
            if page == .library { if try handleLibrary(id,event:event) { return } }
            if page == .progress && id==20005 && event==0 { try renderDetachedProgress(show:true); return }
            if try handlePrayer(id,event:event) { return }
            if page == .prayers && id == 779 && event == 0 {
                if showPsalter { showPsalter=false } else { openPsalter() }
                try render(); return
            }
            if id == 90 && event == 0 {
                let names = page == .settings && editor == nil ? (text(311),text(313)) : nil
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
            if page == .home && event == 0 && (1000..<5000).contains(id) {
                let entries=try practice.entries(on: selectedDate), index=Int(id%1000)
                guard entries.indices.contains(index) else { return }
                selectedRow=index
                let entry=entries[index]
                if id < 2000 { try openHomeEntry(entry) }
                else if id < 3000 { try toggleHomeKept(entry) }
                else if id < 4000 { expandedRuleID=expandedRuleID == entry.rule.id ? nil : entry.rule.id; revealExpandedCard=expandedRuleID != nil }
                else if let slug=entry.rule.glossarySlug { showGlossaryTerm(slug); return }
                try render(); return
            }
            if page == .prayers && showPsalter && handlePsalter(control: id, event: event) { return }
            if page == .reading && handleReading(control:id,event:event) { return }
            if page == .settings && handleSettings(control: id, event: event) {
                return
            }
            if let target = Page(rawValue: Int(id)), event == 0 {
                if page != target { weekAnchor=CalendarDate(Date(),in:.current); visibleMonth=weekAnchor; calendarExpanded=false; calendarTouched=nil; ch_calendar_browse(0) }
                editor = nil; libraryCaution = false; ch_reset_home_scroll(); page = target; glossarySlug = nil; glossaryQuery = ""; selectedRow = 0; notice = ""; readingTarget=nil; showPsalter=false; rulePrayerID=nil
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
                    calendarTouched=Date(); ch_calendar_browse(1)
                    if calendarExpanded {
                        let first=CalendarDate(year:visibleMonth.year,month:visibleMonth.month,day:1)!
                        visibleMonth=id == 711 ? first.adding(days:-1) : first.adding(days:first.lastDayOfMonth)
                    } else { weekAnchor=weekAnchor.adding(days:id == 711 ? -7 : 7) }
                case 713: calendarExpanded.toggle(); if calendarExpanded { visibleMonth=selectedDate }
                case 403: setHomeDate(selectedDate.adding(days:-1))
                case 404: setHomeDate(CalendarDate(Date(),in:.current))
                case 405: setHomeDate(selectedDate.adding(days:1))
                case 406:
                    if try practice.entries(on:selectedDate).isEmpty { page = .library; selectedRow=0 }
                    else { try showRuleMenu(); return }
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
                case 414: beginCustomRule()
                case 450...458, 460...462: try homeRuleAction(id)
                default: return
                }
            } else { return }
            try render()
        } catch {
            actionError = error.localizedDescription
            if id == -1 || notificationSmoke { print("UI verification failed: \(error)"); ch_close(1) }
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
        if ProcessInfo.processInfo.environment["CHOTKI_VISUAL_REVIEW"]=="1" {
            verifying=true; defer { verifying=false }
            try press(101); try captureReview("visual-library-top")
            try press(90); try captureReview("visual-sidebar-collapsed"); try press(90)
            if let index=templates.firstIndex(where:{ !$0.glossarySlugs.isEmpty }) {
                let firstLink=Int32(19000+index*3)
                try require(ch_test_library_hover(firstLink,0)==0 && ch_test_library_hover(firstLink,1)==1,"Library glossary links did not follow row hover")
                try captureReview("visual-library-hover")
                try require(ch_test_library_hover(firstLink,0)==0,"Library glossary links remained visible after mouse exit")
            }
            ch_test_panel_wheel(5); try captureReview("visual-library-wheel")
            ch_test_panel_scroll(1); try captureReview("visual-library-bottom")
            let presetIndex=templates.firstIndex { $0.title.localizedCaseInsensitiveContains("Morning prayers") }!
            try press(Int32(11000+presetIndex))
            try require(editor?.presetHeading == templates[presetIndex].title.capitalized,"Preset editor heading")
            try captureReview("visual-preset-editor")
            if editor?.reminders == false { try press(533) }
            try press(533)
            try require(ch_checked(534)==0 && ch_checked(535)==0 && ch_checked(536)==0,"Silenced reminder leads must look unchecked")
            try captureReview("visual-reminder-off")
            try press(551)
            try press(100); try captureReview("visual-home")
            ch_test_resize(760,640); try render(); try captureReview("visual-home-narrow")
            ch_test_resize(620,540); try render(); try captureReview("visual-home-minimum")
            try require(ch_test_control_intersects(750)==1,"Home artwork disappeared at minimum size")
            try press(102); try choosePrayer("morning")
            try captureReview("visual-prayers")
            try require(ch_test_reader_painted(301)==1,"Prayer text disappeared after repaint")
            showGlossaryTerm("amen"); try captureReview("visual-glossary")
            try require(ch_test_reader_painted(6014)==1,"Glossary text disappeared after repaint")
            try press(6063); try press(106); try captureReview("visual-glossary-list")
            try require(ch_test_reader_painted(6014)==1,"Glossary list disappeared after repaint")
            try press(104); try captureReview("visual-progress")
            ch_test_resize(760,640); try render(); try captureReview("visual-progress-narrow")
            ch_test_resize(620,540); try render(); try captureReview("visual-progress-minimum")
            print("Visible reader repaint checks passed."); ch_close(0); return
        }
        verifying = true
        defer { verifying = false }
        guard ch_click(2000) == 1, try practice.entries(on: selectedDate).first?.isKept == true else { throw BootstrapError.verification("Home mark control") }
        guard ch_click(2000) == 1, try practice.entries(on: selectedDate).first?.isKept == false else { throw BootstrapError.verification("Home unmark control") }
        guard ch_click(402) == 1, page == .library else { throw BootstrapError.verification("Home Add route") }
        let templateIndex = templates.firstIndex { $0.title != "Jesus Prayer" }!
        try press(Int32(11000+templateIndex))
        try require(editor != nil && (try store.rules(includeArchived: false).count) == 1, "Taking a new template must open the editor first")
        try press(550)
        try require(try store.rules(includeArchived: false).count == 2, "Library editor save must activate the selected rule")
        guard ch_click(102) == 1, page == .prayers else { throw BootstrapError.verification("Prayer route") }
        guard ch_click(420) == 1, rope.count == 1 else { throw BootstrapError.verification("Prayer count") }
        guard ch_click(421) == 1, rope.count == 0 else { throw BootstrapError.verification("Prayer reset") }
        for target in [Page.reading, .progress, .settings, .glossary] {

            guard ch_click(Int32(target.rawValue)) == 1, page == target else {
                throw BootstrapError.verification("Navigation to \(target)")
            }
        }

        try verifyOnboardingAndSound(); ch_flush()
        try verifyNotificationControls(); ch_flush()
        try verifyRuleControls(); ch_flush()
        try verifySettingsControls(); ch_flush()
        try verifyLibraryAndProgress(); ch_flush()
        try verifyHomeControls(); ch_flush()
        try verifyReaderControls(); ch_flush()
        try verifyReadingSections(); ch_flush()
        try verifyPrayerControls(); ch_flush()
        try verifyTrayControls()
        page = .home; selectedRow = 0; notice = "Synthetic review · Control checks passed"; try render()
        if let path = ProcessInfo.processInfo.environment["CHOTKI_REVIEW_CAPTURE"] {
            guard path.withCString({ ch_capture($0) }) == 1 else { throw BootstrapError.verification("Window capture") }
        }
        print("UI controls passed: all seven pages, Home mark/unmark, Add route, Library activation, prayer count/reset.")
        try require(ch_test_tray(Int32(CH_TRAY_QUIT)) == 1 && ch_tray_present() == 0, "Tray Quit must remove the icon and exit")
        print("Tray Quit passed: icon removed and application closed.")
    }
}
