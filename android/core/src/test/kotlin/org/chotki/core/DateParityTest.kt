package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Differential test against the Swift core, which is the specification.
 *
 * `date-parity.tsv` was produced by the Swift implementation itself — every 37th
 * day from 1900 to 2100, which crosses every weekday, every month length, both
 * leap rules and the epoch. Each line is `daysSinceEpoch`, the ISO date, and the
 * weekday number as Foundation computed it.
 *
 * This matters because the Kotlin version does not translate the Swift code: it
 * replaces two `Foundation` calls with arithmetic. That is a better design and
 * an opportunity to be subtly wrong, so agreement is checked against the
 * original rather than assumed from a handful of cases.
 *
 * Regenerate the fixture if the Swift core's date handling ever changes.
 */
class DateParityTest {

    private data class Row(val days: Int, val iso: String, val weekday: Int)

    private fun rows(): List<Row> {
        val text = javaClass.getResourceAsStream("/date-parity.tsv")
            ?.bufferedReader()?.readText()
        assertNotNull(text, "the parity fixture is missing")
        return text.trim().lines().map { line ->
            val (days, iso, weekday) = line.split('\t')
            Row(days.toInt(), iso, weekday.toInt())
        }
    }

    @Test
    fun `the fixture is substantial enough to mean something`() {
        val rows = rows()
        assertTrue(rows.size > 1_900, "only ${rows.size} rows")
        assertTrue(rows.any { it.days < 0 }, "no dates before the epoch")
        assertTrue(rows.map { it.weekday }.toSet().size == 7, "not every weekday is covered")
    }

    @Test
    fun `every date agrees with the Swift core`() {
        for (row in rows()) {
            val date = CalendarDate.fromDaysSinceEpoch(row.days)
            assertEquals(row.iso, date.iso, "days ${row.days}")
            assertEquals(row.weekday, date.weekday.number, "weekday for ${row.iso}")
        }
    }

    @Test
    fun `days since the epoch agrees in both directions`() {
        for (row in rows()) {
            val parsed = CalendarDate.parse(row.iso)
            assertNotNull(parsed, "could not parse ${row.iso}")
            assertEquals(row.days, parsed.daysSinceEpoch, "for ${row.iso}")
            // And the round trip closes.
            assertEquals(parsed, CalendarDate.fromDaysSinceEpoch(parsed.daysSinceEpoch))
        }
    }
}
