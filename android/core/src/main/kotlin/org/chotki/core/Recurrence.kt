package org.chotki.core

import kotlinx.serialization.Serializable

/** What to do when a monthly rule names a day the month does not have. */
@Serializable
enum class ShortMonthPolicy {
    /**
     * 31st becomes the 30th, or the 28th/29th in February.
     *
     * The default, because skipping is almost never what someone means. A
     * monthly confession set for the 31st should not silently vanish in
     * February, April, June, September and November — nearly half the year.
     */
    LAST_DAY,

    /**
     * The occurrence simply does not exist that month. For a rule genuinely
     * tied to a date rather than to a monthly rhythm.
     */
    SKIP,
}

@Serializable
enum class FastingSeason { GREAT_LENT, NATIVITY_FAST, APOSTLES_FAST, DORMITION_FAST }

/** Recurrence driven by the church calendar rather than the civil one. */
@Serializable
sealed interface LiturgicalTrigger {
    /** Any day the calendar marks as a fast, whichever reckoning is set. */
    @Serializable
    data object FastDay : LiturgicalTrigger

    @Serializable
    data object GreatFeast : LiturgicalTrigger

    /** Every day within a named fasting season. */
    @Serializable
    data class Season(val season: FastingSeason) : LiturgicalTrigger
}

@Serializable
sealed interface Recurrence {
    /**
     * A single named day. Produced when one occurrence of a repeating rule is
     * edited in isolation, and available directly for a one-off intention.
     */
    @Serializable
    data class Once(val date: CalendarDate) : Recurrence

    @Serializable
    data object Daily : Recurrence

    @Serializable
    data class Weekly(val days: Set<Weekday>) : Recurrence

    @Serializable
    data class Monthly(
        val day: Int,
        val whenShort: ShortMonthPolicy = ShortMonthPolicy.LAST_DAY,
    ) : Recurrence

    @Serializable
    data class Liturgical(val trigger: LiturgicalTrigger) : Recurrence

    companion object {
        /**
         * The Wednesday and Friday fast, which is the most common weekly shape
         * in an Orthodox rule.
         *
         * Note it is a weekly pattern and not `Liturgical(FastDay)`. That
         * mistake put the rule on roughly 180 days a year, because every fast
         * day in the calendar matched it.
         */
        val WEDNESDAY_AND_FRIDAY: Recurrence =
            Weekly(setOf(Weekday.WEDNESDAY, Weekday.FRIDAY))
    }
}

@Serializable
enum class RuleCategory { PRAYER, FASTING, SERVICES, READING, LIFE }
