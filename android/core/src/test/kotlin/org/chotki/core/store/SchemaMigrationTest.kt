package org.chotki.core.store

import org.chotki.core.CalendarDate
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.TimeOfDay
import java.time.Instant
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * A database written by an older version, brought forward.
 *
 * The equivalent Swift fixture has broken twice — at version 4 and again at 5 —
 * both times because a migration was added without teaching the fixture to
 * reverse it, so the test silently stopped testing anything. **If you add a
 * migration, add its reversal to [WIND_BACK].**
 */
class SchemaMigrationTest {

    private var db: JdbcDb = JdbcDb.inMemory()

    @AfterTest fun tearDown() = db.close()

    private companion object {
        /** Everything after version 1, undone. Add to this with every migration. */
        val WIND_BACK = listOf(
            "DROP TABLE IF EXISTS liturgical_day;",           // v2
            "ALTER TABLE rule DROP COLUMN reminders;",        // v3
            "DROP TABLE IF EXISTS app_settings;",             // v4
            "ALTER TABLE rule DROP COLUMN prayer_ids;",       // v5
            "ALTER TABLE rule DROP COLUMN hidden_from_library;", // v6
            "DELETE FROM schema_version WHERE version > 1;",
        )
    }

    /** A database as version 1 left it, holding a rule someone actually kept. */
    private fun legacyDatabase(): JdbcDb {
        SqliteStore(db).save(
            Rule(
                title = "Evening prayers",
                note = "before sleep",
                recurrence = Recurrence.Daily,
                timeOfDay = TimeOfDay.of(21, 30),
                createdAt = Instant.parse("2026-03-01T05:00:00Z"),
            ),
        )
        for (statement in WIND_BACK) db.execute(statement)
        return db
    }

    @Test
    fun `the fixture really is wound back, or this proves nothing`() {
        legacyDatabase()
        assertEquals(1, version(), "the fixture is not at version 1")
        assertTrue("prayer_ids" !in ruleColumns(), "a later column survived the wind-back")
        assertTrue("hidden_from_library" !in ruleColumns())
        assertTrue("reminders" !in ruleColumns())
        assertTrue(tables().none { it == "app_settings" || it == "liturgical_day" })
    }

    @Test
    fun `an old database is brought all the way forward`() {
        legacyDatabase()
        SqliteStore(db)

        assertEquals(Schema.CURRENT_VERSION, version())
        for (column in listOf("reminders", "prayer_ids", "hidden_from_library")) {
            assertTrue(column in ruleColumns(), "$column was not added")
        }
        assertTrue("app_settings" in tables())
        assertTrue("liturgical_day" in tables())
    }

    @Test
    fun `what was already there survives the journey`() {
        legacyDatabase()
        val store = SqliteStore(db)

        val rule = store.rules().singleOrNull()
        assertNotNull(rule, "the rule did not survive migration")
        assertEquals("Evening prayers", rule.title)
        assertEquals("before sleep", rule.note)
        assertEquals(TimeOfDay.of(21, 30), rule.timeOfDay)
        assertEquals(Recurrence.Daily, rule.recurrence)
        assertEquals(Instant.parse("2026-03-01T05:00:00Z"), rule.createdAt)
        // The columns it never had read as absent, not as false or empty.
        assertNull(rule.prayerIDs)
        assertNull(rule.hiddenFromLibrary)
    }

    // Absent must go on meaning "still offered", or every rule written before
    // version 6 would disappear from the library.
    @Test
    fun `a rule from before the library column is still offered`() {
        legacyDatabase()
        val rule = SqliteStore(db).rules().single()
        assertNull(rule.hiddenFromLibrary)
    }

    @Test
    fun `migrating a database already at the latest version changes nothing`() {
        SqliteStore(db)
        val before = version()
        SqliteStore(db)
        SqliteStore(db)
        assertEquals(before, version())
        assertEquals(
            1,
            db.query("SELECT COUNT(*) FROM schema_version WHERE version = 6;") { it.int(0) }.single(),
            "a step ran twice",
        )
    }

    @Test
    fun `a fresh database arrives at the current version`() {
        SqliteStore(db)
        assertEquals(Schema.CURRENT_VERSION, version())
        assertEquals(
            (1..Schema.CURRENT_VERSION).toList(),
            db.query("SELECT version FROM schema_version ORDER BY version;") { it.int(0)!! },
            "the ladder skipped a rung",
        )
    }

    @Test
    fun `dates are stored as text so they sort and range-scan`() {
        val store = SqliteStore(db)
        val rule = Rule(title = "r", recurrence = Recurrence.Daily)
        store.save(rule)
        store.save(
            org.chotki.core.Activation(
                ruleID = rule.id,
                from = CalendarDate.of(2026, 8, 19)!!,
            ),
        )
        val stored = db.query("SELECT from_date FROM activation;") { it.string(0) }.single()
        assertEquals("2026-08-19", stored)
    }

    // MARK: reading the database's own shape

    private fun version(): Int =
        db.query("SELECT version FROM schema_version;") { it.int(0) ?: 0 }.max()

    private fun ruleColumns(): List<String> =
        db.query("PRAGMA table_info(rule);") { it.string(1)!! }

    private fun tables(): List<String> =
        db.query("SELECT name FROM sqlite_master WHERE type = 'table';") { it.string(0)!! }
}
