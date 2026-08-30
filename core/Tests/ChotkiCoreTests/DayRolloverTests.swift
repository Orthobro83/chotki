import Testing
import Foundation
@testable import ChotkiCore

@Suite("The day the view is showing")
struct DayRolloverTests {

    /// Force-unwrapped deliberately: every date below is a literal real day,
    /// and a nil here would mean the test itself is wrong.
    private func date(_ y: Int, _ m: Int, _ d: Int) -> CalendarDate {
        CalendarDate(year: y, month: m, day: d)!
    }

    /// The reported bug: closed on the 28th, opened on the 29th, still showing
    /// the 28th — so the rules on screen were yesterday's.
    @Test("a view that was on today moves to the new today")
    func followsTodayAcrossMidnight() {
        let shown = DayRollover.selection(
            showing: date(2026, 8, 28),
            wasToday: date(2026, 8, 28),
            isToday: date(2026, 8, 29)
        )
        #expect(shown == date(2026, 8, 29))
    }

    /// The other half, and the reason this is a rule rather than an assignment.
    @Test("a day chosen on purpose is left alone")
    func doesNotStealADeliberateChoice() {
        let shown = DayRollover.selection(
            showing: date(2026, 8, 20),
            wasToday: date(2026, 8, 28),
            isToday: date(2026, 8, 29)
        )
        #expect(shown == date(2026, 8, 20), "looking back at last week was interrupted")
    }

    /// Tapping today again resumes following, with no flag to maintain.
    @Test("returning to today starts following it again")
    func returningToTodayResumesFollowing() {
        // The reader taps today (the 29th) while today is the 29th.
        let shown = DayRollover.selection(
            showing: date(2026, 8, 29),
            wasToday: date(2026, 8, 29),
            isToday: date(2026, 8, 30)
        )
        #expect(shown == date(2026, 8, 30))
    }

    @Test("nothing moves when the day has not changed")
    func stillWhenTheDayHasNotChanged() {
        for showing in [date(2026, 8, 29), date(2026, 8, 20)] {
            let shown = DayRollover.selection(
                showing: showing, wasToday: date(2026, 8, 29), isToday: date(2026, 8, 29)
            )
            #expect(shown == showing)
        }
    }

    /// A Mac asleep over a long weekend, or a phone not opened for a month.
    @Test("it catches up however many days have passed")
    func catchesUpOverALongGap() {
        let shown = DayRollover.selection(
            showing: date(2026, 8, 28),
            wasToday: date(2026, 8, 28),
            isToday: date(2026, 10, 3)
        )
        #expect(shown == date(2026, 10, 3))
    }

    /// A clock corrected backwards, or a flight west across a date line.
    @Test("it follows the clock backwards too")
    func followsBackwards() {
        let shown = DayRollover.selection(
            showing: date(2026, 8, 29),
            wasToday: date(2026, 8, 29),
            isToday: date(2026, 8, 28)
        )
        #expect(shown == date(2026, 8, 28))
    }
}
