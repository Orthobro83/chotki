import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func verifyHomeControls() throws {
        var face=[CChar](repeating:0,count:128)
        _=ch_reading_face(&face,Int32(face.count))
        let family=String(decoding:face.prefix { $0 != 0 }.map { UInt8(bitPattern:$0) },as:UTF8.self)
        try require(family.contains("XCharter"),"Reading font fell back to \(family)")
        try require(WindowsAssets.names.count==365 && !WindowsAssets.focuses.isEmpty && WindowsAssets.names.allSatisfy { FileManager.default.fileExists(atPath:WindowsAssets.root.appendingPathComponent($0).path) },"Artwork rotation/focus catalog is incomplete")

        let savedDate=selectedDate, savedToday=lastKnownToday
        let emptyDate=CalendarDate(year:2000,month:1,day:1)!
        page = .home; setHomeDate(emptyDate); try render()
        try require(try practice.entries(on:emptyDate).isEmpty && ch_test_control_visible(747)==1,"Centered first-rule prompt is missing")
        try captureReview("home-empty")
        try press(747); try require(page == .library,"First-rule prompt must open Library")
        lastKnownToday=emptyDate; page = .progress; try render()
        try require(ch_test_control_visible(20006)==1,"Empty Progress artwork must be anchored inside the viewport")
        try captureReview("progress-empty")
        lastKnownToday=savedToday; setHomeDate(savedDate)
        let date=CalendarDate(year:2026,month:8,day:19)!
        setHomeDate(date); page = .home; calendarExpanded=false
        try store.clearLiturgicalCache(reckoning:nil); try resetCalendarService()
        try require(liturgical.cachedDay(for:date)==nil,"Calendar arrival fixture was already cached")
        let redraws=calendarRedraws
        try render()
        let deadline=Date().addingTimeInterval(8)
        while (liturgical.cachedDay(for:date)==nil || calendarRedraws==redraws) && Date()<deadline {
            ch_pump(); Thread.sleep(forTimeInterval:0.01)
        }
        try require(liturgical.cachedDay(for:date) != nil && calendarRedraws>redraws,"Detached calendar fetch did not repaint through the Win32 loop")
        try require(try store.liturgicalDay(civilDate:date,reckoning:settings.jurisdiction.reckoning) != nil,"Fetched calendar did not populate SQLite")
        let previousSelection=selectedDate, anchor=weekAnchor
        try press(712)
        try require(selectedDate==previousSelection && weekAnchor==anchor.adding(days:7),"Week browsing changed the selected day")
        ch_test_calendar_expire()
        try require(weekAnchor==CalendarDate(Date(),in:.current),"Week must return to today after idle timeout")
        setHomeDate(date); try render(); try press(712)
        try press(800)
        try require(selectedDate==anchor.adding(days:4),"Week chip did not select its day")
        setHomeDate(date); try render(); try press(713)
        try require(calendarExpanded,"Month expansion")
        try press(712)
        try require(visibleMonth.month==9 && selectedDate==date,"Month browsing changed selected date")
        try press(713)
        try require(!calendarExpanded,"Week folding")
        try press(90); try require(sidebarCollapsed,"Sidebar collapse")
        try press(90); try require(!sidebarCollapsed,"Sidebar expansion")
        setHomeDate(date)
        guard let gospelTemplate=RuleLibrary.shared.templates.first(where: { $0.title=="The day's Gospel" }) else {
            throw BootstrapError.verification("Gospel template")
        }
        let gospel=gospelTemplate.makeRule(source:"the library")
        try store.save(gospel); try store.save(Activation(ruleID:gospel.id,from:date.adding(days:-3)))
        try render()
        let index=try practice.entries(on:date).firstIndex { $0.rule.id==gospel.id }!
        let before=try store.occurrences(ruleID:gospel.id,from:date,through:date)
        selectedRow=index
        try homeRuleAction(457); try render()
        try require(expandedRuleID==gospel.id,"Context-menu expansion")
        try homeRuleAction(457); try render()
        try require(expandedRuleID==nil,"Context-menu collapse")
        try press(Int32(3000+index))
        try require(expandedRuleID==gospel.id,"Expansion control opened a destination")
        try require(try store.occurrences(ruleID:gospel.id,from:date,through:date)==before,"Expansion marked a rule kept")
        try press(Int32(1000+index))
        try require(page == .home && expandedRuleID==nil,"Expanded card click did not collapse")
        try press(Int32(1000+index))
        try require(page == .reading && readingBand==0,"Gospel card did not open its own reading band")
        try require(try store.occurrences(ruleID:gospel.id,from:date,through:date).isEmpty,"Opening a reading marked it kept")
        ch_test_scroll_end(301,0); ch_pump()
        try require(try store.occurrences(ruleID:gospel.id,from:date,through:date).isEmpty,"Programmatic scrolling completed a reading")
        let firstLine=ch_first_visible_line(301)
        let identity=ch_test_reader_identity(301), redrawCount=calendarRedraws
        for _ in 0..<100 { ch_post(-3,calendarGeneration); ch_pump() }
        try require(calendarRedraws>=redrawCount+100 && ch_test_reader_identity(301)==identity && ch_first_visible_line(301)==firstLine,
                    "Calendar refresh disposed or moved the active reader")
        try render()
        try require(firstLine>0 && ch_first_visible_line(301)==firstLine,"Calendar redraw lost the reader position")
        ch_test_scroll_end(301,1); ch_pump()
        try require(try store.occurrences(ruleID:gospel.id,from:date,through:date).first?.status == .completed,"Deliberate end scroll did not complete the reading")
        try captureReview("reading")
        try press(100)
        let current=try practice.entries(on:date), row=current.firstIndex { $0.rule.id==gospel.id }!
        try press(Int32(2000+row))
        try require(try store.occurrences(ruleID:gospel.id,from:date,through:date).isEmpty,"Card completion control did not clear kept")
        try store.save(Occurrence(ruleID:gospel.id,date:date,status:.skipped))
        try render(); try press(Int32(1000+row))
        ch_test_scroll_end(301,1); ch_pump()
        try require(try store.occurrences(ruleID:gospel.id,from:date,through:date).first?.status == .skipped,"Reading overwrote a stood-down day")
        try press(103)
        try require(readingBand==nil,"Reading sidebar inherited the last rule's open band")
        try press(778)
        try require(page == .prayers && showPsalter && text(200)=="The Psalter","Psalter route")
        try press(779)
        try require(page == .prayers && !showPsalter,"Psalter return")
        try choosePrayer("morning")
        try require(rope.selection=="morning" && text(301).contains("Heavenly King"),"Morning sequence text was replaced with a single prayer")

        ch_test_resize(1100,860)
        try require(ch_width()==1100 && ch_height()==860,"Full-size review content sizing")
        page = .home; setHomeDate(date)
        var longCard=try fixture("A rule with a long public explanation")
        longCard.note=String(repeating:"Keep a small beginning, with patience and attention.\n",count:24)
        try store.save(longCard); try render()
        let longIndex=try practice.entries(on:date).firstIndex { $0.rule.id==longCard.id }!
        ch_test_resize(620,540)
        try press(Int32(3000+longIndex))
        let longEntry=try practice.entries(on:date)[longIndex]
        try require(expandedCardHeight(longEntry)>380 && ch_test_card_revealed(Int32(1000+longIndex))==1,"Long expanded card is measured and revealed")
        try captureReview("expanded-card-long")
        try press(Int32(3000+longIndex))
        longCard.archivedAt=Date(); try store.save(longCard)
        ch_test_resize(1100,860)
        // Match the Mac's built-in fictional Home record for visual comparison.
        calendarTask?.cancel()
        for var rule in try store.rules(includeArchived:true) { rule.archivedAt=Date(); try store.save(rule) }
        settings = .default; settings.displayName="Anna"; settings.hasCompletedFirstRun=true
        settings.observances=ObservanceSettings(fasting:.observed,feasts:.shown)
        try store.saveSettings(settings)
        let titles=["Morning prayers","The Wednesday and Friday fast","The day's Gospel","The life of the day's saint","The Jesus Prayer","Evening prayers"]
        for title in titles {
            let template=RuleLibrary.shared.templates.first { $0.title==title }!
            let rule=template.makeRule(source:"the library")
            try store.save(rule); try store.save(Activation(ruleID:rule.id,from:date.adding(days:-40)))
            if title=="Morning prayers" { try store.save(Occurrence(ruleID:rule.id,date:date,status:.completed)) }
        }
        page = .home; setHomeDate(date); calendarExpanded=false; sidebarCollapsed=false
        try resetCalendarService(); try render()
        ch_pump()
        let fastEntries=try practice.entries(on:date)
        if let fastIndex=fastEntries.firstIndex(where: { $0.rule.isFastingRule }),let slug=fastEntries[fastIndex].rule.glossarySlug {
            try press(Int32(1000+fastIndex))
            try require(flippedRuleID==fastEntries[fastIndex].rule.id,"Fasting card shows its explanation")
            try press(Int32(4000+fastIndex))
            try require(glossaryDetouring && glossarySlug==slug,"Fasting Learn More opens its glossary entry")
            try press(6063)
            try require(page == .home && flippedRuleID==fastEntries[fastIndex].rule.id,"Fasting glossary return preserves the card")
            try homeRuleAction(458)
            try require(glossaryDetouring && glossarySlug==slug,"Context-menu About This Rule")
            try press(6063); try press(Int32(1000+fastIndex))
        }
        try captureReview("home")
        try press(713); try captureReview("month"); try press(713)
        ch_test_resize(620,540)
        try require(ch_width()==620 && ch_height()==540,"Minimum content sizing")
        try captureReview("narrow")
        ch_test_resize(1100,860)
        try render()
        print("Home/calendar UI passed: bundled reading face and 365 images, asynchronous fetch/cache/redraw, week/month selection, sidebar, separate expand/open/complete controls, direct reading/Psalter/morning routes and deliberate-scroll completion with stood-down preservation.")
    }
}
