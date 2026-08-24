package org.chotki.core

import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int): CalendarDate =
    CalendarDate.of(y, m, day) ?: error("$y-$m-$day is not a date")

/** Translated from `CalendarDateTests.swift`, suite "CalendarDate". */
class CalendarDateTest {

    @Test
    fun `rejects days the month does not have`() {
        assertNull(CalendarDate.of(2026, 4, 31))
        assertNull(CalendarDate.of(2026, 2, 29))     // 2026 is common
        assertNotNull(CalendarDate.of(2028, 2, 29))  // 2028 is leap
        assertNull(CalendarDate.of(2026, 13, 1))
    }

    @Test
    fun `leap years follow the full Gregorian rule, not just divisible by four`() {
        assertTrue(CalendarDate.isLeapYear(2028))
        assertTrue(!CalendarDate.isLeapYear(2026))
        assertTrue(!CalendarDate.isLeapYear(1900))  // century, not divisible by 400
        assertTrue(CalendarDate.isLeapYear(2000))   // divisible by 400
        assertEquals(29, CalendarDate.daysInMonth(2028, 2))
        assertEquals(28, CalendarDate.daysInMonth(2026, 2))
    }

    // Anchored against a date verified independently: orthocal reported
    // 19 August 2026 as a Wednesday.
    @Test
    fun `weekday is correct`() {
        assertEquals(Weekday.WEDNESDAY, d(2026, 8, 19).weekday)
        assertEquals(Weekday.FRIDAY, d(2026, 8, 21).weekday)
        assertEquals(Weekday.SUNDAY, d(2026, 8, 23).weekday)
    }

    @Test
    fun `day arithmetic crosses months and years`() {
        assertEquals(d(2026, 9, 1), d(2026, 8, 31).plusDays(1))
        assertEquals(d(2027, 1, 1), d(2026, 12, 31).plusDays(1))
        assertEquals(d(2025, 12, 31), d(2026, 1, 1).plusDays(-1))
        assertEquals(d(2028, 2, 29), d(2028, 2, 28).plusDays(1))  // leap
        assertEquals(d(2026, 3, 1), d(2026, 2, 28).plusDays(1))   // common
    }

    @Test
    fun `orders chronologically`() {
        assertTrue(d(2026, 1, 31) < d(2026, 2, 1))
        assertTrue(d(2025, 12, 31) < d(2026, 1, 1))
        assertEquals(d(2026, 8, 19), d(2026, 8, 19))
    }
}

/**
 * The reason CalendarDate exists. A rule due at 06:30 must be due at 06:30 on
 * both sides of a clock change — these tests are the proof, and they are the
 * ones most likely to catch a regression if anyone "simplifies" the model to
 * store instants.
 *
 * Translated from suite "DST".
 */
class DSTTest {

    private val zones = listOf("America/New_York", "Europe/London", "Europe/Berlin")

    private fun localTime(instant: java.time.Instant, zone: ZoneId): Pair<Int, Int> {
        val local = LocalDateTime.ofInstant(instant, zone)
        return local.hour to local.minute
    }

    @Test
    fun `0630 stays 0630 across spring forward`() {
        val morning = TimeOfDay.of(6, 30)!!
        for (zoneName in zones) {
            val zone = ZoneId.of(zoneName)
            // Span every day of March, which holds the transition in all three.
            for (day in 1..31) {
                val date = d(2026, 3, day)
                val instant = date.dueInstant(morning, zone)
                assertNotNull(instant, "06:30 should exist on $date in $zoneName")
                assertEquals(6 to 30, localTime(instant, zone), "drifted on $date in $zoneName")
            }
        }
    }

    @Test
    fun `0630 stays 0630 across autumn fall back`() {
        val morning = TimeOfDay.of(6, 30)!!
        for (zoneName in zones) {
            val zone = ZoneId.of(zoneName)
            for ((month, lastDay) in listOf(10 to 31, 11 to 30)) {
                for (day in 1..lastDay) {
                    val date = d(2026, month, day)
                    val instant = date.dueInstant(morning, zone)
                    assertNotNull(instant, "06:30 should exist on $date in $zoneName")
                    assertEquals(6 to 30, localTime(instant, zone), "drifted on $date in $zoneName")
                }
            }
        }
    }

    // A time that does not exist must be refused, not silently shifted an hour.
    // The caller decides what to do; being handed a wrong instant is worse than
    // being handed nothing.
    @Test
    fun `a time skipped by spring forward is refused`() {
        val zone = ZoneId.of("America/New_York")
        // 8 March 2026, 02:00 to 03:00. 02:30 never happens.
        val skipped = TimeOfDay.of(2, 30)!!
        assertNull(d(2026, 3, 8).dueInstant(skipped, zone))
        // The same wall time is fine the day before and the day after.
        assertNotNull(d(2026, 3, 7).dueInstant(skipped, zone))
        assertNotNull(d(2026, 3, 9).dueInstant(skipped, zone))
    }

    @Test
    fun `an hour repeated by fall back still resolves`() {
        val zone = ZoneId.of("America/New_York")
        // 1 November 2026, 02:00 back to 01:00. 01:30 happens twice; one is enough.
        val repeated = TimeOfDay.of(1, 30)!!
        val instant = d(2026, 11, 1).dueInstant(repeated, zone)
        assertNotNull(instant)
        assertEquals(1 to 30, localTime(instant, zone))
    }
}

/** Translated from suite "Counting days". */
class DayCountingTest {

    @Test
    fun `the epoch is day zero`() {
        assertEquals(0, d(1970, 1, 1).daysSinceEpoch)
        assertEquals(-1, d(1969, 12, 31).daysSinceEpoch)
        assertEquals(1, d(1970, 1, 2).daysSinceEpoch)
    }

    @Test
    fun `distance matches stepping a day at a time`() {
        // Across a leap day, a century, and a year boundary.
        val starts = listOf(d(2026, 8, 19), d(2028, 2, 27), d(1899, 12, 30), d(2099, 12, 30))
        for (days in listOf(1, 2, 27, 28, 29, 31, 59, 365, 366, 1_000)) {
            for (start in starts) {
                assertEquals(days, start.daysUntil(start.plusDays(days)))
                assertEquals(-days, start.plusDays(days).daysUntil(start))
            }
        }
    }

    // The previous Swift implementation stepped one day at a time and gave up
    // after four thousand, returning a wrong answer without saying so.
    @Test
    fun `distances beyond eleven years are still correct`() {
        assertEquals(10_957, d(1970, 1, 1).daysUntil(d(2000, 1, 1)))
        assertEquals(
            36_525, d(2000, 1, 1).daysUntil(d(2100, 1, 1)),
            "2000 is a leap year, so this century has 25",
        )
        assertEquals(
            36_524, d(2026, 1, 1).daysUntil(d(2126, 1, 1)),
            "this one skips 2100, so 24",
        )
    }

    @Test
    fun `the same day is zero apart`() {
        assertEquals(0, d(2026, 8, 19).daysUntil(d(2026, 8, 19)))
    }

    @Test
    fun `a year is 365 days, and a leap year 366`() {
        assertEquals(365, d(2026, 1, 1).daysUntil(d(2027, 1, 1)))
        assertEquals(366, d(2028, 1, 1).daysUntil(d(2029, 1, 1)))
        assertEquals(365, d(1900, 1, 1).daysUntil(d(1901, 1, 1)), "1900 was not a leap year")
        assertEquals(366, d(2000, 1, 1).daysUntil(d(2001, 1, 1)), "2000 was")
    }
}
