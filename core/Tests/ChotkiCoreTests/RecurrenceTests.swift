import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

@Suite("Recurrence patterns")
struct RecurrencePatternTests {
    let engine = RecurrenceEngine()

    @Test("daily produces every day in range")
    func daily() {
        let days = engine.patternDates(for: .daily, from: d(2026, 8, 17), through: d(2026, 8, 23))
        #expect(days.count == 7)
        #expect(days.first == d(2026, 8, 17))
        #expect(days.last == d(2026, 8, 23))
    }

    @Test("the Wednesday and Friday fast lands only on those weekdays")
    func wednesdayAndFriday() {
        let days = engine.patternDates(
            for: .wednesdayAndFriday, from: d(2026, 8, 1), through: d(2026, 8, 31)
        )
        #expect(days.allSatisfy { $0.weekday == .wednesday || $0.weekday == .friday })
        #expect(days.contains(d(2026, 8, 19)))
        #expect(days.contains(d(2026, 8, 21)))
        #expect(!days.contains(d(2026, 8, 20)))
    }

    @Test("once produces exactly its own day")
    func once() {
        let days = engine.patternDates(
            for: .once(d(2026, 8, 19)), from: d(2026, 8, 1), through: d(2026, 8, 31)
        )
        #expect(days == [d(2026, 8, 19)])
    }

    // The case that quietly loses nearly half the year if got wrong.
    @Test("monthly on the 31st falls back to the last day of a short month")
    func monthlyThirtyFirstClamps() {
        let days = engine.patternDates(
            for: .monthly(day: 31), from: d(2026, 1, 1), through: d(2026, 12, 31)
        )
        #expect(days.count == 12, "every month should produce exactly one occurrence")
        #expect(days.contains(d(2026, 1, 31)))
        #expect(days.contains(d(2026, 2, 28)), "February clamps to the 28th in a common year")
        #expect(days.contains(d(2026, 4, 30)), "April clamps to the 30th")
        #expect(days.contains(d(2026, 6, 30)))
        #expect(days.contains(d(2026, 9, 30)))
        #expect(days.contains(d(2026, 11, 30)))
    }

    @Test("February clamps to the 29th in a leap year")
    func monthlyClampsToLeapDay() {
        let days = engine.patternDates(
            for: .monthly(day: 31), from: d(2028, 2, 1), through: d(2028, 2, 29)
        )
        #expect(days == [d(2028, 2, 29)])
    }

    @Test("the skip policy omits short months entirely")
    func monthlySkips() {
        let days = engine.patternDates(
            for: .monthly(day: 31, whenShort: .skip),
            from: d(2026, 1, 1), through: d(2026, 12, 31)
        )
        #expect(days.count == 7, "only the seven 31-day months")
        #expect(!days.contains(where: { $0.month == 2 }))
        #expect(!days.contains(where: { $0.month == 4 }))
    }

    @Test("a rule tied to the leap day occurs only in leap years")
    func leapDayRule() {
        let common = engine.patternDates(
            for: .monthly(day: 29, whenShort: .skip),
            from: d(2026, 2, 1), through: d(2026, 2, 28)
        )
        #expect(common.isEmpty)
        let leap = engine.patternDates(
            for: .monthly(day: 29, whenShort: .skip),
            from: d(2028, 2, 1), through: d(2028, 2, 29)
        )
        #expect(leap == [d(2028, 2, 29)])
    }

    @Test("an inverted range produces nothing rather than looping")
    func invertedRange() {
        #expect(engine.patternDates(for: .daily, from: d(2026, 8, 20), through: d(2026, 8, 19)).isEmpty)
    }
}

/// The activation intersection is the mechanism behind "enable later" and
/// "pause without penalty". These are the tests that keep the score honest.
@Suite("Activation windows")
struct ActivationTests {
    let engine = RecurrenceEngine()

    private func rule() -> Rule {
        Rule(title: "Evening prayers", recurrence: .daily, timeOfDay: TimeOfDay(hour: 21, minute: 30))
    }

    @Test("a rule taken on today invents no history behind it")
    func noRetroactiveHistory() {
        let r = rule()
        let activations = [Activation(ruleID: r.id, from: d(2026, 8, 19))]
        let due = engine.dueDates(
            rule: r, activations: activations,
            from: d(2026, 1, 1), through: d(2026, 8, 31)
        )
        #expect(due.first == d(2026, 8, 19), "nothing before the day it was taken on")
        #expect(!due.contains(d(2026, 8, 18)))
        #expect(due.count == 13)
    }

    @Test("a paused stretch produces nothing due, so it cannot read as missed")
    func pausedStretchIsNotDue() {
        let r = rule()
        let activations = [
            Activation(ruleID: r.id, from: d(2026, 3, 1), to: d(2026, 4, 30)),
            Activation(ruleID: r.id, from: d(2026, 6, 1))
        ]
        let due = engine.dueDates(
            rule: r, activations: activations,
            from: d(2026, 1, 1), through: d(2026, 6, 30)
        )
        #expect(due.contains(d(2026, 4, 30)), "in force up to and including the pause day")
        #expect(!due.contains(d(2026, 5, 1)), "the gap is not due")
        #expect(!due.contains(d(2026, 5, 31)))
        #expect(due.contains(d(2026, 6, 1)), "back in force on resume")
        #expect(due.filter { $0.month == 5 }.isEmpty, "May is entirely absent, not missed")
    }

    @Test("a rule with no activation at all is never due")
    func noActivationMeansNeverDue() {
        let r = rule()
        #expect(engine.dueDates(
            rule: r, activations: [], from: d(2026, 1, 1), through: d(2026, 12, 31)
        ).isEmpty)
    }

    @Test("activations belonging to other rules are ignored")
    func foreignActivationsIgnored() {
        let mine = rule()
        let theirs = Rule(title: "Morning prayers", recurrence: .daily)
        let activations = [Activation(ruleID: theirs.id, from: d(2026, 1, 1))]
        #expect(engine.dueDates(
            rule: mine, activations: activations, from: d(2026, 1, 1), through: d(2026, 12, 31)
        ).isEmpty)
    }

    @Test("a seasonal rule is due only inside its stretch")
    func seasonalRule() {
        let r = Rule(title: "Lenten rule", recurrence: .daily)
        let activations = [Activation(ruleID: r.id, from: d(2026, 2, 23), to: d(2026, 4, 11))]
        let due = engine.dueDates(
            rule: r, activations: activations, from: d(2026, 1, 1), through: d(2026, 12, 31)
        )
        #expect(due.first == d(2026, 2, 23))
        #expect(due.last == d(2026, 4, 11))
        #expect(!due.contains(d(2026, 5, 1)))
    }
}
