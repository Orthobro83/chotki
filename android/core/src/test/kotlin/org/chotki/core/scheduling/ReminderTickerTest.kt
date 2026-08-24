package org.chotki.core.scheduling

import org.chotki.core.CalendarDate
import org.chotki.core.NotificationRequest
import org.chotki.core.TimeOfDay
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private val zone: ZoneId = ZoneId.of("Europe/London")

private fun day(y: Int, m: Int, d: Int): CalendarDate = CalendarDate.of(y, m, d)!!

private fun instant(date: CalendarDate, hour: Int): Instant =
    date.dueInstant(TimeOfDay.of(hour, 0)!!, zone)!!

private fun reminder(date: CalendarDate, hour: Int, id: String) = PlannedNotification(
    id = id,
    ruleID = UUID.randomUUID(),
    date = date,
    fireAt = instant(date, hour),
    request = NotificationRequest(id = id, title = "Evening prayers", body = "At $hour:00"),
)

/**
 * The decisions behind reminders, driven directly. These used to be reachable
 * only through the macOS driver, which meant they were tested on one platform
 * and would have to be rewritten — and re-debugged — for any other.
 *
 * Translated from suite "Reminder decisions".
 */
class ReminderTickerTest {

    private val today = day(2026, 8, 20)

    @Test
    fun `a reminder is shown once, however often the clock ticks`() {
        val ticker = ReminderTicker()
        val planned = listOf(reminder(today, 9, "a"))

        assertEquals(1, ticker.tick(planned, instant(today, 9), zone).show.size)
        assertTrue(ticker.tick(planned, instant(today, 9), zone).show.isEmpty())
        assertTrue(ticker.tick(planned, instant(today, 9), zone).show.isEmpty())
    }

    @Test
    fun `nothing fires before its moment`() {
        val ticker = ReminderTicker()
        assertTrue(
            ticker.tick(listOf(reminder(today, 21, "evening")), instant(today, 9), zone).isEmpty,
        )
    }

    // The fix that prompted this: turning an observance on mid-afternoon made
    // several earlier reminders due at once.
    @Test
    fun `reminders long past their moment stay quiet`() {
        val ticker = ReminderTicker()
        val decision = ticker.tick(
            listOf(
                reminder(today, 7, "morning"),
                reminder(today, 12, "noon"),
                reminder(today, 16, "now"),
            ),
            instant(today, 16),
            zone,
        )
        assertEquals(listOf("now"), decision.show.map { it.id })
    }

    @Test
    fun `a stale reminder is not shown later either`() {
        val ticker = ReminderTicker()
        val planned = listOf(reminder(today, 7, "morning"))
        ticker.tick(planned, instant(today, 16), zone)
        assertTrue(ticker.tick(planned, instant(today, 16), zone).isEmpty)
    }

    // Runs once a day, which means in practice it never runs while anyone is
    // watching. A mistake costs a whole day of silence, or of repeats.
    @Test
    fun `crossing midnight lets the next day remind again`() {
        val ticker = ReminderTicker()
        val tomorrow = today.plusDays(1)

        val first = ticker.tick(
            listOf(reminder(today, 9, "rule:${today.iso}")), instant(today, 9), zone,
        )
        assertEquals(1, first.show.size)

        val second = ticker.tick(
            listOf(reminder(tomorrow, 9, "rule:${tomorrow.iso}")), instant(tomorrow, 9), zone,
        )
        assertEquals(listOf("rule:${tomorrow.iso}"), second.show.map { it.id })
    }

    @Test
    fun `a reminder that leaves the plan is taken back`() {
        val ticker = ReminderTicker()
        val planned = listOf(reminder(today, 9, "a"))
        ticker.tick(planned, instant(today, 9), zone)

        val after = ticker.tick(emptyList(), instant(today, 9), zone)
        assertEquals(listOf("a"), after.withdraw)
        assertTrue(after.show.isEmpty())
    }

    @Test
    fun `something never shown is not withdrawn`() {
        assertTrue(ReminderTicker().tick(emptyList(), instant(today, 9), zone).isEmpty)
    }

    @Test
    fun `a snoozed occurrence stays quiet until its hour`() {
        val ticker = ReminderTicker()
        val one = reminder(today, 9, "a")
        ticker.snooze(one.ruleID, one.date, instant(today, 11))

        assertTrue(ticker.tick(listOf(one), instant(today, 9), zone).isEmpty)

        val later = one.copy(id = "b", fireAt = instant(today, 12))
        assertEquals(1, ticker.tick(listOf(later), instant(today, 12), zone).show.size)
    }

    // The first tick must not count as a change of day, or a snooze set before
    // it is wiped before it has any effect.
    @Test
    fun `the very first tick does not wipe what was set before it`() {
        val ticker = ReminderTicker()
        val one = reminder(today, 9, "a")
        ticker.snooze(one.ruleID, one.date, instant(today, 11))
        assertTrue(
            ticker.tick(listOf(one), instant(today, 9), zone).isEmpty,
            "the snooze was cleared by the first tick",
        )
    }
}
