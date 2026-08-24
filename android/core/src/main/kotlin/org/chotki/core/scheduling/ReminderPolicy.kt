package org.chotki.core.scheduling

import kotlinx.serialization.Serializable
import org.chotki.core.CalendarDate
import org.chotki.core.NotificationRequest
import java.time.Instant
import java.util.UUID

/** How reminders for an untimed rule are distributed through the day. */
@Serializable
enum class UntimedSpacing {
    /**
     * One every `untimedInterval`, starting at the first waking hour. With the
     * default cap this clusters them in the morning: 07:00, 08:00, 09:00, 10:00,
     * then silence for the rest of the day.
     */
    HOURLY,

    /**
     * The same number of reminders, spread evenly across the waking hours —
     * 07:00, 11:00, 16:00, 21:00 with the defaults. Fewer nudges in a row, and
     * the rule is still in front of you in the evening.
     */
    SPREAD_ACROSS_DAY,
}

/**
 * When reminders fire, and how often.
 *
 * [notificationsEnabled] is the master switch. Turning it off stops every
 * reminder and changes nothing else — rules stay due, and the score is
 * untouched. Silence is not the same as standing down.
 *
 * Tunable rather than hard-coded, because the right cadence is personal and
 * because a policy that cannot be softened is a policy that nags.
 */
@Serializable
data class ReminderPolicy(
    /** Master switch. Off means no reminder of any kind fires. */
    val notificationsEnabled: Boolean = true,
    /** Default warning for rules that do not set their own. */
    val defaultLead: ReminderLead = ReminderLead.TEN_MINUTES,
    /** Gap between reminders for a rule with no clock time, in seconds. */
    val untimedIntervalSeconds: Long = 60 * 60,
    /** Most reminders in a day for one untimed rule. Zero means uncapped. */
    val untimedCap: Int = 4,
    val spacing: UntimedSpacing = UntimedSpacing.SPREAD_ACROSS_DAY,
    val quietHours: QuietHours = QuietHours.DEFAULT,
) {
    companion object {
        val DEFAULT = ReminderPolicy()

        /** One reminder in the morning and nothing further. */
        val GENTLE = ReminderPolicy(untimedCap = 1)

        /** The literal original shape: hourly from the first waking hour. */
        val HOURLY = ReminderPolicy(spacing = UntimedSpacing.HOURLY)

        /** Everything silent. Rules remain due and scored exactly as before. */
        val SILENT = ReminderPolicy(notificationsEnabled = false)
    }
}

/** A reminder the scheduler has decided should fire. */
data class PlannedNotification(
    /**
     * Stable and derived, so every reminder for one occurrence can be cancelled
     * together the moment it is marked complete.
     */
    val id: String,
    val ruleID: UUID,
    val date: CalendarDate,
    val fireAt: Instant,
    val request: NotificationRequest,
) {
    companion object {
        /** Every reminder for a rule on a day shares this prefix. */
        fun occurrenceKey(ruleID: UUID, date: CalendarDate): String = "$ruleID:${date.iso}"
    }
}
