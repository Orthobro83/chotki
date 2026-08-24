package org.chotki.core.scheduling

import kotlinx.serialization.Serializable

/** How far ahead of a rule's time to give warning. */
@Serializable
enum class ReminderLead(val minutes: Int, val label: String) {
    AT_THE_TIME(0, "At the time"),
    TEN_MINUTES(10, "10 minutes before"),
    THIRTY_MINUTES(30, "30 minutes before"),
    ONE_HOUR(60, "1 hour before"),
    TWO_HOURS(120, "2 hours before"),

    /** Handled separately; not a simple offset. */
    THE_EVENING_BEFORE(-1, "The evening before");

    val seconds: Long get() = if (this == THE_EVENING_BEFORE) 0 else minutes * 60L

    companion object {
        /** Offered in the interface, in the order shown. */
        val CHOICES = listOf(
            AT_THE_TIME, TEN_MINUTES, THIRTY_MINUTES, ONE_HOUR, TWO_HOURS, THE_EVENING_BEFORE,
        )

        /** Fire order, which is not the order they are offered in. */
        val BY_LEAD: Comparator<ReminderLead> = compareBy { it.minutes }
    }
}

/**
 * Per-rule reminder settings.
 *
 * Separate from whether the rule is *kept*: turning reminders off silences a
 * rule without changing whether it is due or how it is scored. Someone who knows
 * their own morning routine should be able to stop the buzzing without the app
 * quietly deciding they have stood the rule down.
 */
@Serializable
data class RuleReminders(
    val enabled: Boolean = true,
    /**
     * More than one is allowed — an hour before to get ready, ten minutes before
     * to actually leave. Empty falls back to the policy default.
     */
    val leads: List<ReminderLead> = listOf(ReminderLead.TEN_MINUTES),
) {
    companion object {
        val DEFAULT = RuleReminders()
        val SILENT = RuleReminders(enabled = false)

        /** Useful for something you travel to. */
        val FOR_SERVICE = RuleReminders(leads = listOf(ReminderLead.ONE_HOUR, ReminderLead.TEN_MINUTES))
    }
}
