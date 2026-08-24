package org.chotki.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.EditPlanner
import org.chotki.core.EditScope
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.TimeOfDay
import org.chotki.core.Weekday
import org.chotki.core.content.Content
import org.chotki.core.store.Schema
import org.chotki.core.store.SqliteStore
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

private fun d(y: Int, m: Int, day: Int): CalendarDate =
    CalendarDate.of(y, m, day) ?: error("$y-$m-$day is not a date")

/**
 * `:core` running on an actual Android device.
 *
 * The JVM tests prove the schema and the queries against JDBC; these prove the
 * same code against Android's own SQLite, which is a different implementation
 * with different quirks. Between them, the store is verified where it runs
 * rather than only where it is convenient to test.
 *
 * Driven with `./gradlew :app:connectedDebugAndroidTest`.
 */
@RunWith(AndroidJUnit4::class)
class AndroidStoreTest {

    private val db = AndroidDb.inMemory()
    private val store = SqliteStore(db)

    @After fun tearDown() = store.close()

    @Test
    fun migrationsRunAllTheWayOnAndroid() {
        val versions = db.query("SELECT version FROM schema_version ORDER BY version;") { it.int(0)!! }
        assertEquals((1..Schema.CURRENT_VERSION).toList(), versions)
    }

    // On a real file, not the in-memory database the rest of these use: an
    // in-memory database cannot journal to a separate file, so it answers
    // "memory" and always will.
    @Test
    fun walIsOnForARealDatabase() {
        val context = androidx.test.platform.app.InstrumentationRegistry
            .getInstrumentation().targetContext
        val name = "wal-check.sqlite"
        java.io.File(context.filesDir, name).delete()

        val onDisk = AndroidDb.open(context, name)
        try {
            SqliteStore(onDisk)
            val mode = onDisk.query("PRAGMA journal_mode;") { it.string(0) }.single()
            assertEquals("wal", mode?.lowercase())
        } finally {
            onDisk.close()
            java.io.File(context.filesDir, name).delete()
        }
    }

    @Test
    fun aRuleRoundTripsWhole() {
        val rule = Rule(
            title = "Morning prayers",
            note = "on rising",
            recurrence = Recurrence.Weekly(setOf(Weekday.WEDNESDAY, Weekday.FRIDAY)),
            timeOfDay = TimeOfDay.of(6, 30),
            prayerIDs = listOf("opening-prayer", "our-father"),
        )
        store.save(rule)
        assertEquals(rule, store.rule(rule.id))
    }

    @Test
    fun datesRangeScanAsText() {
        val rule = Rule(title = "r", recurrence = Recurrence.Daily)
        store.save(rule)
        for (day in listOf(d(2026, 7, 31), d(2026, 8, 1), d(2026, 8, 19), d(2026, 9, 1))) {
            store.save(Occurrence(ruleID = rule.id, date = day, status = OccurrenceStatus.COMPLETED))
        }
        val august = store.occurrences(from = d(2026, 8, 1), through = d(2026, 8, 31))
        assertEquals(listOf(d(2026, 8, 1), d(2026, 8, 19)), august.map { it.date })
    }

    // The reason apply() takes a transaction: a split that closed the old
    // stretch and failed to open the new one would make a rule vanish.
    @Test
    fun aWholeEditPlanLandsAtOnce() {
        val rule = Rule(
            title = "Evening prayers",
            recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(21, 30),
        )
        store.save(rule)
        val activation = Activation(ruleID = rule.id, from = d(2026, 3, 1))
        store.save(activation)

        store.apply(
            EditPlanner().edit(
                rule = rule,
                changes = rule.copy(timeOfDay = TimeOfDay.of(22, 0)),
                activations = listOf(activation),
                date = d(2026, 8, 19),
                scope = EditScope.THIS_AND_FUTURE,
            ),
        )

        assertEquals(2, store.rules().size)
        assertEquals(d(2026, 8, 18), store.activations(rule.id).single().to)
    }

    @Test
    fun foreignKeysCascadeOnAndroid() {
        val rule = Rule(title = "r", recurrence = Recurrence.Daily)
        store.save(rule)
        store.save(Activation(ruleID = rule.id, from = d(2026, 1, 1)))
        db.update("DELETE FROM rule WHERE id = ?;", listOf(rule.id.toString()))
        assertTrue(store.activations(rule.id).isEmpty())
    }

    @Test
    fun settingsRoundTrip() {
        assertNull(store.loadSettings())
        val settings = org.chotki.core.AppSettings(
            hasCompletedFirstRun = true,
            clockStyle = org.chotki.core.ClockStyle.TWELVE_HOUR,
        )
        store.saveSettings(settings)
        assertEquals(settings, store.loadSettings())
    }

    // The content ships inside the APK; a resource that fails to load on device
    // is invisible until someone opens the glossary.
    @Test
    fun theBundledContentLoadsFromTheApk() {
        assertEquals(111, Content.glossary.size)
        assertEquals(19, Content.prayers.size)
        assertEquals(23, Content.ruleLibrary.size)
        assertNotNull(Content.prayers.first { it.id == "jesus-prayer" })
    }
}
