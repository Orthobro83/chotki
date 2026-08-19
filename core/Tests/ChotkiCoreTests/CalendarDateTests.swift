import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

@Suite("CalendarDate")
struct CalendarDateTests {

    @Test("rejects days the month does not have")
    func rejectsImpossibleDates() {
        #expect(CalendarDate(year: 2026, month: 4, day: 31) == nil)
        #expect(CalendarDate(year: 2026, month: 2, day: 29) == nil)  // 2026 is common
        #expect(CalendarDate(year: 2028, month: 2, day: 29) != nil)  // 2028 is leap
        #expect(CalendarDate(year: 2026, month: 13, day: 1) == nil)
    }

    @Test("leap years follow the full Gregorian rule, not just divisible by four")
    func leapYears() {
        #expect(CalendarDate.isLeapYear(2028))
        #expect(!CalendarDate.isLeapYear(2026))
        #expect(!CalendarDate.isLeapYear(1900))   // century, not divisible by 400
        #expect(CalendarDate.isLeapYear(2000))    // divisible by 400
        #expect(CalendarDate.daysInMonth(year: 2028, month: 2) == 29)
        #expect(CalendarDate.daysInMonth(year: 2026, month: 2) == 28)
    }

    // Anchored against a date verified independently: orthocal reported
    // 19 August 2026 as a Wednesday.
    @Test("weekday is correct")
    func weekday() {
        #expect(d(2026, 8, 19).weekday == .wednesday)
        #expect(d(2026, 8, 21).weekday == .friday)
        #expect(d(2026, 8, 23).weekday == .sunday)
    }

    @Test("day arithmetic crosses months and years")
    func addingDays() {
        #expect(d(2026, 8, 31).adding(days: 1) == d(2026, 9, 1))
        #expect(d(2026, 12, 31).adding(days: 1) == d(2027, 1, 1))
        #expect(d(2026, 1, 1).adding(days: -1) == d(2025, 12, 31))
        #expect(d(2028, 2, 28).adding(days: 1) == d(2028, 2, 29))  // leap
        #expect(d(2026, 2, 28).adding(days: 1) == d(2026, 3, 1))   // common
    }

    @Test("orders chronologically")
    func ordering() {
        #expect(d(2026, 1, 31) < d(2026, 2, 1))
        #expect(d(2025, 12, 31) < d(2026, 1, 1))
        #expect(d(2026, 8, 19) == d(2026, 8, 19))
    }
}

/// The reason CalendarDate exists. A rule due at 06:30 must be due at 06:30 on
/// both sides of a clock change — these tests are the proof, and they are the
/// ones most likely to catch a regression if anyone "simplifies" the model to
/// store instants.
@Suite("DST")
struct DSTTests {

    private func localTime(_ instant: Date, _ zone: TimeZone) -> (Int, Int) {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        let parts = c.dateComponents([.hour, .minute], from: instant)
        return (parts.hour!, parts.minute!)
    }

    @Test("06:30 stays 06:30 across spring forward", arguments: [
        "America/New_York", "Europe/London", "Europe/Berlin"
    ])
    func springForward(zoneName: String) throws {
        let zone = try #require(TimeZone(identifier: zoneName))
        let morning = TimeOfDay(hour: 6, minute: 30)!
        // Span every day of March, which contains the transition in all three zones.
        for day in 1...31 {
            let date = d(2026, 3, day)
            let instant = try #require(
                date.dueInstant(at: morning, in: zone),
                "06:30 should exist on \(date) in \(zoneName)"
            )
            #expect(localTime(instant, zone) == (6, 30), "drifted on \(date) in \(zoneName)")
        }
    }

    @Test("06:30 stays 06:30 across autumn fall back", arguments: [
        "America/New_York", "Europe/London", "Europe/Berlin"
    ])
    func fallBack(zoneName: String) throws {
        let zone = try #require(TimeZone(identifier: zoneName))
        let morning = TimeOfDay(hour: 6, minute: 30)!
        for day in 1...31 {
            let date = d(2026, 10, day)
            let instant = try #require(date.dueInstant(at: morning, in: zone))
            #expect(localTime(instant, zone) == (6, 30), "drifted on \(date) in \(zoneName)")
        }
        for day in 1...30 {
            let date = d(2026, 11, day)
            let instant = try #require(date.dueInstant(at: morning, in: zone))
            #expect(localTime(instant, zone) == (6, 30), "drifted on \(date) in \(zoneName)")
        }
    }

    // A time that does not exist must be refused, not silently shifted an hour.
    // The caller decides what to do; being handed a wrong instant is worse than
    // being handed nothing.
    @Test("a time skipped by spring forward is refused")
    func nonexistentTimeIsRefused() throws {
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        // 8 March 2026, 02:00 → 03:00. 02:30 never happens.
        let skipped = TimeOfDay(hour: 2, minute: 30)!
        #expect(d(2026, 3, 8).dueInstant(at: skipped, in: zone) == nil)
        // The same wall time is fine the day before and the day after.
        #expect(d(2026, 3, 7).dueInstant(at: skipped, in: zone) != nil)
        #expect(d(2026, 3, 9).dueInstant(at: skipped, in: zone) != nil)
    }

    @Test("an hour repeated by fall back still resolves")
    func ambiguousTimeResolves() throws {
        let zone = try #require(TimeZone(identifier: "America/New_York"))
        // 1 November 2026, 02:00 → 01:00. 01:30 happens twice; one is enough.
        let repeated = TimeOfDay(hour: 1, minute: 30)!
        let instant = try #require(d(2026, 11, 1).dueInstant(at: repeated, in: zone))
        #expect(localTime(instant, zone) == (1, 30))
    }
}
