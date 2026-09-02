package org.chotki.core.store

import org.chotki.core.CalendarDate
import org.chotki.core.FastingSeason
import org.chotki.core.LiturgicalTrigger
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
            // v7 changed stored data rather than shape: put Kotlin's class
            // names back into the column, which is what every database written
            // before the names were frozen actually holds.
            """UPDATE rule SET recurrence = REPLACE(recurrence, '"daily"', '"org.chotki.core.Recurrence.Daily"');""",
            """UPDATE rule SET recurrence = REPLACE(recurrence, '"weekly"', '"org.chotki.core.Recurrence.Weekly"');""",
            """UPDATE rule SET recurrence = REPLACE(recurrence, '"liturgical"', '"org.chotki.core.Recurrence.Liturgical"');""",
            """UPDATE rule SET recurrence = REPLACE(recurrence, '"season"', '"org.chotki.core.LiturgicalTrigger.Season"');""",
            // v8
            "DROP TABLE IF EXISTS reflection_entry;",
            "DROP TABLE IF EXISTS reflection;",
            "DELETE FROM schema_version WHERE version > 1;",
        )

        /**
         * Every table a migration creates. Checked against `Schema.kt` by
         * [everyLaterTableIsReversed], so forgetting one is a named failure
         * rather than "table already exists" in a suite that has nothing to do
         * with whatever was just added.
         *
         * That is not hypothetical: it happened on macOS at versions 4, 5 and
         * 7, and again here at 8.
         */
        val TABLES_MIGRATIONS_CREATE = listOf(
            "rule", "activation", "occurrence",
            "liturgical_day", "app_settings", "reflection", "reflection_entry",
        )
    }

    /**
     * Reads `Schema.kt` and checks that every table it creates is one this
     * fixture knows how to remove.
     */
    @Test fun `the fixture reverses every table a migration creates`() {
        val source = java.io.File(
            "src/main/kotlin/org/chotki/core/store/Schema.kt"
        ).let { if (it.exists()) it else java.io.File("core/$it") }
        assertTrue(source.exists(), "cannot find Schema.kt to scan — the check is looking in the wrong place")

        val created = Regex("""CREATE TABLE (?:IF NOT EXISTS )?(\w+)""")
            .findAll(source.readText())
            .map { it.groupValues[1] }
            .filter { it != "schema_version" }
            .toList()

        assertTrue(created.isNotEmpty(), "no CREATE TABLE found — the scan is wrong")
        for (table in created) {
            assertTrue(
                table in TABLES_MIGRATIONS_CREATE,
                "the schema creates `$table` but the wind-back never drops it — add it to WIND_BACK and to TABLES_MIGRATIONS_CREATE",
            )
        }
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
            db.query("SELECT COUNT(*) FROM schema_version WHERE version = ${Schema.CURRENT_VERSION};") { it.int(0) }.single(),
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

    /**
     * The one that matters: a rule written before the names were frozen.
     *
     * Until v7 the recurrence column held `org.chotki.core.Recurrence.Daily`,
     * so the class could not be renamed or moved without breaking every
     * database. This asserts the rewrite happened and the rule still decodes —
     * and it fails loudly if V7 is ever dropped from the ladder.
     */
    @Test
    fun `a rule stored under Kotlin's class names still decodes`() {
        legacyDatabase()
        assertTrue(
            db.query("SELECT recurrence FROM rule;") { it.string(0) }.single()!!
                .contains("org.chotki.core.Recurrence.Daily"),
            "the fixture does not hold the old form, so this proves nothing",
        )

        val store = SqliteStore(db)

        assertEquals(Recurrence.Daily, store.rules().single().recurrence)
        assertTrue(
            "org.chotki.core" !in db.query("SELECT recurrence FROM rule;") { it.string(0) }.single()!!,
            "a Kotlin class name is still in the stored data",
        )
    }

    /**
     * Every stored name, not only the one the fixture happens to use.
     *
     * A nested trigger is the case a text substitution can get wrong, because
     * two discriminators sit in the same string.
     */
    @Test
    fun `every recurrence shape survives being stored and read back`() {
        val store = SqliteStore(db)
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

        assertEquals(shapes.toSet(), store.rules().map { it.recurrence }.toSet())
        assertTrue(
            db.query("SELECT recurrence FROM rule;") { it.string(0) }
                .none { "org.chotki" in (it ?: "") },
            "a Kotlin class name reached the database",
        )
    }
}
