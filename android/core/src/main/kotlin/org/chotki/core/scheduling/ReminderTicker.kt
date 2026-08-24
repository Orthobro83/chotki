package org.chotki.core.scheduling

import org.chotki.core.CalendarDate
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

/**
 * Decides, on each tick, what should be shown and what should be taken back.
 *
 * Separated from the timer that drives it and the notifier that obeys it, so the
 * parts that are easy to get wrong — not repeating a reminder, not firing a
 * burst of stale ones, crossing midnight, withdrawing something that is no
 * longer due — are plain arithmetic that any platform can reuse and any test can
 * drive with an injected clock.
 */
class ReminderTicker(
    /**
     * How late a reminder may be and still be worth showing. Without this,
     * launching in the afternoon — or a rule becoming due mid-day, which is what
     * happens when an observance is turned on — fires every earlier reminder for
     * that day at once.
     */
    private val staleAfterSeconds: Long = 15 * 60,
) {
    data class Decision(
        val show: List<PlannedNotification> = emptyList(),
        val withdraw: List<String> = emptyList(),
    ) {
        val isEmpty: Boolean get() = show.isEmpty() && withdraw.isEmpty()
    }

    /** Already delivered, so a tick never repeats one. */
    private val fired = mutableSetOf<String>()

    /** Occurrence keys held back, and until when. */
    private val snoozedUntil = mutableMapOf<String, Instant>()
    private var lastDay: CalendarDate? = null

    fun snooze(ruleID: UUID, date: CalendarDate, until: Instant) {
        snoozedUntil[PlannedNotification.occurrenceKey(ruleID, date)] = until
    }

    fun tick(
        planned: List<PlannedNotification>,
        now: Instant,
        zone: ZoneId = ZoneId.systemDefault(),
    ): Decision {
        val today = CalendarDate.from(now, zone)

        // A new day starts clean, and yesterday's silences lapse. This runs once
        // a day, which in practice means it never runs while anyone is watching.
        //
        // Note the null check: the very first tick must not count as a change of
        // day, or anything set before it — a snooze, say — is wiped before it has
        // any effect.
        val previous = lastDay
        if (previous != null && previous != today) {
            fired.clear()
            snoozedUntil.clear()
        }
        lastDay = today

        // Anything no longer planned — kept, paused, silenced or deleted — is
        // taken back rather than left standing.
        val live = planned.map { it.id }.toSet()
        val stale = fired - live
        val withdraw = stale.sorted()
        fired -= stale

        val show = mutableListOf<PlannedNotification>()
        for (notification in planned) {
            if (notification.id in fired) continue
            if (notification.fireAt > now) continue

            if (now.epochSecond - notification.fireAt.epochSecond > staleAfterSeconds) {
                // Its moment has passed. Mark it handled and stay quiet.
                fired.add(notification.id)
                continue
            }

            val key = PlannedNotification.occurrenceKey(notification.ruleID, notification.date)
            val until = snoozedUntil[key]
            if (until != null && until > now) continue

            fired.add(notification.id)
            show.add(notification)
        }

        return Decision(show = show, withdraw = withdraw)
    }
}
