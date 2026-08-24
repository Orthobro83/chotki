package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int): CalendarDate =
    CalendarDate.of(y, m, day) ?: error("$y-$m-$day is not a date")

/** Translated from suite "Recurrence patterns". */
class RecurrencePatternTest {
    private val engine = RecurrenceEngine()

    @Test
    fun `daily produces every day in range`() {
        val days = engine.patternDates(Recurrence.Daily, d(2026, 8, 17), d(2026, 8, 23))
        assertEquals(7, days.size)
        assertEquals(d(2026, 8, 17), days.first())
        assertEquals(d(2026, 8, 23), days.last())
    }

    @Test
    fun `the Wednesday and Friday fast lands only on those weekdays`() {
        val days = engine.patternDates(
            Recurrence.WEDNESDAY_AND_FRIDAY, d(2026, 8, 1), d(2026, 8, 31),
        )
        assertTrue(days.all { it.weekday == Weekday.WEDNESDAY || it.weekday == Weekday.FRIDAY })
        assertTrue(days.contains(d(2026, 8, 19)))
        assertTrue(days.contains(d(2026, 8, 21)))
        assertTrue(!days.contains(d(2026, 8, 20)))
    }

    @Test
    fun `once produces exactly its own day`() {
        val days = engine.patternDates(
            Recurrence.Once(d(2026, 8, 19)), d(2026, 8, 1), d(2026, 8, 31),
        )
        assertEquals(listOf(d(2026, 8, 19)), days)
    }

    // The case that quietly loses nearly half the year if got wrong.
    @Test
    fun `monthly on the 31st falls back to the last day of a short month`() {
        val days = engine.patternDates(
            Recurrence.Monthly(31), d(2026, 1, 1), d(2026, 12, 31),
        )
        assertEquals(12, days.size, "every month should produce exactly one occurrence")
        assertTrue(days.contains(d(2026, 1, 31)))
        assertTrue(days.contains(d(2026, 2, 28)), "February clamps to the 28th in a common year")
        assertTrue(days.contains(d(2026, 4, 30)), "April clamps to the 30th")
        assertTrue(days.contains(d(2026, 6, 30)))
        assertTrue(days.contains(d(2026, 9, 30)))
        assertTrue(days.contains(d(2026, 11, 30)))
    }

    @Test
    fun `February clamps to the 29th in a leap year`() {
        val days = engine.patternDates(Recurrence.Monthly(31), d(2028, 2, 1), d(2028, 2, 29))
        assertEquals(listOf(d(2028, 2, 29)), days)
    }

    @Test
    fun `the skip policy omits short months entirely`() {
        val days = engine.patternDates(
            Recurrence.Monthly(31, ShortMonthPolicy.SKIP), d(2026, 1, 1), d(2026, 12, 31),
        )
        assertEquals(7, days.size, "only the seven 31-day months")
        assertTrue(days.none { it.month == 2 })
        assertTrue(days.none { it.month == 4 })
    }

    @Test
    fun `a rule tied to the leap day occurs only in leap years`() {
        val common = engine.patternDates(
            Recurrence.Monthly(29, ShortMonthPolicy.SKIP), d(2026, 2, 1), d(2026, 2, 28),
        )
        assertTrue(common.isEmpty())
        val leap = engine.patternDates(
            Recurrence.Monthly(29, ShortMonthPolicy.SKIP), d(2028, 2, 1), d(2028, 2, 29),
        )
        assertEquals(listOf(d(2028, 2, 29)), leap)
    }

    @Test
    fun `an inverted range produces nothing rather than looping`() {
        assertTrue(
            engine.patternDates(Recurrence.Daily, d(2026, 8, 20), d(2026, 8, 19)).isEmpty(),
        )
    }
}

/**
 * The activation intersection is the mechanism behind "enable later" and "pause
 * without penalty". These are the tests that keep the score honest.
 *
 * Translated from suite "Activation windows".
 */
class ActivationTest {
    private val engine = RecurrenceEngine()

    private fun rule() = Rule(
        title = "Evening prayers",
        recurrence = Recurrence.Daily,
        timeOfDay = TimeOfDay.of(21, 30),
    )

    @Test
    fun `a rule taken on today invents no history behind it`() {
        val r = rule()
        val activations = listOf(Activation(ruleID = r.id, from = d(2026, 8, 19)))
        val due = engine.dueDates(r, activations, d(2026, 1, 1), d(2026, 8, 31))
        assertEquals(d(2026, 8, 19), due.first(), "nothing before the day it was taken on")
        assertTrue(!due.contains(d(2026, 8, 18)))
        assertEquals(13, due.size)
    }

    @Test
    fun `a paused stretch produces nothing due, so it cannot read as missed`() {
        val r = rule()
        val activations = listOf(
            Activation(ruleID = r.id, from = d(2026, 3, 1), to = d(2026, 4, 30)),
            Activation(ruleID = r.id, from = d(2026, 6, 1)),
        )
        val due = engine.dueDates(r, activations, d(2026, 1, 1), d(2026, 6, 30))
        assertTrue(due.contains(d(2026, 4, 30)), "in force up to and including the pause day")
        assertTrue(!due.contains(d(2026, 5, 1)), "the gap is not due")
        assertTrue(!due.contains(d(2026, 5, 31)))
        assertTrue(due.contains(d(2026, 6, 1)), "back in force on resume")
        assertTrue(due.none { it.month == 5 }, "May is entirely absent, not missed")
    }

    @Test
    fun `a rule with no activation at all is never due`() {
        assertTrue(
            engine.dueDates(rule(), emptyList(), d(2026, 1, 1), d(2026, 12, 31)).isEmpty(),
        )
    }

    @Test
    fun `activations belonging to other rules are ignored`() {
        val mine = rule()
        val theirs = Rule(title = "Morning prayers", recurrence = Recurrence.Daily)
        val activations = listOf(Activation(ruleID = theirs.id, from = d(2026, 1, 1)))
        assertTrue(
            engine.dueDates(mine, activations, d(2026, 1, 1), d(2026, 12, 31)).isEmpty(),
        )
    }

    @Test
    fun `a seasonal rule is due only inside its stretch`() {
        val r = Rule(title = "Lenten rule", recurrence = Recurrence.Daily)
        val activations = listOf(
            Activation(ruleID = r.id, from = d(2026, 2, 23), to = d(2026, 4, 11)),
        )
        val due = engine.dueDates(r, activations, d(2026, 1, 1), d(2026, 12, 31))
        assertEquals(d(2026, 2, 23), due.first())
        assertEquals(d(2026, 4, 11), due.last())
        assertTrue(!due.contains(d(2026, 5, 1)))
    }
}

/** Translated from suite "Editing a rule loses nothing". */
class RecurrenceFormTest {

    private val shapes: List<Recurrence> = listOf(
        Recurrence.Daily,
        Recurrence.Once(d(2026, 8, 19)),
        Recurrence.Weekly(setOf(Weekday.SUNDAY)),
        Recurrence.Weekly(setOf(Weekday.WEDNESDAY, Weekday.FRIDAY)),
        Recurrence.Monthly(1, ShortMonthPolicy.LAST_DAY),
        Recurrence.Monthly(31, ShortMonthPolicy.LAST_DAY),
        Recurrence.Monthly(31, ShortMonthPolicy.SKIP),
        Recurrence.Liturgical(LiturgicalTrigger.FastDay),
        Recurrence.Liturgical(LiturgicalTrigger.GreatFeast),
        Recurrence.Liturgical(LiturgicalTrigger.Season(FastingSeason.GREAT_LENT)),
        Recurrence.Liturgical(LiturgicalTrigger.Season(FastingSeason.NATIVITY_FAST)),
        Recurrence.Liturgical(LiturgicalTrigger.Season(FastingSeason.APOSTLES_FAST)),
        Recurrence.Liturgical(LiturgicalTrigger.Season(FastingSeason.DORMITION_FAST)),
    )

    @Test
    fun `every recurrence survives a load and save unchanged`() {
        val fallback = d(2026, 1, 1)
        for (recurrence in shapes) {
            assertEquals(recurrence, RecurrenceForm.of(recurrence).recurrence(fallback))
        }
    }

    @Test
    fun `a one-off day never becomes a repeating rule`() {
        val day = d(2026, 8, 19)
        val form = RecurrenceForm.of(Recurrence.Once(day))
        assertEquals(RecurrenceForm.Kind.ONCE, form.kind)
        assertEquals(Recurrence.Once(day), form.recurrence(d(2020, 1, 1)))
    }

    @Test
    fun `a season keeps which season it was`() {
        for (season in FastingSeason.entries) {
            val form = RecurrenceForm.of(
                Recurrence.Liturgical(LiturgicalTrigger.Season(season)),
            )
            assertEquals(RecurrenceForm.Kind.SEASON, form.kind)
            assertEquals(season, form.season)
        }
    }

    @Test
    fun `the short-month policy is carried through, though nothing shows it`() {
        val form = RecurrenceForm.of(Recurrence.Monthly(31, ShortMonthPolicy.SKIP))
        assertEquals(ShortMonthPolicy.SKIP, form.shortMonthPolicy)
        assertEquals(
            Recurrence.Monthly(31, ShortMonthPolicy.SKIP),
            form.recurrence(d(2026, 1, 1)),
        )
    }

    @Test
    fun `clearing every weekday falls back rather than making a rule that never runs`() {
        val form = RecurrenceForm.of(Recurrence.Weekly(setOf(Weekday.SUNDAY)))
            .copy(weekdays = emptySet())
        assertEquals(
            Recurrence.Weekly(setOf(Weekday.SUNDAY)),
            form.recurrence(d(2026, 1, 1)),
        )
    }

    @Test
    fun `every kind the picker offers can be saved`() {
        val fallback = d(2026, 8, 19)
        for (kind in RecurrenceForm.Kind.entries) {
            // Must not throw.
            RecurrenceForm(kind = kind).recurrence(fallback)
        }
    }
}
