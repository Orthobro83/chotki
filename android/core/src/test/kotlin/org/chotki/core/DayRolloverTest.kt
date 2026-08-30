package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals

/** Translated from Swift's "The day the view is showing". */
class DayRolloverTest {

    /** Non-null asserted: every date below is a real day, and a null here
     *  would mean the test itself is wrong. */
    private fun date(y: Int, m: Int, d: Int) = CalendarDate.of(y, m, d)!!

    /** The reported bug: closed on the 28th, opened on the 29th. */
    @Test
    fun `a view that was on today moves to the new today`() {
        assertEquals(
            date(2026, 8, 29),
            DayRollover.selection(
                showing = date(2026, 8, 28),
                wasToday = date(2026, 8, 28),
                isToday = date(2026, 8, 29),
            ),
        )
    }

    @Test
    fun `a day chosen on purpose is left alone`() {
        assertEquals(
            date(2026, 8, 20),
            DayRollover.selection(
                showing = date(2026, 8, 20),
                wasToday = date(2026, 8, 28),
                isToday = date(2026, 8, 29),
            ),
            "looking back at last week was interrupted",
        )
    }

    @Test
    fun `it catches up however many days have passed`() {
        assertEquals(
            date(2026, 10, 3),
            DayRollover.selection(
                showing = date(2026, 8, 28),
                wasToday = date(2026, 8, 28),
                isToday = date(2026, 10, 3),
            ),
        )
    }

    @Test
    fun `it follows the clock backwards too`() {
        assertEquals(
            date(2026, 8, 28),
            DayRollover.selection(
                showing = date(2026, 8, 29),
                wasToday = date(2026, 8, 29),
                isToday = date(2026, 8, 28),
            ),
        )
    }

    @Test
    fun `nothing moves when the day has not changed`() {
        for (showing in listOf(date(2026, 8, 29), date(2026, 8, 20))) {
            assertEquals(
                showing,
                DayRollover.selection(
                    showing = showing,
                    wasToday = date(2026, 8, 29),
                    isToday = date(2026, 8, 29),
                ),
            )
        }
    }
}
