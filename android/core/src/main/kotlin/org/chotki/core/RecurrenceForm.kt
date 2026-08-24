package org.chotki.core

/**
 * The editor's view of a recurrence, and the way back.
 *
 * Extracted from the view so the round trip can be tested. It had three silent
 * data-loss bugs: a one-off day became a daily rule, a Great Lent rule became a
 * general fast-day rule, and a monthly rule's short-month policy reset. Each
 * happened because the form could not express the shape it had loaded, so saving
 * replaced it with something else — without saying so.
 */
data class RecurrenceForm(
    val kind: Kind = Kind.DAILY,
    val weekdays: Set<Weekday> = setOf(Weekday.SUNDAY),
    val monthDay: Int = 1,
    /** No control for this; carried through so an edit cannot change it. */
    val shortMonthPolicy: ShortMonthPolicy = ShortMonthPolicy.LAST_DAY,
    val season: FastingSeason = FastingSeason.GREAT_LENT,
    val onceDate: CalendarDate? = null,
) {
    enum class Kind(val label: String) {
        ONCE("Just one day"),
        DAILY("Every day"),
        WEEKLY("Certain weekdays"),
        MONTHLY("Once a month"),
        FAST_DAYS("Fast days"),
        SEASON("Through a fasting season"),
        GREAT_FEASTS("Great feasts"),
    }

    companion object {
        fun of(recurrence: Recurrence): RecurrenceForm = when (recurrence) {
            is Recurrence.Once -> RecurrenceForm(kind = Kind.ONCE, onceDate = recurrence.date)
            Recurrence.Daily -> RecurrenceForm(kind = Kind.DAILY)
            is Recurrence.Weekly -> RecurrenceForm(kind = Kind.WEEKLY, weekdays = recurrence.days)
            is Recurrence.Monthly -> RecurrenceForm(
                kind = Kind.MONTHLY,
                monthDay = recurrence.day,
                shortMonthPolicy = recurrence.whenShort,
            )
            is Recurrence.Liturgical -> when (val trigger = recurrence.trigger) {
                LiturgicalTrigger.FastDay -> RecurrenceForm(kind = Kind.FAST_DAYS)
                LiturgicalTrigger.GreatFeast -> RecurrenceForm(kind = Kind.GREAT_FEASTS)
                is LiturgicalTrigger.Season ->
                    RecurrenceForm(kind = Kind.SEASON, season = trigger.season)
            }
        }
    }

    /**
     * [fallback] is used only when a one-off rule somehow has no day, so that it
     * stays a single day rather than quietly becoming a daily rule.
     */
    fun recurrence(fallback: CalendarDate): Recurrence = when (kind) {
        Kind.ONCE -> Recurrence.Once(onceDate ?: fallback)
        Kind.DAILY -> Recurrence.Daily
        Kind.WEEKLY -> Recurrence.Weekly(weekdays.ifEmpty { setOf(Weekday.SUNDAY) })
        Kind.MONTHLY -> Recurrence.Monthly(monthDay, shortMonthPolicy)
        Kind.FAST_DAYS -> Recurrence.Liturgical(LiturgicalTrigger.FastDay)
        Kind.SEASON -> Recurrence.Liturgical(LiturgicalTrigger.Season(season))
        Kind.GREAT_FEASTS -> Recurrence.Liturgical(LiturgicalTrigger.GreatFeast)
    }
}
