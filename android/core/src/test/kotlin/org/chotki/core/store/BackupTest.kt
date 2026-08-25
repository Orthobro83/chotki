package org.chotki.core.store

import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.FastingSeason
import org.chotki.core.LiturgicalTrigger
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.TimeOfDay
import java.time.Instant
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * The record has to be able to leave the phone.
 *
 * Android gives an app no place to leave anything behind, and Chotki turns
 * Android's own backup off — a record of someone's prayer life is not something
 * to hand to Google. Which means this file is the only way a person keeps their
 * history when they change phones, and the only thing standing between a beta
 * tester and losing months of it.
 */
class BackupTest {

    private val db = JdbcDb.inMemory()
    private val store = SqliteStore(db)

    @AfterTest fun tearDown() = db.close()

    private fun aRecord(): Triple<Rule, Activation, Occurrence> {
        val rule = Rule(
            title = "Evening prayers",
            note = "before sleep",
            recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(21, 30),
            prayerIDs = listOf("trisagion", "our-father"),
            createdAt = Instant.parse("2026-03-01T05:00:00Z"),
        )
        val activation = Activation(ruleID = rule.id, from = CalendarDate.of(2026, 3, 1)!!)
        val occurrence = Occurrence(
            ruleID = rule.id,
            date = CalendarDate.of(2026, 3, 2)!!,
            status = OccurrenceStatus.COMPLETED,
            completedAt = Instant.parse("2026-03-02T21:40:00Z"),
        )
        store.save(rule); store.save(activation); store.save(occurrence)
        return Triple(rule, activation, occurrence)
    }

    @Test fun `everything comes back`() {
        val (rule, activation, occurrence) = aRecord()
        val text = store.exportJson()

        val fresh = JdbcDb.inMemory()
        try {
            val restored = SqliteStore(fresh)
            restored.importJson(text)

            assertEquals(listOf(rule), restored.rules())
            assertEquals(listOf(activation), restored.activations())
            assertEquals(listOf(occurrence), restored.occurrences())
        } finally {
            fresh.close()
        }
    }

    /** A rule someone stopped keeping is history, and history is the point. */
    @Test fun `archived rules are carried too`() {
        val rule = Rule(
            title = "A rule I stopped",
            recurrence = Recurrence.Daily,
            archivedAt = Instant.parse("2026-06-01T05:00:00Z"),
        )
        store.save(rule)

        val fresh = JdbcDb.inMemory()
        try {
            SqliteStore(fresh).let {
                it.importJson(store.exportJson())
                assertEquals(listOf(rule), it.rules(includeArchived = true))
            }
        } finally {
            fresh.close()
        }
    }

    /** Every shape, because a backup that drops one is worse than none. */
    @Test fun `every recurrence shape survives the round trip`() {
        val shapes = listOf(
            Recurrence.Daily,
            Recurrence.WEDNESDAY_AND_FRIDAY,
            Recurrence.Once(CalendarDate.of(2026, 8, 24)!!),
            Recurrence.Monthly(31),
            Recurrence.Liturgical(LiturgicalTrigger.FastDay),
            Recurrence.Liturgical(LiturgicalTrigger.GreatFeast),
            Recurrence.Liturgical(LiturgicalTrigger.Season(FastingSeason.GREAT_LENT)),
        )
        for (shape in shapes) store.save(Rule(title = shape.toString(), recurrence = shape))

        val fresh = JdbcDb.inMemory()
        try {
            val restored = SqliteStore(fresh)
            restored.importJson(store.exportJson())
            assertEquals(shapes.toSet(), restored.rules().map { it.recurrence }.toSet())
        } finally {
            fresh.close()
        }
    }

    /** Restoring twice must not double anyone's history. */
    @Test fun `restoring the same file twice changes nothing the second time`() {
        aRecord()
        val text = store.exportJson()

        val fresh = JdbcDb.inMemory()
        try {
            val restored = SqliteStore(fresh)
            restored.importJson(text)
            val after = restored.rules() to restored.occurrences()
            restored.importJson(text)

            assertEquals(after.first, restored.rules())
            assertEquals(after.second, restored.occurrences())
        } finally {
            fresh.close()
        }
    }

    /** Nothing already here is removed. A restore is a merge. */
    @Test fun `a restore never removes what is already there`() {
        val mine = Rule(title = "Something I already keep", recurrence = Recurrence.Daily)
        store.save(mine)

        val other = JdbcDb.inMemory()
        try {
            val elsewhere = SqliteStore(other)
            elsewhere.save(Rule(title = "From the other phone", recurrence = Recurrence.Daily))
            store.importJson(elsewhere.exportJson())
        } finally {
            other.close()
        }

        assertTrue(store.rules().any { it.title == "Something I already keep" })
        assertTrue(store.rules().any { it.title == "From the other phone" })
    }

    @Test fun `a macOS backup is refused rather than half-read`() {
        val fromAMac = store.exportJson().replace("\"platform\": \"android\"", "\"platform\": \"macos\"")

        val message = assertFailsWith<BackupException> { store.importJson(fromAMac) }.message
        assertTrue(message!!.contains("macos"), message)
        assertTrue(message.contains("cannot be restored"), message)
    }

    @Test fun `a newer backup is refused rather than half-read`() {
        val newer = store.exportJson().replace("\"version\": 1", "\"version\": 2")
        assertTrue(assertFailsWith<BackupException> { store.importJson(newer) }.message!!.contains("newer"))
    }

    @Test fun `something that is not a backup at all says so plainly`() {
        val message = assertFailsWith<BackupException> { store.importJson("not json") }.message
        assertEquals("That file is not a Chotki backup.", message)
    }
}
