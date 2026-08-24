package org.chotki.core.scheduling

import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.NotificationAction
import org.chotki.core.NotificationRequest
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.RecurrenceEngine
import org.chotki.core.Rule
import org.chotki.core.TimeOfDay
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Decides what should be reminded, and when.
 *
 * Pure: given rules, activations, occurrences and a day, it returns the
 * reminders for that day. It does not fire anything, does not sleep, and does
 * not know what platform it is on — the notifier only shows what this decides.
 * That is what lets a simulated month run headlessly in CI.
 */
class Scheduler(
    private val engine: RecurrenceEngine = RecurrenceEngine(),
    private val policy: ReminderPolicy = ReminderPolicy.DEFAULT,
    private val zone: ZoneId = ZoneId.systemDefault(),
) {
    private companion object {
        /**
         * Statuses that end a day's reminders. Completing is the obvious one;
         * skipping and cancelling must silence it too, or standing something
         * down would keep buzzing about it.
         */
        val SETTLED = setOf(
            OccurrenceStatus.COMPLETED,
            OccurrenceStatus.COMPLETED_LATE,
            OccurrenceStatus.SKIPPED,
            OccurrenceStatus.CANCELLED,
            OccurrenceStatus.MOVED,
        )
    }

    /** Every reminder for one day, in fire order. */
    fun plan(
        rules: List<Rule>,
        activations: List<Activation>,
        occurrences: List<Occurrence>,
        on: CalendarDate,
    ): List<PlannedNotification> {
        // The master switch silences everything and changes nothing else: rules
        // stay due, and scoring never sees this.
        if (!policy.notificationsEnabled) return emptyList()

        val settledRuleIDs = occurrences
            .filter { it.date == on && it.status in SETTLED }
            .map { it.ruleID }
            .toSet()

        return rules
            .filterNot { it.isArchived || it.id in settledRuleIDs }
            .filter { it.effectiveReminders.enabled }
            .filter { engine.dueDates(it, activations, on, on).isNotEmpty() }
            .flatMap { reminders(it, on) }
            .sortedBy { it.fireAt }
    }

    /** Reminders still ahead of [after] — what a driver would actually arm. */
    fun pending(
        rules: List<Rule>,
        activations: List<Activation>,
        occurrences: List<Occurrence>,
        on: CalendarDate,
        after: Instant,
    ): List<PlannedNotification> =
        plan(rules, activations, occurrences, on).filter { it.fireAt > after }

    /**
     * The ids to cancel when a rule is completed, paused or archived. Callers
     * need not know how many reminders were armed.
     */
    fun cancellationIDs(
        ruleID: UUID,
        date: CalendarDate,
        rules: List<Rule>,
    ): List<String> {
        val rule = rules.firstOrNull { it.id == ruleID } ?: return emptyList()
        return reminders(rule, date).map { it.id }
    }

    // MARK: building reminders

    private fun reminders(rule: Rule, date: CalendarDate): List<PlannedNotification> {
        val time = rule.timeOfDay
        return if (time != null) timedReminders(rule, date, time) else untimedReminders(rule, date)
    }

    /**
     * One reminder per configured lead. More than one is allowed — an hour
     * before to get ready, ten minutes before to actually leave.
     */
    private fun timedReminders(
        rule: Rule,
        date: CalendarDate,
        time: TimeOfDay,
    ): List<PlannedNotification> {
        // A wall-clock time the day does not have — 02:30 on a spring-forward
        // morning — yields no instant, so no reminder rather than a wrong one.
        val dueAt = date.dueInstant(time, zone) ?: return emptyList()

        val configured = rule.effectiveReminders.leads
        val leads = configured.ifEmpty { listOf(policy.defaultLead) }
        val key = PlannedNotification.occurrenceKey(rule.id, date)

        return leads.sortedWith(ReminderLead.BY_LEAD).mapNotNull { lead ->
            val fireAt = if (lead == ReminderLead.THE_EVENING_BEFORE) {
                // A fixed, predictable hour the evening before, so something you
                // travel to can be prepared for the night before.
                date.plusDays(-1).dueInstant(TimeOfDay.of(20, 0)!!, zone) ?: return@mapNotNull null
            } else {
                dueAt.minusSeconds(lead.seconds)
            }

            // Quiet hours deliberately do NOT apply to a rule the user gave a
            // time to. They exist to stop unsolicited repetition, not to silence
            // a reminder that was asked for: with the default window ending
            // 06:30, a 06:30 rule warns at 06:20 and must still arrive.
            val id = "$key:lead${lead.minutes}"
            PlannedNotification(
                id = id,
                ruleID = rule.id,
                date = date,
                fireAt = fireAt,
                request = NotificationRequest(
                    id = id,
                    title = rule.title,
                    // Neutral by construction: what is due and when, never how
                    // long it has been outstanding.
                    body = body(lead, time),
                    actions = listOf(NotificationAction.MARK_COMPLETE, NotificationAction.SNOOZE),
                ),
            )
        }
    }

    private fun body(lead: ReminderLead, time: TimeOfDay): String {
        val at = "%02d:%02d".format(time.hour, time.minute)
        return if (lead == ReminderLead.THE_EVENING_BEFORE) "Tomorrow at $at" else "At $at"
    }

    private fun untimedReminders(rule: Rule, date: CalendarDate): List<PlannedNotification> {
        val cap = if (policy.untimedCap > 0) policy.untimedCap else Int.MAX_VALUE

        // Every slot the quiet window leaves open, in order.
        val stepMinutes = maxOf((policy.untimedIntervalSeconds / 60).toInt(), 1)
        val waking = mutableListOf<TimeOfDay>()
        var minute = 0
        while (minute < 24 * 60) {
            val time = TimeOfDay.of(minute / 60, minute % 60)
            if (time != null && !policy.quietHours.contains(time)) waking.add(time)
            minute += stepMinutes
        }
        if (waking.isEmpty()) return emptyList()

        val chosen: List<TimeOfDay> = when (policy.spacing) {
            UntimedSpacing.HOURLY -> waking.take(cap)
            UntimedSpacing.SPREAD_ACROSS_DAY -> {
                val wanted = min(cap, waking.size)
                if (wanted <= 1) {
                    waking.take(wanted)
                } else {
                    // Evenly spaced across the waking window, first and last
                    // included.
                    val stride = (waking.size - 1).toDouble() / (wanted - 1).toDouble()
                    (0 until wanted).map { waking[(it * stride).roundToInt()] }
                }
            }
        }

        val result = mutableListOf<PlannedNotification>()
        for (time in chosen) {
            val fireAt = date.dueInstant(time, zone) ?: continue
            val id = "${PlannedNotification.occurrenceKey(rule.id, date)}:${result.size}"
            result.add(
                PlannedNotification(
                    id = id,
                    ruleID = rule.id,
                    date = date,
                    fireAt = fireAt,
                    request = NotificationRequest(
                        id = id,
                        title = rule.title,
                        body = "Today",
                        actions = listOf(
                            NotificationAction.MARK_COMPLETE, NotificationAction.SNOOZE,
                        ),
                    ),
                ),
            )
        }
        return result
    }
}
