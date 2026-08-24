package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Differential test of the recurrence engine against the Swift core.
 *
 * `recurrence-parity.tsv` was produced by the Swift engine itself: twelve
 * patterns expanded over three years, 2026 to 2028, which spans a leap year and
 * every month length. Each line is a label and the days that pattern produced.
 *
 * Twelve patterns and 2,272 dates say more than the eight hand-written cases
 * translated from the Swift suite, and they say it about the exact shape that
 * quietly loses half a year when the short-month clamp is wrong.
 */
class RecurrenceParityTest {

    private val shapes: Map<String, Recurrence> = mapOf(
        "daily" to Recurrence.Daily,
        "wed-fri" to Recurrence.WEDNESDAY_AND_FRIDAY,
        "weekly-sun" to Recurrence.Weekly(setOf(Weekday.SUNDAY)),
        "weekly-mon-thu-sat" to Recurrence.Weekly(
            setOf(Weekday.MONDAY, Weekday.THURSDAY, Weekday.SATURDAY),
        ),
        "monthly-1" to Recurrence.Monthly(1),
        "monthly-15" to Recurrence.Monthly(15),
        "monthly-29-last" to Recurrence.Monthly(29, ShortMonthPolicy.LAST_DAY),
        "monthly-29-skip" to Recurrence.Monthly(29, ShortMonthPolicy.SKIP),
        "monthly-30-last" to Recurrence.Monthly(30, ShortMonthPolicy.LAST_DAY),
        "monthly-31-last" to Recurrence.Monthly(31, ShortMonthPolicy.LAST_DAY),
        "monthly-31-skip" to Recurrence.Monthly(31, ShortMonthPolicy.SKIP),
        "once" to Recurrence.Once(CalendarDate.of(2027, 2, 28)!!),
    )

    private fun expected(): Map<String, List<String>> {
        val text = javaClass.getResourceAsStream("/recurrence-parity.tsv")
            ?.bufferedReader()?.readText()
        assertNotNull(text, "the recurrence parity fixture is missing")
        return text.trim().lines().associate { line ->
            val (label, dates) = line.split('\t')
            label to if (dates.isEmpty()) emptyList() else dates.split(',')
        }
    }

    @Test
    fun `every pattern in the fixture is one this test knows about`() {
        val fixture = expected()
        assertEquals(
            shapes.keys, fixture.keys,
            "the fixture and this test have drifted apart; regenerate or update both",
        )
        assertTrue(fixture.values.sumOf { it.size } > 2_000)
    }

    @Test
    fun `every pattern expands exactly as the Swift engine expands it`() {
        val engine = RecurrenceEngine()
        val from = CalendarDate.of(2026, 1, 1)!!
        val through = CalendarDate.of(2028, 12, 31)!!

        for ((label, recurrence) in shapes) {
            val want = expected()[label]
            assertNotNull(want, "no fixture row for $label")
            val got = engine.patternDates(recurrence, from, through).map { it.iso }
            assertEquals(want, got, "pattern $label differs from the specification")
        }
    }
}
