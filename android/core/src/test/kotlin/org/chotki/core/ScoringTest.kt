package org.chotki.core

import java.time.Instant
import java.time.ZoneId
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int): CalendarDate =
    CalendarDate.of(y, m, day) ?: error("$y-$m-$day is not a date")

private val zone: ZoneId = ZoneId.of("Europe/London")

/**
 * 20 August 2026, mid-morning — so the 19th and everything before it has
 * elapsed, and today's evening rules have not.
 */
private val now: Instant = d(2026, 8, 20).dueInstant(TimeOfDay.of(10, 0)!!, zone)!!

private fun engine() = ScoringEngine(zone = zone)

private fun dailyRule(title: String, at: TimeOfDay? = null): Pair<Rule, Activation> {
    val rule = Rule(title = title, recurrence = Recurrence.Daily, timeOfDay = at)
    return rule to Activation(ruleID = rule.id, from = d(2026, 8, 1))
}

/** Translated from suite "Scoring". */
class ScoringTest {

    @Test
    fun `a day still ahead is not counted as missed`() {
        val (rule, activation) = dailyRule("Evening prayers", TimeOfDay.of(21, 30))
        val report = engine().report(
            listOf(rule), listOf(activation), emptyList(),
            d(2026, 8, 1), d(2026, 8, 31), now,
        )
        val score = report.perRule[0]
        // 1-19 August elapsed; the 20th at 21:30 has not, nor has anything after.
        assertEquals(19, score.missed)
        assertEquals(19, score.scoreable)
    }

    @Test
    fun `an untimed rule counts only once its day is out`() {
        val (rule, activation) = dailyRule("Jesus prayer")
        val report = engine().report(
            listOf(rule), listOf(activation), emptyList(),
            d(2026, 8, 1), d(2026, 8, 31), now,
        )
        assertEquals(19, report.perRule[0].missed, "today is still open")
    }

    @Test
    fun `nothing due yet gives no figure rather than zero`() {
        val rule = Rule(title = "Sunday Liturgy", recurrence = Recurrence.Weekly(setOf(Weekday.SUNDAY)))
        val activation = Activation(ruleID = rule.id, from = d(2026, 8, 20))
        val report = engine().report(
            listOf(rule), listOf(activation), emptyList(),
            d(2026, 8, 1), d(2026, 8, 31), now,
        )
        assertNull(report.overall, "a zero would be a lie, not a score")
        assertTrue(!report.hasAnythingDue)
    }

    // The binding property from design.md: standing something down leaves the
    // score untouched rather than counting against anyone.
    @Test
    fun `standing a day down moves the score not at all`() {
        val (rule, activation) = dailyRule("Evening prayers")
        val allKept = (1..19).map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }
        val withStandDown = allKept.toMutableList().also {
            it[9] = Occurrence(
                ruleID = rule.id, date = d(2026, 8, 10), status = OccurrenceStatus.SKIPPED,
            )
        }

        val full = engine().report(
            listOf(rule), listOf(activation), allKept, d(2026, 8, 1), d(2026, 8, 31), now,
        )
        val paused = engine().report(
            listOf(rule), listOf(activation), withStandDown, d(2026, 8, 1), d(2026, 8, 31), now,
        )
        assertEquals(1.0, full.overall)
        assertEquals(1.0, paused.overall, "the day left the record entirely")
        assertEquals(1, paused.perRule[0].stoodDown)
        assertEquals(18, paused.perRule[0].scoreable)
    }

    @Test
    fun `keeping something late earns partial credit, not nothing`() {
        val (rule, activation) = dailyRule("Evening prayers")
        val late = (1..19).map {
            Occurrence(
                ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED_LATE,
            )
        }
        val report = engine().report(
            listOf(rule), listOf(activation), late, d(2026, 8, 1), d(2026, 8, 31), now,
        )
        val ratio = report.overall
        assertNotNull(ratio)
        assertTrue(ratio > 0.4 && ratio < 0.6, "half credit, not zero")
        assertEquals(19, report.perRule[0].keptLate)
    }

    @Test
    fun `a rule taken on today reports no prior misses`() {
        val rule = Rule(title = "Morning prayers", recurrence = Recurrence.Daily)
        val activation = Activation(ruleID = rule.id, from = d(2026, 8, 19))
        val report = engine().report(
            listOf(rule), listOf(activation), emptyList(),
            d(2026, 1, 1), d(2026, 8, 31), now,
        )
        assertEquals(1, report.perRule[0].missed, "only the 19th, which has elapsed")
    }

    @Test
    fun `recent days weigh more than old ones`() {
        val (rule, _) = dailyRule("Evening prayers")

        // Kept everything except one day, either long ago or yesterday.
        fun report(missing: CalendarDate): Double {
            val kept = (1..19).map { d(2026, 8, it) }.filter { it != missing }
                .map { Occurrence(ruleID = rule.id, date = it, status = OccurrenceStatus.COMPLETED) }
            val older = (1..31).map { d(2026, 5, it) }.filter { it != missing }
                .map { Occurrence(ruleID = rule.id, date = it, status = OccurrenceStatus.COMPLETED) }
            return engine().report(
                listOf(rule),
                listOf(Activation(ruleID = rule.id, from = d(2026, 5, 1))),
                kept + older,
                d(2026, 5, 1), d(2026, 8, 31), now,
            ).overall ?: 0.0
        }

        // Both are the same count of misses; only the age differs.
        assertTrue(
            report(d(2026, 8, 19)) < report(d(2026, 5, 2)),
            "a recent slip should weigh more than one months ago",
        )
        assertTrue(report(d(2026, 5, 2)) < 1.0, "but an old one never vanishes")
    }

    @Test
    fun `a streak steps over stood-down days rather than breaking`() {
        val (rule, activation) = dailyRule("Morning prayers")
        val occurrences = (1..19).map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }.toMutableList().also {
            it[16] = Occurrence(
                ruleID = rule.id, date = d(2026, 8, 17), status = OccurrenceStatus.SKIPPED,
            )
        }
        val report = engine().report(
            listOf(rule), listOf(activation), occurrences, d(2026, 8, 1), d(2026, 8, 31), now,
        )
        assertEquals(18, report.perRule[0].streak, "pausing is not a break")
    }
}

/** Translated from suite "The written summary". */
class ProseTest {

    private fun report(
        occurrences: List<Occurrence>,
        rules: List<Rule>,
        activations: List<Activation>,
    ) = engine().report(rules, activations, occurrences, d(2026, 8, 1), d(2026, 8, 31), now)

    @Test
    fun `nothing due yet says so plainly`() {
        val rule = Rule(title = "Sunday Liturgy", recurrence = Recurrence.Weekly(setOf(Weekday.SUNDAY)))
        val summary = report(
            emptyList(), listOf(rule),
            listOf(Activation(ruleID = rule.id, from = d(2026, 8, 25))),
        ).summary
        assertTrue(summary.joinToString("").contains("fills in"))
    }

    @Test
    fun `everything kept is said without gushing`() {
        val (rule, activation) = dailyRule("Morning prayers")
        val kept = (1..19).map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }
        val summary = report(kept, listOf(rule), listOf(activation)).summary
        assertTrue(summary.first().contains("kept"))
        assertTrue(!summary.joinToString("").contains("!"))
    }

    // The example from the design: the pattern is the useful part.
    @Test
    fun `a pattern in the slips is named`() {
        val (rule, activation) = dailyRule("Evening prayers")
        // Miss both Fridays in the elapsed window: 7 and 14 August.
        val kept = (1..19).filter { it != 7 && it != 14 }.map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }
        val summary = report(kept, listOf(rule), listOf(activation)).summary.joinToString(" ")
        assertTrue(summary.contains("twice"))
        assertTrue(summary.contains("Fridays"), "the pattern is what someone can act on")
    }

    @Test
    fun `a pattern is not invented from a single slip`() {
        val (rule, activation) = dailyRule("Evening prayers")
        val kept = (1..19).filter { it != 7 }.map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }
        val summary = report(kept, listOf(rule), listOf(activation)).summary.joinToString(" ")
        assertTrue(summary.contains("once"))
        assertTrue(!summary.contains("Fridays"))
    }

    @Test
    fun `what held is mentioned alongside what slipped`() {
        val (slipping, a1) = dailyRule("Evening prayers")
        val (holding, a2) = dailyRule("Morning prayers")
        val occurrences = (1..19).map {
            Occurrence(ruleID = holding.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        } + (1..19).filter { it != 5 }.map {
            Occurrence(ruleID = slipping.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }
        val summary = report(occurrences, listOf(slipping, holding), listOf(a1, a2))
            .summary.joinToString(" ")
        assertTrue(summary.contains("Evening prayers"))
        assertTrue(summary.lowercase().contains("held"))
    }

    @Test
    fun `standing down is reported neutrally`() {
        val (rule, activation) = dailyRule("Jesus prayer")
        val occurrences = (1..19).map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }.toMutableList().also {
            it[3] = Occurrence(
                ruleID = rule.id, date = d(2026, 8, 4), status = OccurrenceStatus.SKIPPED,
            )
        }
        val summary = report(occurrences, listOf(rule), listOf(activation)).summary.joinToString(" ")
        assertTrue(summary.contains("stood down"))
        assertTrue(summary.contains("not counted"))
    }

    // The Tone constraint, applied to every shape of report this can produce.
    @Test
    fun `no summary ever shames, compares, or declares failure`() {
        val (a, actA) = dailyRule("Evening prayers")
        val (b, actB) = dailyRule("Morning prayers", TimeOfDay.of(6, 30))
        val (c, actC) = dailyRule("Jesus prayer")

        val shapes: List<List<Occurrence>> = listOf(
            emptyList(),
            (1..19).map { Occurrence(ruleID = a.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED) },
            (1..19).map { Occurrence(ruleID = a.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED_LATE) },
            (1..19).map { Occurrence(ruleID = a.id, date = d(2026, 8, it), status = OccurrenceStatus.SKIPPED) },
            (1..10).map { Occurrence(ruleID = b.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED) },
            (1..19).filter { it % 3 == 0 }.map {
                Occurrence(ruleID = c.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
            },
        )

        val forbidden = listOf(
            "fail", "failed", "failure", "missed", "behind", "should have",
            "only", "just", "poor", "bad", "worse", "better than", "down from",
            "target", "goal", "streak broken", "broke", "lost", "!",
        )

        for (shape in shapes) {
            val summary = report(shape, listOf(a, b, c), listOf(actA, actB, actC))
                .summary.joinToString(" ").lowercase()
            assertTrue(summary.isNotEmpty())
            for (word in forbidden) {
                assertTrue(!summary.contains(word), "\"$word\" appeared in: $summary")
            }
        }
    }
}

/**
 * The bug this covers: an all-day rule kept this morning did not appear in the
 * report at all, because the day had not finished. Elapsing decides whether an
 * absent record is a miss; it says nothing about a day that was actually kept.
 *
 * Translated from suite "Today counts".
 */
class TodayCountsTest {

    @Test
    fun `an all-day rule kept today shows up today`() {
        val (rule, activation) = dailyRule("The Wednesday and Friday fast")
        val today = CalendarDate.from(now, zone)
        val kept = listOf(
            Occurrence(ruleID = rule.id, date = today, status = OccurrenceStatus.COMPLETED),
        )
        val report = engine().report(listOf(rule), listOf(activation), kept, today, today, now)
        val score = report.perRule[0]
        assertTrue(score.hasAnythingDue, "it must be in the report the moment it is kept")
        assertEquals(1, score.kept)
        assertEquals(1.0, report.overall)
    }

    @Test
    fun `an all-day rule not yet acted on today is not a miss`() {
        val (rule, activation) = dailyRule("Jesus prayer")
        val today = CalendarDate.from(now, zone)
        val report = engine().report(
            listOf(rule), listOf(activation), emptyList(), today, today, now,
        )
        assertEquals(0, report.perRule[0].missed, "the day is not over")
        assertNull(report.overall, "and there is nothing to score yet")
    }

    @Test
    fun `a timed rule kept before its hour counts straight away`() {
        val (rule, activation) = dailyRule("Evening prayers", TimeOfDay.of(21, 30))
        val today = CalendarDate.from(now, zone)
        // now is 10:00; the rule is due at 21:30 and has been kept already.
        val kept = listOf(
            Occurrence(ruleID = rule.id, date = today, status = OccurrenceStatus.COMPLETED),
        )
        val report = engine().report(listOf(rule), listOf(activation), kept, today, today, now)
        assertEquals(1, report.perRule[0].kept, "done early is still done")
    }

    @Test
    fun `standing today down still removes it from the ratio`() {
        val (rule, activation) = dailyRule("Jesus prayer")
        val today = CalendarDate.from(now, zone)
        val stood = listOf(
            Occurrence(ruleID = rule.id, date = today, status = OccurrenceStatus.SKIPPED),
        )
        val report = engine().report(listOf(rule), listOf(activation), stood, today, today, now)
        assertEquals(1, report.perRule[0].stoodDown)
        assertEquals(0, report.perRule[0].scoreable)
    }

    // A day that has not happened cannot end a streak — otherwise every streak
    // would read as zero from midnight until the rule's hour.
    @Test
    fun `today being still ahead does not end a streak`() {
        val (rule, activation) = dailyRule("Evening prayers", TimeOfDay.of(21, 30))
        val today = CalendarDate.from(now, zone)
        val kept = (1..19).map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }
        val report = engine().report(
            listOf(rule), listOf(activation), kept, d(2026, 8, 1), today, now,
        )
        assertEquals(19, report.perRule[0].streak, "the 20th has not come round yet")
    }

    @Test
    fun `an all-day rule missed yesterday is still a miss`() {
        val (rule, activation) = dailyRule("Jesus prayer")
        val report = engine().report(
            listOf(rule), listOf(activation), emptyList(),
            d(2026, 8, 18), CalendarDate.from(now, zone), now,
        )
        assertEquals(2, report.perRule[0].missed, "the 18th and 19th are over; the 20th is not")
    }
}

/**
 * Changing the calendar must not rewrite what someone kept.
 *
 * A liturgical rule is the only kind whose due days come from outside the app.
 * Switching between the Old and New Calendar moves them thirteen days, and
 * scoring re-derives the past from whatever calendar is current — so a fast kept
 * faithfully read as a fortnight of failures. Measured on the Swift side before
 * it was fixed: fourteen kept and none missed became one kept and thirteen
 * missed, at seven per cent.
 *
 * Translated from suite "Changing the calendar".
 */
class ReckoningChangeTest {

    /** The Dormition Fast as each reckoning places it, thirteen days apart. */
    private class Cal(val julian: Boolean) : LiturgicalDayProvider {
        override fun isFastDay(date: CalendarDate) = season(date) != null
        override fun isGreatFeast(date: CalendarDate) = false
        override fun season(date: CalendarDate): FastingSeason? {
            if (date.month != 8) return null
            val range = if (julian) 14..27 else 1..14
            return if (date.day in range) FastingSeason.DORMITION_FAST else null
        }
        override fun fastFreeReason(date: CalendarDate): String? = null
    }

    private val rule = Rule(
        title = "The Dormition Fast",
        recurrence = Recurrence.Liturgical(LiturgicalTrigger.Season(FastingSeason.DORMITION_FAST)),
        category = RuleCategory.FASTING,
    )

    private fun score(julian: Boolean, changedOn: CalendarDate? = null): RuleScore {
        val kept = (14..27).map {
            Occurrence(ruleID = rule.id, date = d(2026, 8, it), status = OccurrenceStatus.COMPLETED)
        }
        return ScoringEngine(
            engine = RecurrenceEngine(
                Cal(julian), ObservanceSettings(fasting = Observance.OBSERVED),
            ),
            zone = zone,
        ).report(
            rules = listOf(rule),
            activations = listOf(Activation(ruleID = rule.id, from = d(2026, 1, 1))),
            occurrences = kept,
            from = d(2026, 8, 1),
            through = d(2026, 8, 31),
            now = d(2026, 9, 1).dueInstant(TimeOfDay.of(10, 0)!!, zone)!!,
            liturgicalHistoryFrom = changedOn,
        ).perRule[0]
    }

    @Test
    fun `kept in full under the calendar it was kept on`() {
        val before = score(julian = true)
        assertEquals(14, before.kept)
        assertEquals(0, before.missed)
        assertEquals(1.0, before.ratio)
    }

    // The bug, stated as the test that would have caught it.
    @Test
    fun `changing the calendar invents no misses at all`() {
        val after = score(julian = false, changedOn = d(2026, 9, 1))
        assertEquals(0, after.missed, "a fortnight of failures appeared from nowhere")
        assertTrue(after.missedDates.isEmpty())
    }

    @Test
    fun `and what was kept is still kept`() {
        val after = score(julian = false, changedOn = d(2026, 9, 1))
        assertEquals(
            14, after.kept,
            "the record is what happened; the calendar changing does not undo it",
        )
        assertEquals(1.0, after.ratio)
    }

    @Test
    fun `days after the change follow the new calendar`() {
        val after = score(julian = false, changedOn = d(2026, 8, 20))
        assertEquals(6, after.kept, "the 14th to the 19th, the days kept before the change")
        assertEquals(0, after.missed, "and on the new calendar nothing from the 20th is a fast")
    }

    // Only liturgical rules are affected: a civil rule means the same day
    // whatever calendar the fasts are reckoned by.
    @Test
    fun `a civil rule is untouched by any of this`() {
        val civil = Rule(title = "Workout", recurrence = Recurrence.Daily)
        val report = ScoringEngine(zone = zone).report(
            rules = listOf(civil),
            activations = listOf(Activation(ruleID = civil.id, from = d(2026, 8, 1))),
            occurrences = emptyList(),
            from = d(2026, 8, 1),
            through = d(2026, 8, 19),
            now = d(2026, 9, 1).dueInstant(TimeOfDay.of(10, 0)!!, zone)!!,
            liturgicalHistoryFrom = d(2026, 8, 20),
        ).perRule[0]
        assertEquals(19, report.missed, "a daily rule is still daily")
    }

    @Test
    fun `with no change ever recorded, nothing behaves differently`() {
        val a = score(julian = true, changedOn = null)
        val b = score(julian = true, changedOn = d(2026, 1, 1))
        assertEquals(a.kept, b.kept)
        assertEquals(a.missed, b.missed)
    }
}
