package org.chotki.core

import java.time.Instant
import java.util.UUID

data class Rule(
    val id: UUID = UUID.randomUUID(),
    val title: String,
    val note: String? = null,
    /**
     * Where the rule came from, in the person's own words — "my godfather".
     * Free text they edit, so it is a note and never a provenance marker;
     * whether a rule is one's own is decided by name against the library.
     */
    val source: String? = null,
    val recurrence: Recurrence,
    val timeOfDay: TimeOfDay? = null,
    val category: RuleCategory? = null,
    /** The prayers this rule carries, in the order they are said. */
    val prayerIDs: List<String>? = null,
    val createdAt: Instant = Instant.now(),
    /** Set when the rule is removed. Never deleted, so history survives. */
    val archivedAt: Instant? = null,
    /**
     * Set when a rule of one's own is taken out of the library's Custom list.
     * The rule and its history are untouched; it is only no longer offered.
     */
    val hiddenFromLibrary: Boolean? = null,
) {
    val isArchived: Boolean get() = archivedAt != null

    val hasPrayers: Boolean get() = !prayerIDs.isNullOrEmpty()

    /**
     * Fasting rules are subject to the Church's dispensations. Keyed on the
     * category rather than the recurrence, so it holds for a rule written by
     * hand as well as one taken from the library.
     */
    val isFastingRule: Boolean get() = category == RuleCategory.FASTING
}

/**
 * A stretch during which a rule is actually in force.
 *
 * A list of these rather than a boolean is what makes "enable later", "pause
 * without penalty", "resume", and seasonal rules all fall out of one structure.
 * Scoring only ever looks at days covered by an activation.
 */
data class Activation(
    val id: UUID = UUID.randomUUID(),
    val ruleID: UUID,
    val from: CalendarDate,
    /** Null means still in force. */
    val to: CalendarDate? = null,
) {
    val isOpen: Boolean get() = to == null

    /**
     * `from` inclusive, `to` inclusive — a rule paused "as of today" still
     * counts today, which is what a person means when they pause in the
     * evening.
     */
    fun covers(date: CalendarDate): Boolean {
        if (date < from) return false
        val end = to ?: return true
        return date <= end
    }
}

enum class OccurrenceStatus {
    COMPLETED,

    /** Done, but after the day was out. Scores partial rather than zero. */
    COMPLETED_LATE,

    /**
     * Deliberately excluded — a pause, illness, travel, a blessing to stand
     * down. Removed from both sides of the ratio, never counted as missed.
     */
    SKIPPED,

    MOVED,
    CANCELLED,
}

/**
 * Written only when a day deviates from the default.
 *
 * A day with no row and a covering activation is simply due, or once its time
 * has passed, missed. Absence is the default state, not a record — which keeps
 * the table small and means "missed" needs no bookkeeping to come true.
 */
data class Occurrence(
    val id: UUID = UUID.randomUUID(),
    val ruleID: UUID,
    val date: CalendarDate,
    val status: OccurrenceStatus,
    val completedAt: Instant? = null,
    /** Set when status is [OccurrenceStatus.MOVED]. */
    val movedTo: CalendarDate? = null,
)
