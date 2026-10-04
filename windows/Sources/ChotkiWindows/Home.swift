import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func homeCardSummary(_ entry:DayEntry) -> String {
        if flippedRuleID==entry.rule.id {
            return entry.dispensation.map { "Not observed during \($0)." }
                ?? entry.rule.glossarySlug.flatMap { Glossary.shared(for:settings.jurisdiction.tradition).entry(slug:$0)?.short }
                ?? ruleSummary(entry.rule)
        }
        return RuleLibrary.shared.templates.first { $0.title==entry.rule.title }?.summary ?? entry.rule.note ?? "A rule of your own."
    }
    func expandedCardHeight(_ entry:DayEntry) -> Int32 {
        let title=entry.rule.title.withCString { ch_measure_reading($0,272,18) }
        let body=homeCardSummary(entry).withCString { ch_measure_reading($0,272,13) }
        let source=entry.rule.suggestedByLabel(currentFather:settings.spiritualFatherName) ?? ""
        let attribution=source.isEmpty ? 0 : source.withCString { ch_measure_text($0,272,512) }
        return max(232,124+title+body+attribution)
    }
    var contentLeft: Int32 { sidebarCollapsed ? 82 : 212 }
    var contentWidth: Int32 { max(310, ch_width()-contentLeft-24) }
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = settings.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Good \(hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening")" + (name.isEmpty ? "" : ", \(name)")
    }
    func renderSidebar() {
        control(90, 9, sidebarCollapsed ? "" : "Sidebar", 10, 7, sidebarCollapsed ? 38 : 168, 32)
        ch_style(90,4096 | (sidebarCollapsed ? 8192 : 0))
        let groups: [(String, [(Page, String)])] = [
            ("The Day", [(.home,"Home")]), ("To Read", [(.prayers,"Prayers"),(.reading,"Reading")]),
            ("The Record", [(.progress,"Progress"),(.library,"Library")]),
            ("Reference", [(.glossary,"Glossary"),(.settings,"Settings")])]
        var y: Int32 = sidebarCollapsed ? 48 : 55
        for (label, items) in groups {
            if !sidebarCollapsed { control(80+y, 0, label, 20, y, 158, 19); ch_style(80+y,64|512) }
            y += sidebarCollapsed ? 12 : 25
            for (item, title) in items {
                control(Int32(item.rawValue), 9, sidebarCollapsed ? "" : title,
                        10, y, sidebarCollapsed ? 38 : 168, 36)
                ch_style(Int32(item.rawValue),4096 | (sidebarCollapsed ? 8192 : 0) | (page == item ? 1 : 0))
                y += 40
            }
            y += sidebarCollapsed ? 4 : 12
        }
    }
    func renderHome() throws {
        control(200, 5, greeting, contentLeft, 24, contentWidth, 38)
        control(402, 18, "+", contentLeft+contentWidth-40, 22, 40, 40)
        ch_font_size(402,26,0,0)
        var days: [CalendarDate] = []
        let calendarTop: Int32 = 80
        let calendarHeight: Int32
        if calendarExpanded {
            calendarHeight = 258
            let first = CalendarDate(year: visibleMonth.year, month: visibleMonth.month, day: 1)!
            let start = first.adding(days: 1-first.weekday.rawValue)
            days = (0..<42).map { start.adding(days: $0) }
            control(710, 0, Format.monthAndYear(visibleMonth), contentLeft+80, calendarTop, contentWidth-160, 28)
            control(711, 18, "‹", contentLeft, calendarTop, 28, 28)
            control(712, 18, "›", contentLeft+contentWidth-28, calendarTop, 28, 28)
            let gridWidth = min(600, contentWidth), cell = gridWidth/7, left = contentLeft+(contentWidth-gridWidth)/2
            for i in 0..<7 { control(Int32(730+i), 0, ["S","M","T","W","T","F","S"][i], left+Int32(i)*cell+12, calendarTop+38, cell, 15); ch_style(Int32(730+i),64) }
            for (i, day) in days.enumerated() where day.month == visibleMonth.month && day.year == visibleMonth.year {
                calendarChip(day, id: Int32(800+i), x: left+Int32(i%7)*cell+2,
                             y: calendarTop+58+Int32(i/7)*29, width: cell-5, height: 26, week: false)
            }
            control(713, 18, "⌃", contentLeft+contentWidth/2-24, calendarTop+232, 48, 18)
        } else {
            calendarHeight = 90
            days = (0..<7).map { weekAnchor.adding(days: $0-3) }
            let cell = min(48,(contentWidth-64)/7), width=cell*7, left=contentLeft+(contentWidth-width)/2
            control(711, 18, "‹", left-28, calendarTop+13, 22, 28)
            control(712, 18, "›", left+width+6, calendarTop+13, 22, 28)
            for (i, day) in days.enumerated() {
                calendarChip(day, id: Int32(800+i), x: left+Int32(i)*cell, y: calendarTop, width: cell-6, height: 54, week: true)
            }
            control(713, 18, "⌄", contentLeft+contentWidth/2-24, calendarTop+60, 48, 18)
        }
        calendarDates = days
        let entries = try practice.entries(on: selectedDate)
        selectedRow = entries.isEmpty ? 0 : min(selectedRow,entries.count-1)
        let day = liturgical.cachedDay(for: selectedDate)
        let title = day?.title ?? (liturgical.isOffline ? "Calendar unavailable · Stored days remain available offline" : "")
        let panelTop = calendarTop+calendarHeight
        let extra: Int32 = day != nil && settings.observances.fasting.isVisible && day!.isFast && entries.contains(where: { $0.rule.isFastingRule }) ? 50 : 0
        let compactCardHeight: Int32 = ch_height()<650 ? 96 : 232
        let expandedHeight: Int32 = entries.first { $0.rule.id==expandedRuleID }.map(expandedCardHeight) ?? compactCardHeight
        let dateY: Int32 = 8 + (title.isEmpty ? 0 : 36) + extra
        let cardsY = dateY+64
        let artY = cardsY+expandedHeight+18
        ch_home_begin(contentLeft,panelTop,contentWidth,max(120,ch_height()-panelTop-24),artY+294)
        if !title.isEmpty { control(740,0,title,0,8,contentWidth,22); ch_style(740,64|1024) }
        control(741,0,Format.longDate(selectedDate),0,dateY,contentWidth-140,24); ch_style(741,256)
        if settings.showOldStyleDates {
            let old=day?.observedDate ?? selectedDate.adding(days:-13)
            control(742,0,"\(old.day) \(Format.shortMonth(old.month)) o.s.",contentWidth-115,dateY+3,115,20); ch_style(742,64)
        }
        if extra>0,let day {
            control(743,0,"The calendar marks this as \(day.fastDescription).",0,dateY-extra,contentWidth,22); ch_style(743,1024)
            control(744,0,"Customarily set aside: \(day.abstentions.joined(separator:", ")).",0,dateY-extra+23,contentWidth,22); ch_style(744,64)
        }
        control(745,0,"Today's Commitments",0,dateY+34,134,20); ch_style(745,64)
        control(746,18,"Add a New Rule",134,dateY+32,110,24)
        var x: Int32 = 0
        let total = entries.isEmpty ? contentWidth : Int32(entries.count)*144 + (expandedRuleID == nil ? 0 : 168) + 132
        ch_cards_begin(0,cardsY,contentWidth,expandedHeight+20,total)
        ch_select(300,Int32(selectedRow))
        for (i, entry) in entries.enumerated() {
            let expanded = expandedRuleID == entry.rule.id
            let width: Int32 = expanded ? 300 : 132
            let category = entry.rule.category.flatMap(RuleCategory.init(rawValue:))?.displayName ?? "Custom"
            let summary = homeCardSummary(entry)
            let time = entry.isDispensed ? "Lifted Today" : entry.isStoodDown ? "Stood Down" : entry.rule.timeOfDay.map { Format.time($0,settings.clockStyle) } ?? "All Day"
            let attribution = entry.rule.suggestedByLabel(currentFather: settings.spiritualFatherName) ?? ""
            entry.rule.title.withCString { title in summary.withCString { body in category.withCString { cat in time.withCString { time in attribution.withCString { source in
                ch_card(Int32(1000+i),title,body,cat,time,source,x,width,expanded ? expandedHeight : compactCardHeight)
            } } } } }
            control(Int32(2000+i),16,"\(entry.isKept ? "Clear" : "Mark") \(entry.rule.title) as kept",x+width-32,10,22,22)
            ch_style(Int32(2000+i),entry.showsAsSatisfied ? 1 : 0); ch_enable(Int32(2000+i),entry.isDispensed ? 0 : 1)
            if flippedRuleID==entry.rule.id,entry.rule.glossarySlug != nil {
                control(Int32(4000+i),18,"Learn More",x+14,expanded ? expandedHeight-32 : compactCardHeight-34,100,24)
            } else {
            control(Int32(3000+i),17,expanded ? "↙" : "↗",x+width-32,expanded ? expandedHeight-30 : compactCardHeight-34,24,24)
            }
            x += width+12
        }
        control(747,entries.isEmpty ? 28 : 1,entries.isEmpty ? "Create your First Rule" : "+  Add",x,0,entries.isEmpty ? contentWidth : 120,compactCardHeight)
        ch_cards_end()
        if revealExpandedCard,let index=entries.firstIndex(where: { $0.rule.id==expandedRuleID }) {
            ch_reveal_card(Int32(1000+index)); revealExpandedCard=false
        }
        if let saying = PatristicReadings.shared.reading(for: selectedDate), let (image,fx,fy) = WindowsAssets.image(on: selectedDate) {
            image.path.withCString { path in saying.text.withCString { quote in "\(saying.author) · \(saying.source)".withCString { source in
                ch_image(750,path,quote,source,fx,fy,0,artY,contentWidth,270)
            } } }

        }
        ch_home_end()
        control(404,18,"Today",contentLeft+contentWidth-90,calendarTop+54,90,22)
        // The retained explicit action route is also reachable by keyboard.
        control(406,18,"…",contentLeft+contentWidth-65,28,28,28)

        requestCalendar()
    }
    func calendarChip(_ date: CalendarDate,id: Int32,x: Int32,y: Int32,width: Int32,height: Int32,week: Bool) {
        let day=liturgical.cachedDay(for: date)
        let feast=settings.observances.feasts.isVisible && day?.isGreatFeast == true
        let fast=settings.observances.fasting.isVisible && day?.isFast == true && date.weekday != .sunday && !feast
        let settled=(try? practice.isSettled(on: date)) == true
        control(id,10,week ? "\(["S","M","T","W","T","F","S"][date.weekday.rawValue-1])\n\(date.day)" : "\(date.day)",x,y,width,height)
        ch_style(id,(date == selectedDate ? 1 : 0) | (fast ? 2 : 0) | (feast ? 4 : 0) | (date.weekday == .sunday ? 8 : 0) | (settled ? 16 : 0))
    }
    func setHomeDate(_ date: CalendarDate) {
        if selectedDate != date {
            expandedReadingBands.removeAll(); appointedKathisma=nil; manualKathisma=nil
        }
        calendarTouched=Date(); ch_calendar_browse(1); selectedDate=date; weekAnchor=date; visibleMonth=date; selectedRow=0
        expandedRuleID=nil; flippedRuleID=nil; notice=""; ch_reset_home_scroll()
    }
}
