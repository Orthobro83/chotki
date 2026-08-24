package org.chotki.core

/**
 * Expands rules into the days they fall on.
 *
 * Pure, deterministic, and entirely free of storage and platform. Everything the
 * scoring and scheduling layers rely on is decided here, which is why this is
 * the most heavily tested type in the project.
 */
class RecurrenceEngine(
    private val liturgical: LiturgicalDayProvider = NoLiturgicalData,
    private val observances: ObservanceSettings = ObservanceSettings.DEFAULT,
) {

    /** Days the recurrence pattern alone would produce, ignoring activations. */
    fun patternDates(
        recurrence: Recurrence,
        from: CalendarDate,
        through: CalendarDate,
    ): List<CalendarDate> {
        if (from > through) return emptyList()
        val result = mutableListOf<CalendarDate>()
        var day = from
        while (day <= through) {
            if (matches(recurrence, day)) result.add(day)
            day = day.plusDays(1)
        }
        return result
    }

    /**
     * The days a rule is actually due: the pattern, intersected with the
     * stretches during which the rule was in force.
     *
     * This intersection is the whole mechanism. A rule enabled in March produces
     * nothing in February; a rule paused in May produces nothing that month;
     * neither leaves a gap that scoring could read as a failure.
     */
    fun dueDates(
        rule: Rule,
        activations: List<Activation>,
        from: CalendarDate,
        through: CalendarDate,
    ): List<CalendarDate> =
        inForce(rule, activations, from, through).filter { dispensation(rule, it) == null }

    /**
     * Days the rule would fall on, but which the Church has lifted — with the
     * reason. These are deliberately **not** due: they cannot be missed and they
     * raise no reminder. They are returned separately so the day can still be
     * shown, kept, with an explanation, rather than silently vanishing from the
     * list as though the rule had broken.
     */
    fun dispensations(
        rule: Rule,
        activations: List<Activation>,
        from: CalendarDate,
        through: CalendarDate,
    ): List<Pair<CalendarDate, String>> =
        inForce(rule, activations, from, through).mapNotNull { date ->
            dispensation(rule, date)?.let { date to it }
        }

    private fun inForce(
        rule: Rule,
        activations: List<Activation>,
        from: CalendarDate,
        through: CalendarDate,
    ): List<CalendarDate> {
        val mine = activations.filter { it.ruleID == rule.id }
        if (mine.isEmpty()) return emptyList()
        return patternDates(rule.recurrence, from, through)
            .filter { date -> mine.any { it.covers(date) } }
    }

    private fun dispensation(rule: Rule, date: CalendarDate): String? {
        if (!rule.isFastingRule) return null
        return liturgical.fastFreeReason(date)
    }

    private fun matches(recurrence: Recurrence, date: CalendarDate): Boolean =
        when (recurrence) {
            is Recurrence.Once -> date == recurrence.date

            Recurrence.Daily -> true

            is Recurrence.Weekly -> recurrence.days.contains(date.weekday)

            is Recurrence.Monthly ->
                if (recurrence.day <= date.lastDayOfMonth) {
                    date.day == recurrence.day
                } else {
                    // The named day does not exist this month.
                    when (recurrence.whenShort) {
                        ShortMonthPolicy.LAST_DAY -> date.day == date.lastDayOfMonth
                        ShortMonthPolicy.SKIP -> false
                    }
                }

            is Recurrence.Liturgical -> {
                // An observance that is merely shown, or hidden, never produces
                // a due day — so it can never be missed, and can never be
                // scored. Standing one down is therefore identical to pausing:
                // the days leave the record rather than counting against anyone.
                if (!observances.settingFor(recurrence.trigger).drivesRules) {
                    false
                } else {
                    when (val trigger = recurrence.trigger) {
                        LiturgicalTrigger.FastDay -> liturgical.isFastDay(date)
                        LiturgicalTrigger.GreatFeast -> liturgical.isGreatFeast(date)
                        is LiturgicalTrigger.Season -> liturgical.season(date) == trigger.season
                    }
                }
            }
        }
}
