import Testing
import Foundation
@testable import ChotkiCore

private let zone = TimeZone(identifier: "Europe/London")!

private func day(_ y: Int, _ m: Int, _ d: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: d)!
}

private func instant(_ date: CalendarDate, _ hour: Int) -> Date {
    date.dueInstant(at: TimeOfDay(hour: hour, minute: 0)!, in: zone)!
}

private func reminder(_ date: CalendarDate, _ hour: Int, id: String) -> PlannedNotification {
    PlannedNotification(
        id: id, ruleID: UUID(), date: date, fireAt: instant(date, hour),
        request: NotificationRequest(id: id, title: "Evening prayers", body: "At \(hour):00")
    )
}

/// The decisions behind reminders, driven directly. These used to be reachable
/// only through the macOS driver, which meant they were tested on one platform
/// and would have to be rewritten — and re-debugged — for any other.
@Suite("Reminder decisions")
struct ReminderTickerTests {

    private let today = day(2026, 8, 20)

    @Test("a reminder is shown once, however often the clock ticks")
    func shownOnce() {
        var ticker = ReminderTicker()
        let planned = [reminder(today, 9, id: "a")]

        #expect(ticker.tick(planned: planned, now: instant(today, 9), timeZone: zone).show.count == 1)
        #expect(ticker.tick(planned: planned, now: instant(today, 9), timeZone: zone).show.isEmpty)
        #expect(ticker.tick(planned: planned, now: instant(today, 9), timeZone: zone).show.isEmpty)
    }

    @Test("nothing fires before its moment")
    func notEarly() {
        var ticker = ReminderTicker()
        let decision = ticker.tick(
            planned: [reminder(today, 21, id: "evening")], now: instant(today, 9), timeZone: zone
        )
        #expect(decision.isEmpty)
    }

    // The fix that prompted this: turning an observance on mid-afternoon made
    // several earlier reminders due at once.
    @Test("reminders long past their moment stay quiet")
    func staleStaysQuiet() {
        var ticker = ReminderTicker()
        let decision = ticker.tick(
            planned: [
                reminder(today, 7, id: "morning"),
                reminder(today, 12, id: "noon"),
                reminder(today, 16, id: "now")
            ],
            now: instant(today, 16), timeZone: zone
        )
        #expect(decision.show.map(\.id) == ["now"])
    }

    @Test("a stale reminder is not shown later either")
    func staleIsNotDeferred() {
        var ticker = ReminderTicker()
        let planned = [reminder(today, 7, id: "morning")]
        _ = ticker.tick(planned: planned, now: instant(today, 16), timeZone: zone)
        #expect(ticker.tick(planned: planned, now: instant(today, 16), timeZone: zone).isEmpty)
    }

    // Runs once a day, which means in practice it never runs while anyone is
    // watching. A mistake costs a whole day of silence, or of repeats.
    @Test("crossing midnight lets the next day remind again")
    func rollover() {
        var ticker = ReminderTicker()
        let tomorrow = today.adding(days: 1)

        let first = ticker.tick(
            planned: [reminder(today, 9, id: "rule:\(today.iso)")],
            now: instant(today, 9), timeZone: zone
        )
        #expect(first.show.count == 1)

        let second = ticker.tick(
            planned: [reminder(tomorrow, 9, id: "rule:\(tomorrow.iso)")],
            now: instant(tomorrow, 9), timeZone: zone
        )
        #expect(second.show.map(\.id) == ["rule:\(tomorrow.iso)"])
    }

    @Test("a reminder that leaves the plan is taken back")
    func withdrawn() {
        var ticker = ReminderTicker()
        let planned = [reminder(today, 9, id: "a")]
        _ = ticker.tick(planned: planned, now: instant(today, 9), timeZone: zone)

        let after = ticker.tick(planned: [], now: instant(today, 9), timeZone: zone)
        #expect(after.withdraw == ["a"])
        #expect(after.show.isEmpty)
    }

    @Test("something never shown is not withdrawn")
    func nothingToWithdraw() {
        var ticker = ReminderTicker()
        #expect(ticker.tick(planned: [], now: instant(today, 9), timeZone: zone).isEmpty)
    }

    @Test("a snoozed occurrence stays quiet until its hour")
    func snoozing() {
        var ticker = ReminderTicker()
        let one = reminder(today, 9, id: "a")
        ticker.snooze(ruleID: one.ruleID, date: one.date, until: instant(today, 11))

        #expect(ticker.tick(planned: [one], now: instant(today, 9), timeZone: zone).isEmpty)

        let later = PlannedNotification(
            id: "b", ruleID: one.ruleID, date: one.date, fireAt: instant(today, 12),
            request: one.request
        )
        #expect(ticker.tick(planned: [later], now: instant(today, 12), timeZone: zone).show.count == 1)
    }
}
