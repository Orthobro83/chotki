package org.chotki.core

import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import kotlin.math.max
import kotlin.math.pow

/** What became of one rule over a window. */
data class RuleScore(
    val ruleID: UUID,
    val title: String,
    val kept: Int,
    val keptLate: Int,
    val missed: Int,
    /** Deliberately excluded from the ratio, on both sides. */
    val stoodDown: Int,
    /**
     * Consecutive due days most recently kept. Days stood down are stepped over
     * rather than breaking it.
     */
    val streak: Int,
    /** Weighted toward the recent, in 0..1. Null when nothing has come due yet. */
    val ratio: Double?,
    /**
     * Kept so the summary can notice a pattern — the same weekday recurring,
     * say — which is more useful to a person than the count alone.
     */
    val missedDates: List<CalendarDate>,
) {
    val scoreable: Int get() = kept + keptLate + missed
    val hasAnythingDue: Boolean get() = scoreable > 0
}

data class ProgressReport(
    val from: CalendarDate,
    val through: CalendarDate,
    /** Null when nothing has come due yet — no figure is better than a zero. */
    val overall: Double?,
    val perRule: List<RuleScore>,
    /** Leads the report. The figure is secondary and can be hidden entirely. */
    val summary: List<String>,
) {
    val hasAnythingDue: Boolean get() = perRule.any { it.hasAnythingDue }
}

/**
 * Works out what was kept, and says so in words.
 *
 * Three rules govern everything here, and they are enforced by tests: only
 * elapsed days inside an activation are counted; standing something down removes
 * it from both sides of the ratio rather than counting against anyone; and
 * nothing is ever phrased as a failure or compared against a better past.
 */
class ScoringEngine(
    private val engine: RecurrenceEngine = RecurrenceEngine(),
    private val zone: ZoneId = ZoneId.systemDefault(),
    /** Days inside this window carry full weight. */
    private val fullWeightDays: Int = 30,
    /**
     * Beyond the window, weight halves every this many days. Never reaches zero:
     * what someone kept months ago still happened.
     */
    private val halfLifeDays: Double = 60.0,
) {
    private companion object {
        /**
         * Completing after the day is out earns partial credit rather than
         * nothing. It was still done.
         */
        const val LATE_CREDIT = 0.5
    }

    fun report(
        rules: List<Rule>,
        activations: List<Activation>,
        occurrences: List<Occurrence>,
        from: CalendarDate,
        through: CalendarDate,
        now: Instant = Instant.now(),
    ): ProgressReport {
        val today = CalendarDate.from(now, zone)
        val scores = rules.map { rule ->
            score(rule, activations, occurrences, from, through, now, today)
        }

        val scoreable = scores.filter { it.hasAnythingDue }
        val overall = if (scoreable.isEmpty()) {
            null
        } else {
            scoreable.mapNotNull { it.ratio }.sum() / scoreable.size
        }

        return ProgressReport(
            from = from,
            through = through,
            overall = overall,
            perRule = scores.sortedBy { it.title },
            summary = Prose.summary(scores),
        )
    }

    private fun score(
        rule: Rule,
        activations: List<Activation>,
        occurrences: List<Occurrence>,
        from: CalendarDate,
        through: CalendarDate,
        now: Instant,
        today: CalendarDate,
    ): RuleScore {
        val due = engine.dueDates(rule, activations, from, through)
        if (due.isEmpty()) {
            return RuleScore(rule.id, rule.title, 0, 0, 0, 0, 0, null, emptyList())
        }

        val byDate = occurrences.filter { it.ruleID == rule.id }.associateBy { it.date }

        var kept = 0
        var keptLate = 0
        var missed = 0
        var stoodDown = 0
        val missedDates = mutableListOf<CalendarDate>()
        var weighted = 0.0
        var weight = 0.0

        for (date in due) {
            val status = byDate[date]?.status

            // Elapsing decides whether an *absent* record is a miss. It has
            // nothing to do with a day that was actually kept: marking an
            // all-day rule complete this morning is a fact, not a pending
            // judgement, and it must count today rather than tomorrow.
            if (status == null && !hasElapsed(date, rule, now, today)) continue

            when (status) {
                OccurrenceStatus.SKIPPED,
                OccurrenceStatus.CANCELLED,
                OccurrenceStatus.MOVED,
                -> stoodDown += 1 // out of both numerator and denominator

                OccurrenceStatus.COMPLETED -> {
                    kept += 1
                    val w = weightFor(date, today)
                    weighted += w
                    weight += w
                }

                OccurrenceStatus.COMPLETED_LATE -> {
                    keptLate += 1
                    val w = weightFor(date, today)
                    weighted += w * LATE_CREDIT
                    weight += w
                }

                null -> {
                    missed += 1
                    missedDates.add(date)
                    weight += weightFor(date, today)
                }
            }
        }

        return RuleScore(
            ruleID = rule.id,
            title = rule.title,
            kept = kept,
            keptLate = keptLate,
            missed = missed,
            stoodDown = stoodDown,
            streak = streak(due, byDate, rule, now, today),
            ratio = if (weight > 0) weighted / weight else null,
            missedDates = missedDates,
        )
    }

    /**
     * A day counts only once its moment has passed. Anything still ahead is not
     * missed — it simply has not happened.
     */
    private fun hasElapsed(
        date: CalendarDate,
        rule: Rule,
        now: Instant,
        today: CalendarDate,
    ): Boolean {
        val time = rule.timeOfDay ?: return date < today // the whole day is the window
        val due = date.dueInstant(time, zone) ?: return date < today
        return due <= now
    }

    private fun weightFor(date: CalendarDate, today: CalendarDate): Double {
        val age = max(0, date.daysUntil(today))
        if (age <= fullWeightDays) return 1.0
        return 0.5.pow((age - fullWeightDays) / halfLifeDays)
    }

    /**
     * Consecutive due days kept, counting back from the most recent.
     *
     * Days stood down are stepped over rather than ending it: pausing is a
     * legitimate act and must not read as a break.
     */
    private fun streak(
        due: List<CalendarDate>,
        byDate: Map<CalendarDate, Occurrence>,
        rule: Rule,
        now: Instant,
        today: CalendarDate,
    ): Int {
        var count = 0
        for (date in due.sortedDescending()) {
            // A day still ahead cannot end a streak.
            if (byDate[date] == null && !hasElapsed(date, rule, now, today)) continue
            when (byDate[date]?.status) {
                OccurrenceStatus.COMPLETED, OccurrenceStatus.COMPLETED_LATE -> count += 1
                OccurrenceStatus.SKIPPED, OccurrenceStatus.CANCELLED, OccurrenceStatus.MOVED -> {}
                null -> return count
            }
        }
        return count
    }
}
