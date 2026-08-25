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

/** Rules of one's own, kept so they can be taken up again. */
class CustomLibraryTest {

    private fun own(title: String, days: Long = 0, hidden: Boolean? = null) = Rule(
        title = title,
        recurrence = Recurrence.Daily,
        createdAt = java.time.Instant.now().plusSeconds(days * 86_400),
        hiddenFromLibrary = hidden,
    )

    @Test
    fun `a rule of one's own is one the bundled library does not have`() {
        assertTrue(CustomLibrary.isOwn(own("Cold plunge")))
        assertTrue(CustomLibrary.isOwn(own("Workout")))
        assertTrue(!CustomLibrary.isOwn(own("Evening prayers")), "that one is the library's")
        assertTrue(!CustomLibrary.isOwn(own("evening PRAYERS")), "and case does not change it")
    }

    // source looks like provenance and is not: it is a free-text note the person
    // edits, so it cannot be trusted to say where a rule came from.
    @Test
    fun `the free-text source is not what decides it`() {
        val rule = own("Cold plunge").copy(source = "the library")
        assertTrue(CustomLibrary.isOwn(rule), "still his own, whatever the note says")
    }

    @Test
    fun `entries are newest first, and set-aside rules are not offered`() {
        val entries = CustomLibrary.entries(
            listOf(
                own("Older", days = -3),
                own("Newest", days = -1),
                own("Evening prayers"),
                own("Set aside", days = -2, hidden = true),
            ),
        )
        assertEquals(listOf("Newest", "Older"), entries.map { it.title })
    }

    @Test
    fun `setting aside touches nothing else`() {
        val rule = own("Cold plunge")
        val aside = CustomLibrary.settingAside(rule)
        assertEquals(true, aside.hiddenFromLibrary)
        assertEquals(rule.id, aside.id)
        assertEquals(rule.recurrence, aside.recurrence)
        assertEquals(null, aside.archivedAt, "still on the rule; only the listing changed")
    }

    // The reason the whole feature exists: the same rule, with its history,
    // rather than a fresh one that splits the record in two.
    @Test
    fun `taking one up again keeps its identity`() {
        val rule = own("Cold plunge")
            .copy(archivedAt = java.time.Instant.now(), hiddenFromLibrary = true)
        val restored = CustomLibrary.takingUp(rule)
        assertEquals(rule.id, restored.id, "the same rule, so its history follows it")
        assertEquals(null, restored.archivedAt)
        assertEquals(null, restored.hiddenFromLibrary, "back in the library too")
    }

    @Test
    fun `an archived rule of one's own is still offered`() {
        val rule = own("Cold plunge").copy(archivedAt = java.time.Instant.now())
        assertEquals(1, CustomLibrary.entries(listOf(rule)).size, "that is the point")
    }
}

/** The prayers screen, which outlives the view it is drawn in. */
class PrayerScreenTest {

    @Test
    fun `the rope follows the prayer`() {
        assertTrue(PrayerScreen(selection = null).showsRope(), "nothing chosen shows the rope")
        assertTrue(PrayerScreen(selection = "jesus-prayer").showsRope())
        assertTrue(
            !PrayerScreen(selection = "morning").showsRope(),
            "a rule is read, not counted",
        )
    }

    @Test
    fun `the reader can overrule it`() {
        val screen = PrayerScreen(selection = "morning")
        assertTrue(!screen.showsRope())
        assertTrue(screen.showingRope(true).showsRope())
    }

    // Otherwise "hide" pressed once on the Creed would silently hide the rope
    // behind the Jesus Prayer chosen ten minutes later.
    @Test
    fun `choosing again goes back to following the prayer`() {
        val hidden = PrayerScreen(selection = "jesus-prayer").showingRope(false)
        assertTrue(!hidden.showsRope())
        assertTrue(hidden.choosing("publican").showsRope())
    }

    @Test
    fun `choosing what is already chosen changes nothing`() {
        val hidden = PrayerScreen(selection = "jesus-prayer").showingRope(false)
        assertTrue(!hidden.choosing("jesus-prayer").showsRope(), "the override survives")
    }

    @Test
    fun `counting stops at the target and reports the knot`() {
        var screen = PrayerScreen(count = 0, target = 3)
        var completed: Boolean
        repeat(2) {
            val (next, done) = screen.advanced()
            screen = next
            assertTrue(!done)
        }
        val (third, done) = screen.advanced()
        screen = third
        assertTrue(done, "the third completes it")
        assertTrue(screen.isComplete)

        val (again, more) = screen.advanced()
        assertTrue(!more, "no further")
        assertEquals(3, again.count)
    }

    @Test
    fun `a new target starts the count again`() {
        val aimed = PrayerScreen(count = 40, target = 50).aiming(33)
        assertEquals(0, aimed.count, "40 of 33 would show a knot already complete")
        assertEquals(33, aimed.target)
    }

    @Test
    fun `the offered targets are the traditional ones`() {
        assertEquals(listOf(33, 50, 100), PrayerScreen.targets)
    }

    // Saint Ioannikios closes the evening rule and is said once, not counted.
    @Test
    fun `only the short repeated prayers bring the rope`() {
        assertTrue(!PrayerScreen(selection = "ioannikios").showsRope())
        assertTrue(!PrayerScreen(selection = "creed").showsRope())
        assertTrue(PrayerScreen(selection = "lord-have-mercy").showsRope())
        assertTrue(PrayerScreen(selection = "no-such-prayer").showsRope(), "an unknown id is not a rule")
    }
}
