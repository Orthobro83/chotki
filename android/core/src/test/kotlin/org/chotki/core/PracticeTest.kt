package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

private fun day(y: Int, m: Int, d: Int): CalendarDate =
    CalendarDate.of(y, m, d) ?: error("$y-$m-$d is not a date")

/** Wednesdays and Fridays fast; Bright Week is lifted. */
private object Calendar2026 : LiturgicalDayProvider {
    override fun isFastDay(date: CalendarDate): Boolean =
        date.weekday == Weekday.WEDNESDAY || date.weekday == Weekday.FRIDAY

    override fun isGreatFeast(date: CalendarDate): Boolean = false
    override fun season(date: CalendarDate): FastingSeason? = null
    override fun fastFreeReason(date: CalendarDate): String? =
        if (date.month == 4 && date.day in 13..18) "Bright Week" else null
}

/**
 * The decisions that used to live in the macOS view model, where a port would
 * have had to rewrite them — and where every bug found by hand has been.
 *
 * Translated from suite "A rule as it stands".
 */
class PracticeTest {

    private val today = day(2026, 8, 19) // a Wednesday

    private fun practice(
        rules: List<Rule>,
        occurrences: List<Occurrence> = emptyList(),
        settings: AppSettings = AppSettings.DEFAULT,
        from: CalendarDate? = null,
    ) = Practice(
        rules = rules,
        activations = rules.map { Activation(ruleID = it.id, from = from ?: day(2026, 1, 1)) },
        occurrences = occurrences,
        settings = settings,
        liturgical = Calendar2026,
    )

    private fun rule(
        title: String,
        at: TimeOfDay? = null,
        recurrence: Recurrence = Recurrence.Daily,
        category: RuleCategory? = null,
    ) = Rule(title = title, recurrence = recurrence, timeOfDay = at, category = category)

    // MARK: what is on a day

    @Test
    fun `timed rules come first, in order, then those that run all day`() {
        val p = practice(
            listOf(
                rule("Jesus prayer"),
                rule("Evening prayers", at = TimeOfDay.of(21, 30)),
                rule("Morning prayers", at = TimeOfDay.of(6, 30)),
                rule("Almsgiving"),
            ),
        )
        assertEquals(
            listOf("Morning prayers", "Evening prayers", "Almsgiving", "Jesus prayer"),
            p.entries(today).map { it.rule.title },
        )
    }

    @Test
    fun `a rule not due that day is absent`() {
        val p = practice(listOf(rule("Sunday Liturgy", recurrence = Recurrence.Weekly(setOf(Weekday.SUNDAY)))))
        assertTrue(p.entries(today).isEmpty())
    }

    // A rule that simply vanished would look like a fault and teach nothing.
    @Test
    fun `a rule the Church has lifted is shown, with the reason`() {
        val p = practice(
            listOf(
                rule(
                    "The Wednesday and Friday fast",
                    recurrence = Recurrence.Weekly(setOf(Weekday.WEDNESDAY, Weekday.FRIDAY)),
                    category = RuleCategory.FASTING,
                ),
            ),
            settings = AppSettings(observances = ObservanceSettings(fasting = Observance.OBSERVED)),
        )
        val brightWednesday = day(2026, 4, 15)
        val entry = p.entries(brightWednesday).firstOrNull()
        assertNotNull(entry)
        assertEquals("Bright Week", entry.dispensation)
        assertTrue(entry.showsAsSatisfied)
        assertTrue(!entry.isKept, "nothing was asked, so nothing was done")
    }

    @Test
    fun `a rule taken on later invents no earlier days`() {
        val p = practice(listOf(rule("Morning prayers")), from = today)
        assertTrue(p.entries(today.plusDays(-1)).isEmpty())
        assertTrue(p.entries(today).isNotEmpty())
    }

    // MARK: settled

    @Test
    fun `a day with something outstanding is not settled`() {
        val rules = listOf(rule("Morning prayers"), rule("Evening prayers"))
        val kept = listOf(
            Occurrence(ruleID = rules[0].id, date = today, status = OccurrenceStatus.COMPLETED),
        )
        assertTrue(!practice(rules, kept).isSettled(today))
    }

    @Test
    fun `a day with everything kept is settled`() {
        val rules = listOf(rule("Morning prayers"), rule("Evening prayers"))
        val kept = rules.map {
            Occurrence(ruleID = it.id, date = today, status = OccurrenceStatus.COMPLETED)
        }
        assertTrue(practice(rules, kept).isSettled(today))
    }

    // Standing down is legitimate; treating it as unfinished would quietly
    // punish pausing.
    @Test
    fun `a rule stood down still leaves the day settled`() {
        val rules = listOf(rule("Morning prayers"), rule("Jesus prayer"))
        val occurrences = listOf(
            Occurrence(ruleID = rules[0].id, date = today, status = OccurrenceStatus.COMPLETED),
            Occurrence(ruleID = rules[1].id, date = today, status = OccurrenceStatus.SKIPPED),
        )
        assertTrue(practice(rules, occurrences).isSettled(today))
    }

    @Test
    fun `standing everything down settles nothing`() {
        val rules = listOf(rule("Morning prayers"), rule("Evening prayers"))
        val stood = rules.map {
            Occurrence(ruleID = it.id, date = today, status = OccurrenceStatus.SKIPPED)
        }
        assertTrue(!practice(rules, stood).isSettled(today))
    }

    @Test
    fun `a day with nothing on it is not settled`() {
        assertTrue(!practice(emptyList()).isSettled(today))
    }

    // MARK: pausing

    @Test
    fun `a rule with no open stretch is paused`() {
        val r = rule("Evening prayers")
        val open = Practice(
            rules = listOf(r),
            activations = listOf(Activation(ruleID = r.id, from = day(2026, 1, 1))),
            occurrences = emptyList(),
        )
        val closed = Practice(
            rules = listOf(r),
            activations = listOf(
                Activation(ruleID = r.id, from = day(2026, 1, 1), to = day(2026, 5, 1)),
            ),
            occurrences = emptyList(),
        )
        assertTrue(!open.isPaused(r))
        assertTrue(closed.isPaused(r))
    }

    // MARK: repairs

    // A rule that can never come due sits on the list and is invisible.
    @Test
    fun `a fasting rule with fasting merely shown needs the observance turned on`() {
        val p = practice(
            listOf(
                rule(
                    "Great Lent",
                    recurrence = Recurrence.Liturgical(
                        LiturgicalTrigger.Season(FastingSeason.GREAT_LENT),
                    ),
                ),
            ),
        )
        assertEquals(Observance.SHOWN, p.settings.observances.fasting)
        assertEquals(
            listOf(LiturgicalTrigger.Season(FastingSeason.GREAT_LENT)),
            p.observancesNeeded(),
        )
    }

    @Test
    fun `nothing is needed when the observance is already kept`() {
        val p = practice(
            listOf(
                rule(
                    "Great Lent",
                    recurrence = Recurrence.Liturgical(
                        LiturgicalTrigger.Season(FastingSeason.GREAT_LENT),
                    ),
                ),
            ),
            settings = AppSettings(observances = ObservanceSettings(fasting = Observance.OBSERVED)),
        )
        assertTrue(p.observancesNeeded().isEmpty())
    }

    @Test
    fun `a paused rule is left alone`() {
        val r = rule(
            "Great Lent",
            recurrence = Recurrence.Liturgical(LiturgicalTrigger.Season(FastingSeason.GREAT_LENT)),
        )
        val p = Practice(
            rules = listOf(r),
            activations = listOf(
                Activation(ruleID = r.id, from = day(2026, 1, 1), to = day(2026, 2, 1)),
            ),
            occurrences = emptyList(),
            liturgical = Calendar2026,
        )
        assertTrue(
            p.observancesNeeded().isEmpty(),
            "nothing is stranded, so nothing needs changing",
        )
    }

    @Test
    fun `someone with rules has been here before`() {
        assertTrue(practice(listOf(rule("Morning prayers"))).shouldMarkFirstRunComplete)
        assertTrue(!practice(emptyList()).shouldMarkFirstRunComplete)

        val done = AppSettings.DEFAULT.copy(hasCompletedFirstRun = true)
        assertTrue(!practice(listOf(rule("Morning prayers")), settings = done).shouldMarkFirstRunComplete)
    }

    // MARK: progress

    @Test
    fun `progress speaks only about finished days`() {
        assertEquals(day(2026, 8, 18), Practice.progressThrough(today))
    }
}
