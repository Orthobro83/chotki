package org.chotki.core

import java.time.Instant
import java.time.ZoneId

/** What is due, what has become of it, and what the record says. */
class Practice(
    private val rules: List<Rule>,
    private val activations: List<Activation>,
    private val occurrences: List<Occurrence>,
    val settings: AppSettings = AppSettings.DEFAULT,
    liturgical: LiturgicalDayProvider = NoLiturgicalData,
) {
    private val engine = RecurrenceEngine(liturgical, settings.observances)

    // MARK: what is on a day

    /**
     * The rules that fall on a day, in the order they are shown: timed first, by
     * hour; then those that run all day.
     *
     * A rule the Church has lifted is included rather than omitted — with the
     * reason — because a rule that simply vanished would look like a fault and
     * teach nothing.
     */
    fun entries(on: CalendarDate): List<DayEntry> {
        val byRule = occurrences.filter { it.date == on }.associateBy { it.ruleID }

        return rules.mapNotNull { rule ->
            val due = engine.dueDates(rule, activations, on, on)
            if (due.isNotEmpty()) {
                DayEntry(rule, on, byRule[rule.id], dispensation = null)
            } else {
                engine.dispensations(rule, activations, on, on).firstOrNull()?.let { (_, reason) ->
                    DayEntry(rule, on, occurrence = null, dispensation = reason)
                }
            }
        }.sortedWith { a, b ->
            // Timed first and in order; untimed after, among themselves by
            // title. Two rules at the same time keep the order they came in,
            // as the Swift original leaves them.
            val x = a.rule.timeOfDay
            val y = b.rule.timeOfDay
            when {
                x != null && y != null -> x.compareTo(y)
                x == null && y != null -> 1
                x != null && y == null -> -1
                else -> a.rule.title.compareTo(b.rule.title)
            }
        }
    }

    /**
     * Every rule for the day accounted for, with at least one actually kept.
     *
     * A rule stood down counts as settled: standing down is a legitimate act,
     * and treating it as unfinished would quietly punish pausing. Standing
     * everything down settles nothing, because nothing was kept.
     */
    fun isSettled(on: CalendarDate): Boolean {
        val items = entries(on)
        if (items.isEmpty()) return false
        if (items.none { it.isKept }) return false
        return items.all { it.showsAsSatisfied || it.isStoodDown }
    }

    fun isPaused(rule: Rule): Boolean =
        activations.none { it.ruleID == rule.id && it.isOpen }

    // MARK: repairs

    /**
     * Observances that must be turned on because a rule depends on them.
     *
     * A rule tied to the church calendar can never come due while its observance
     * is merely shown — it sits on the list and is invisible. That happens to a
     * rule taken on before this was handled, or restored from an older backup,
     * so it is repaired on load rather than only when taken on.
     */
    fun observancesNeeded(): List<LiturgicalTrigger> =
        rules.filterNot { it.isArchived }
            .mapNotNull { rule ->
                val recurrence = rule.recurrence as? Recurrence.Liturgical ?: return@mapNotNull null
                if (activations.none { it.ruleID == rule.id && it.isOpen }) return@mapNotNull null
                if (settings.observances.settingFor(recurrence.trigger).drivesRules) {
                    return@mapNotNull null
                }
                recurrence.trigger
            }

    /**
     * Someone who already has rules has plainly been here before, whatever the
     * stored flag says. Showing them the first-run screen would be absurd.
     */
    val shouldMarkFirstRunComplete: Boolean
        get() = !settings.hasCompletedFirstRun && rules.isNotEmpty()

    // MARK: progress

    fun report(
        days: Int = 30,
        today: CalendarDate,
        zone: ZoneId = ZoneId.systemDefault(),
        now: Instant = Instant.now(),
    ): ProgressReport {
        val through = progressThrough(today)
        return ScoringEngine(engine, zone).report(
            rules = rules,
            activations = activations,
            occurrences = occurrences,
            from = through.plusDays(-(days - 1)),
            through = through,
            now = now,
        )
    }

    companion object {
        /**
         * The last day progress speaks about: yesterday.
         *
         * Today is deliberately outside it. A day still in progress is not a
         * verdict — a rule added this morning and not yet kept would otherwise
         * count against someone before they had the chance.
         */
        fun progressThrough(today: CalendarDate): CalendarDate = today.plusDays(-1)
    }
}
