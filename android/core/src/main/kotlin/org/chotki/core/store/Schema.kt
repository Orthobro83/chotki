package org.chotki.core.store

import org.chotki.core.store.Db

/**
 * The schema, and the ladder that brings any older database up to it.
 *
 * Deliberately the same shape as the Swift store's: the same tables and the
 * same columns. The *contents* of the JSON columns differ — Kotlin writes its
 * own encoding — so a database does not move between the two platforms. That
 * was settled when sync was ruled out; it is recorded here because the schema
 * looking identical invites the assumption.
 *
 * **The version numbers have diverged, and that is correct.** Swift stops at 6.
 * Step 7 here is Kotlin's alone: it frees the stored recurrence from Kotlin
 * class names, a problem Swift never had because Swift never wrote them. Do not
 * "fix" the mismatch by adding a step to Swift — the ladders are per-platform
 * from 7 onward, and only the table shape is shared.
 *
 * Forward-only, and each step stamps `schema_version`. A step is never edited
 * once shipped: someone's database has already run it.
 */
object Schema {

    const val CURRENT_VERSION = 8

    fun migrate(db: Db) {
        db.execute("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL);")
        val current = db.query("SELECT version FROM schema_version;") { it.int(0) ?: 0 }
            .maxOrNull() ?: 0

        if (current < 1) db.execute(V1)
        if (current < 2) db.execute(V2)
        if (current < 3) db.execute(V3)
        if (current < 4) db.execute(V4)
        if (current < 5) db.execute(V5)
        if (current < 6) db.execute(V6)
        if (current < 7) db.execute(V7)
        if (current < 8) db.execute(V8)
    }

    private val V1 = """
        CREATE TABLE rule (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            note TEXT,
            source TEXT,
            recurrence TEXT NOT NULL,
            time_of_day TEXT,
            category TEXT,
            created_at TEXT NOT NULL,
            archived_at TEXT
        );

        CREATE TABLE activation (
            id TEXT PRIMARY KEY,
            rule_id TEXT NOT NULL REFERENCES rule(id) ON DELETE CASCADE,
            from_date TEXT NOT NULL,
            to_date TEXT
        );
        CREATE INDEX activation_by_rule ON activation(rule_id);

        -- One deviation per rule per day. The unique constraint is the model's
        -- rule made structural: a day cannot be both completed and skipped.
        CREATE TABLE occurrence (
            id TEXT PRIMARY KEY,
            rule_id TEXT NOT NULL REFERENCES rule(id) ON DELETE CASCADE,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            completed_at TEXT,
            moved_to TEXT,
            UNIQUE(rule_id, date)
        );
        CREATE INDEX occurrence_by_date ON occurrence(date);

        INSERT INTO schema_version (version) VALUES (1);
    """.trimIndent()

    private val V2 = """
        CREATE TABLE liturgical_day (
            civil_date TEXT NOT NULL,
            reckoning TEXT NOT NULL,
            payload TEXT NOT NULL,
            fetched_at TEXT NOT NULL,
            PRIMARY KEY (civil_date, reckoning)
        );
        INSERT INTO schema_version (version) VALUES (2);
    """.trimIndent()

    private val V3 = """
        ALTER TABLE rule ADD COLUMN reminders TEXT;
        INSERT INTO schema_version (version) VALUES (3);
    """.trimIndent()

    private val V4 = """
        CREATE TABLE app_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            payload TEXT NOT NULL
        );
        INSERT INTO schema_version (version) VALUES (4);
    """.trimIndent()

    private val V5 = """
        ALTER TABLE rule ADD COLUMN prayer_ids TEXT;
        INSERT INTO schema_version (version) VALUES (5);
    """.trimIndent()

    private val V6 = """
        ALTER TABLE rule ADD COLUMN hidden_from_library INTEGER;
        INSERT INTO schema_version (version) VALUES (6);
    """.trimIndent()

    /**
     * Every column the rule table holds, in the order the reader expects.
     *
     * Named once so the SELECT and the decoder cannot drift apart — reading by
     * index is fast and completely silent when the two disagree.
     */
    const val RULE_COLUMNS =
        "id, title, note, source, recurrence, time_of_day, category, created_at, " +
            "archived_at, reminders, prayer_ids, hidden_from_library"

    /**
     * Frees the stored recurrence from Kotlin's class names.
     *
     * Until now kotlinx wrote the fully-qualified class name as the type
     * discriminator, so every rule in the column named `org.chotki.core.
     * Recurrence.Daily` and friends. Moving or renaming the class would have
     * broken every database in the wild. The names are now explicit and frozen;
     * this rewrites what is already stored to match.
     *
     * Written as REPLACE over the text because that is exactly what it is —
     * eight literal substitutions, no parsing, no round trip through a decoder
     * that would refuse the old form anyway.
     */
    private val V7 = """
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.Recurrence.Once"', '"once"');
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.Recurrence.Daily"', '"daily"');
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.Recurrence.Weekly"', '"weekly"');
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.Recurrence.Monthly"', '"monthly"');
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.Recurrence.Liturgical"', '"liturgical"');
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.LiturgicalTrigger.FastDay"', '"fastDay"');
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.LiturgicalTrigger.GreatFeast"', '"greatFeast"');
        UPDATE rule SET recurrence = REPLACE(recurrence, '"org.chotki.core.LiturgicalTrigger.Season"', '"season"');
        INSERT INTO schema_version (version) VALUES (7);
    """.trimIndent()

    /**
     * Reflections.
     *
     * **Eight here, seven on Swift, and that is correct** — the ladders are
     * per-platform from 7 onward, as the note at the top of this file says.
     * Swift's 7 is these two tables; Kotlin's 7 was the recurrence rewrite it
     * needed and Swift did not. Only the table shape is shared.
     *
     * `weekday` is the primary key of `reflection` because there is exactly one
     * per day and there always will be — they are rewritten, never added or
     * removed, so there is no ordering within a day and no archived state.
     *
     * The seven are NOT seeded here. `Store.seedReflections()` does it from the
     * generated content, so the Brotherhood's text lives in one place rather
     * than being copied into a migration where it would drift.
     */
    private val V8 = """
        CREATE TABLE reflection (
            weekday INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            notice TEXT NOT NULL,
            task TEXT NOT NULL,
            edited_at TEXT
        );

        -- q_title, q_notice and q_task are the question as it stood when the
        -- answer was written. They are copied, not joined: the wording is
        -- editable, and a join would silently rewrite every past answer's
        -- question the moment it changed.
        CREATE TABLE reflection_entry (
            id TEXT PRIMARY KEY,
            weekday INTEGER NOT NULL,
            date TEXT NOT NULL,
            text TEXT NOT NULL,
            q_title TEXT NOT NULL,
            q_notice TEXT NOT NULL,
            q_task TEXT NOT NULL,
            written_at TEXT NOT NULL,
            UNIQUE(weekday, date)
        );
        CREATE INDEX reflection_entry_by_date ON reflection_entry(date);

        INSERT INTO schema_version (version) VALUES (8);
    """.trimIndent()
}
