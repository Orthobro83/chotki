package org.chotki.core.store

import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.EditPlanner
import org.chotki.core.EditScope
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.RuleCategory
import org.chotki.core.ShortMonthPolicy
import org.chotki.core.TimeOfDay
import org.chotki.core.Weekday
import java.time.Instant
import java.util.UUID
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int): CalendarDate =
    CalendarDate.of(y, m, day) ?: error("$y-$m-$day is not a date")

class StoreTest {
    private val db = JdbcDb.inMemory()
    private val store = SqliteStore(db)

    @AfterTest fun tearDown() = store.close()

    private fun rule(title: String = "Evening prayers") = Rule(
        title = title,
        recurrence = Recurrence.Daily,
        timeOfDay = TimeOfDay.of(21, 30),
    )

    @Test
    fun `a rule survives a round trip whole`() {
        val original = Rule(
            title = "Morning prayers",
            note = "on rising",
            source = "my godfather",
            recurrence = Recurrence.Weekly(setOf(Weekday.WEDNESDAY, Weekday.FRIDAY)),
            timeOfDay = TimeOfDay.of(6, 30),
            category = RuleCategory.PRAYER,
            prayerIDs = listOf("opening-prayer", "our-father"),
            createdAt = Instant.parse("2026-03-01T05:00:00Z"),
            hiddenFromLibrary = true,
        )
        store.save(original)

        val loaded = store.rule(original.id)
        assertNotNull(loaded)
        // Whole-value equality, so a column dropped on the way out fails here.
        assertEquals(original, loaded)
    }

    @Test
    fun `every recurrence shape survives storage`() {
        val shapes = listOf(
            Recurrence.Daily,
            Recurrence.Once(d(2026, 8, 19)),
            Recurrence.Weekly(setOf(Weekday.SUNDAY)),
            Recurrence.Monthly(31, ShortMonthPolicy.SKIP),
            Recurrence.Monthly(1, ShortMonthPolicy.LAST_DAY),
            Recurrence.Liturgical(org.chotki.core.LiturgicalTrigger.FastDay),
            Recurrence.Liturgical(org.chotki.core.LiturgicalTrigger.GreatFeast),
            Recurrence.Liturgical(
                org.chotki.core.LiturgicalTrigger.Season(org.chotki.core.FastingSeason.GREAT_LENT),
            ),
        )
        for (shape in shapes) {
            val r = Rule(title = "shape", recurrence = shape)
            store.save(r)
            assertEquals(shape, store.rule(r.id)?.recurrence, "$shape did not survive")
        }
    }

    @Test
    fun `saving twice updates rather than duplicating`() {
        val original = rule()
        store.save(original)
        store.save(original.copy(title = "Evening rule"))
        assertEquals(1, store.rules().size)
        assertEquals("Evening rule", store.rule(original.id)?.title)
    }

    @Test
    fun `archived rules are excluded unless asked for`() {
        val kept = rule("Kept")
        val gone = rule("Gone").copy(archivedAt = Instant.now())
        store.save(kept)
        store.save(gone)

        assertEquals(listOf("Kept"), store.rules().map { it.title })
        assertEquals(2, store.rules(includeArchived = true).size)
    }

    @Test
    fun `an unknown rule is null rather than an error`() {
        assertNull(store.rule(UUID.randomUUID()))
    }

    @Test
    fun `activations round-trip and filter by rule`() {
        val mine = rule("Mine")
        val theirs = rule("Theirs")
        store.save(mine)
        store.save(theirs)
        val open = Activation(ruleID = mine.id, from = d(2026, 3, 1))
        val closed = Activation(ruleID = mine.id, from = d(2026, 1, 1), to = d(2026, 2, 28))
        store.save(open)
        store.save(closed)
        store.save(Activation(ruleID = theirs.id, from = d(2026, 3, 1)))

        val loaded = store.activations(mine.id)
        assertEquals(2, loaded.size)
        assertEquals(setOf(open, closed), loaded.toSet())
        assertEquals(3, store.activations().size)
    }

    @Test
    fun `removing an activation removes only that one`() {
        val r = rule()
        store.save(r)
        val first = Activation(ruleID = r.id, from = d(2026, 1, 1), to = d(2026, 2, 1))
        val second = Activation(ruleID = r.id, from = d(2026, 3, 1))
        store.save(first)
        store.save(second)

        store.removeActivation(first.id)
        assertEquals(listOf(second), store.activations(r.id))
    }

    @Test
    fun `occurrences round-trip with their status and times`() {
        val r = rule()
        store.save(r)
        val occurrence = Occurrence(
            ruleID = r.id,
            date = d(2026, 8, 19),
            status = OccurrenceStatus.COMPLETED_LATE,
            completedAt = Instant.parse("2026-08-20T07:00:00Z"),
        )
        store.save(occurrence)
        assertEquals(listOf(occurrence), store.occurrences(r.id))
    }

    // The unique constraint is the model's rule made structural: a day cannot
    // be both completed and skipped.
    @Test
    fun `a second occurrence for the same day replaces the first`() {
        val r = rule()
        store.save(r)
        store.save(Occurrence(ruleID = r.id, date = d(2026, 8, 19), status = OccurrenceStatus.COMPLETED))
        store.save(Occurrence(ruleID = r.id, date = d(2026, 8, 19), status = OccurrenceStatus.SKIPPED))

        val loaded = store.occurrences(r.id)
        assertEquals(1, loaded.size)
        assertEquals(OccurrenceStatus.SKIPPED, loaded[0].status)
    }

    // ISO text is stored precisely so ranges can be compared as strings.
    @Test
    fun `occurrences filter by date range`() {
        val r = rule()
        store.save(r)
        for (day in listOf(d(2026, 7, 31), d(2026, 8, 1), d(2026, 8, 19), d(2026, 9, 1))) {
            store.save(Occurrence(ruleID = r.id, date = day, status = OccurrenceStatus.COMPLETED))
        }

        val august = store.occurrences(from = d(2026, 8, 1), through = d(2026, 8, 31))
        assertEquals(listOf(d(2026, 8, 1), d(2026, 8, 19)), august.map { it.date })
        assertEquals(3, store.occurrences(from = d(2026, 8, 1)).size)
        assertEquals(2, store.occurrences(through = d(2026, 8, 1)).size)
    }

    // Un-ticking a box must restore absence, not write "skipped" — which would
    // remove the day from scoring, an entirely different thing.
    @Test
    fun `removing an occurrence leaves no record at all`() {
        val r = rule()
        store.save(r)
        store.save(Occurrence(ruleID = r.id, date = d(2026, 8, 19), status = OccurrenceStatus.COMPLETED))
        store.removeOccurrence(r.id, d(2026, 8, 19))
        assertTrue(store.occurrences(r.id).isEmpty())
    }

    @Test
    fun `removing a rule cascades to its activations and occurrences`() {
        val r = rule()
        store.save(r)
        store.save(Activation(ruleID = r.id, from = d(2026, 1, 1)))
        store.save(Occurrence(ruleID = r.id, date = d(2026, 8, 19), status = OccurrenceStatus.COMPLETED))

        db.update("DELETE FROM rule WHERE id = ?;", listOf(r.id.toString()))
        assertTrue(store.activations(r.id).isEmpty(), "the foreign key did not cascade")
        assertTrue(store.occurrences(r.id).isEmpty())
    }

    @Test
    fun `a whole edit plan lands at once`() {
        val r = rule()
        store.save(r)
        val activation = Activation(ruleID = r.id, from = d(2026, 3, 1))
        store.save(activation)

        val plan = EditPlanner().edit(
            rule = r,
            changes = r.copy(timeOfDay = TimeOfDay.of(22, 0)),
            activations = listOf(activation),
            date = d(2026, 8, 19),
            scope = EditScope.THIS_AND_FUTURE,
        )
        store.apply(plan)

        assertEquals(2, store.rules().size, "the successor was written")
        assertEquals(d(2026, 8, 18), store.activations(r.id).single().to)
        val successor = store.rules().first { it.id != r.id }
        assertEquals(TimeOfDay.of(22, 0), successor.timeOfDay)
        assertEquals(d(2026, 8, 19), store.activations(successor.id).single().from)
    }

    // The reason apply() takes a transaction: a split that closed the old
    // stretch and failed to open the new one would make a rule vanish.
    @Test
    fun `a plan that fails part way leaves nothing behind`() {
        val r = rule()
        store.save(r)
        val activation = Activation(ruleID = r.id, from = d(2026, 3, 1))
        store.save(activation)

        // An occurrence for a rule that does not exist violates the foreign key.
        val doomed = EditPlanner()
            .pause(r, listOf(activation), d(2026, 8, 19))
            .copy(
                newOccurrences = listOf(
                    Occurrence(
                        ruleID = UUID.randomUUID(),
                        date = d(2026, 8, 19),
                        status = OccurrenceStatus.CANCELLED,
                    ),
                ),
            )

        assertFailsWith<Exception> { store.apply(doomed) }
        assertNull(
            store.activations(r.id).single().to,
            "the pause was rolled back with the rest",
        )
        assertTrue(store.occurrences().isEmpty())
    }
}

/**
 * Settings live beside the data rather than in a platform preferences system.
 *
 * The Swift app lost a person's settings once, because they were written to a
 * preferences domain that did not exist — which is how fasting rules silently
 * stopped appearing. These tests are why that cannot happen quietly here.
 */
class SettingsStoreTest {
    private val db = JdbcDb.inMemory()
    private val store = SqliteStore(db)

    @AfterTest fun tearDown() = store.close()

    @Test
    fun `a fresh database has no settings rather than wrong ones`() {
        assertNull(store.loadSettings())
    }

    @Test
    fun `settings round-trip whole`() {
        val settings = org.chotki.core.AppSettings(
            jurisdiction = org.chotki.core.Jurisdiction.KNOWN
                .first { it.name == "Georgian Orthodox Church" },
            observances = org.chotki.core.ObservanceSettings(
                fasting = org.chotki.core.Observance.OBSERVED,
                feasts = org.chotki.core.Observance.HIDDEN,
            ),
            hasCompletedFirstRun = true,
            clockStyle = org.chotki.core.ClockStyle.TWELVE_HOUR,
            reckoningChangedOn = d(2026, 8, 24),
        )
        store.saveSettings(settings)
        assertEquals(settings, store.loadSettings())
    }

    @Test
    fun `saving twice replaces rather than duplicating`() {
        store.saveSettings(org.chotki.core.AppSettings.DEFAULT)
        store.saveSettings(
            org.chotki.core.AppSettings.DEFAULT.copy(hasCompletedFirstRun = true),
        )
        assertEquals(1, db.query("SELECT COUNT(*) FROM app_settings;") { it.int(0) }.single())
        assertEquals(true, store.loadSettings()?.hasCompletedFirstRun)
    }

    // A record written before a setting existed must keep everything else and
    // default the rest, never fail and take the whole thing with it.
    @Test
    fun `a record that predates a setting keeps what it has`() {
        db.update(
            "INSERT INTO app_settings (id, payload) VALUES (1, ?);",
            listOf("""{"hasCompletedFirstRun":true,"clockStyle":"TWELVE_HOUR"}"""),
        )
        val loaded = store.loadSettings()
        assertNotNull(loaded)
        assertEquals(true, loaded.hasCompletedFirstRun, "what was written is kept")
        assertEquals(org.chotki.core.ClockStyle.TWELVE_HOUR, loaded.clockStyle)
        assertEquals(
            org.chotki.core.Jurisdiction.DEFAULT, loaded.jurisdiction,
            "and what was not gets a default",
        )
        assertNull(loaded.reckoningChangedOn)
    }

    @Test
    fun `an empty record is every default rather than an error`() {
        db.update("INSERT INTO app_settings (id, payload) VALUES (1, ?);", listOf("{}"))
        assertEquals(org.chotki.core.AppSettings.DEFAULT, store.loadSettings())
    }
}
