import Testing
@testable import ChotkiCore

@Suite("The link back to today")
struct TodayLinkTests {
    let today = CalendarDate(year: 2026, month: 10, day: 6)!

    @Test("On today there is no link")
    func onToday() {
        #expect(TodayLink.needed(selected: today, today: today, visibleMonth: today, monthOpen: false) == nil)
        #expect(TodayLink.needed(selected: today, today: today, visibleMonth: today, monthOpen: true) == nil)
    }

    @Test("In the future the link is on the left and points back")
    func future() {
        let link = TodayLink.needed(selected: today.adding(days: 3), today: today, visibleMonth: today, monthOpen: false)
        #expect(link == .onTheLeft)
        #expect(link?.text == "\u{2190} Today")
    }

    @Test("In the past the link is on the right and points forward")
    func past() {
        let link = TodayLink.needed(selected: today.adding(days: -3), today: today, visibleMonth: today, monthOpen: false)
        #expect(link == .onTheRight)
        #expect(link?.text == "Today \u{2192}")
    }

    @Test("Browsing months with today still selected also offers the way back")
    func browsingMonths() {
        let next = CalendarDate(year: 2026, month: 12, day: 1)!, earlier = CalendarDate(year: 2026, month: 8, day: 1)!
        #expect(TodayLink.needed(selected: today, today: today, visibleMonth: next, monthOpen: true) == .onTheLeft)
        #expect(TodayLink.needed(selected: today, today: today, visibleMonth: earlier, monthOpen: true) == .onTheRight)
        // The month is only looked at while it is open.
        #expect(TodayLink.needed(selected: today, today: today, visibleMonth: next, monthOpen: false) == nil)
    }

    @Test("Across a year boundary")
    func acrossYears() {
        let jan = CalendarDate(year: 2027, month: 1, day: 2)!
        #expect(TodayLink.needed(selected: jan, today: today, visibleMonth: jan, monthOpen: false) == .onTheLeft)
    }
}
