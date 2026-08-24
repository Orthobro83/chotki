package org.chotki.core.store

import kotlinx.serialization.json.Json
import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.EditPlan
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.RuleCategory
import org.chotki.core.TimeOfDay
import java.time.Instant
import java.util.UUID

/**
 * The store, written once against [Db] and run on whatever supplies one.
 *
 * Dates are ISO text so SQLite can order and range-scan them with no date
 * handling of its own. Structured fields are JSON.
 */
class SqliteStore(private val db: Db) : Store {

    init {
        db.execute("PRAGMA journal_mode=WAL;")
        db.execute("PRAGMA foreign_keys=ON;")
        Schema.migrate(db)
    }

    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }

    // MARK: rules

    override fun save(rule: Rule) {
        db.update(
            """
            INSERT INTO rule (${Schema.RULE_COLUMNS})
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title, note = excluded.note, source = excluded.source,
                recurrence = excluded.recurrence, time_of_day = excluded.time_of_day,
                category = excluded.category, archived_at = excluded.archived_at,
                reminders = excluded.reminders, prayer_ids = excluded.prayer_ids,
                hidden_from_library = excluded.hidden_from_library;
            """.trimIndent(),
            listOf(
                rule.id.toString(),
                rule.title,
                rule.note,
                rule.source,
                json.encodeToString(Recurrence.serializer(), rule.recurrence),
                rule.timeOfDay?.let { json.encodeToString(TimeOfDay.serializer(), it) },
                rule.category?.name,
                rule.createdAt.toString(),
                rule.archivedAt?.toString(),
                // Reminders arrive at phase 7. The column is written null rather
                // than dropped, so the row shape stays right and nothing has to
                // migrate again when they do.
                null,
                rule.prayerIDs?.let { json.encodeToString(it) },
                // Only when set, so absent goes on meaning "still offered".
                if (rule.hiddenFromLibrary == true) "1" else null,
            ),
        )
    }

    override fun rule(id: UUID): Rule? =
        db.query(
            "SELECT ${Schema.RULE_COLUMNS} FROM rule WHERE id = ?;",
            listOf(id.toString()),
        ) { readRule(it) }.firstOrNull()

    override fun rules(includeArchived: Boolean): List<Rule> {
        val where = if (includeArchived) "" else "WHERE archived_at IS NULL "
        return db.query(
            "SELECT ${Schema.RULE_COLUMNS} FROM rule ${where}ORDER BY created_at;",
        ) { readRule(it) }
    }

    private fun readRule(row: Row): Rule {
        val id = row.string(0) ?: throw StoreException("a rule with no id")
        val recurrence = row.string(4) ?: throw StoreException("a rule with no recurrence")
        return Rule(
            id = UUID.fromString(id),
            title = row.string(1) ?: throw StoreException("a rule with no title"),
            note = row.string(2),
            source = row.string(3),
            recurrence = json.decodeFromString(Recurrence.serializer(), recurrence),
            timeOfDay = row.string(5)?.let { json.decodeFromString(TimeOfDay.serializer(), it) },
            category = row.string(6)?.let { name ->
                RuleCategory.entries.firstOrNull { it.name == name }
            },
            prayerIDs = row.string(10)?.let { json.decodeFromString<List<String>>(it) },
            createdAt = Instant.parse(
                row.string(7) ?: throw StoreException("a rule with no created_at"),
            ),
            archivedAt = row.string(8)?.let(Instant::parse),
            hiddenFromLibrary = row.int(11)?.let { it == 1 },
        )
    }

    // MARK: activations

    override fun save(activation: Activation) {
        db.update(
            """
            INSERT INTO activation (id, rule_id, from_date, to_date) VALUES (?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                rule_id = excluded.rule_id, from_date = excluded.from_date,
                to_date = excluded.to_date;
            """.trimIndent(),
            listOf(
                activation.id.toString(),
                activation.ruleID.toString(),
                activation.from.iso,
                activation.to?.iso,
            ),
        )
    }

    override fun removeActivation(id: UUID) {
        db.update("DELETE FROM activation WHERE id = ?;", listOf(id.toString()))
    }

    override fun activations(ruleID: UUID?): List<Activation> {
        val where = if (ruleID == null) "" else "WHERE rule_id = ? "
        val args = listOfNotNull(ruleID?.toString())
        return db.query(
            "SELECT id, rule_id, from_date, to_date FROM activation ${where}ORDER BY from_date;",
            args,
        ) { row ->
            Activation(
                id = UUID.fromString(row.string(0)),
                ruleID = UUID.fromString(row.string(1)),
                from = CalendarDate.parse(row.string(2)!!)
                    ?: throw StoreException("an activation with no start"),
                to = row.string(3)?.let(CalendarDate::parse),
            )
        }
    }

    // MARK: occurrences

    override fun save(occurrence: Occurrence) {
        db.update(
            """
            INSERT INTO occurrence (id, rule_id, date, status, completed_at, moved_to)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(rule_id, date) DO UPDATE SET
                status = excluded.status, completed_at = excluded.completed_at,
                moved_to = excluded.moved_to;
            """.trimIndent(),
            listOf(
                occurrence.id.toString(),
                occurrence.ruleID.toString(),
                occurrence.date.iso,
                occurrence.status.name,
                occurrence.completedAt?.toString(),
                occurrence.movedTo?.iso,
            ),
        )
    }

    override fun occurrences(
        ruleID: UUID?,
        from: CalendarDate?,
        through: CalendarDate?,
    ): List<Occurrence> {
        val clauses = mutableListOf<String>()
        val args = mutableListOf<String?>()
        ruleID?.let { clauses.add("rule_id = ?"); args.add(it.toString()) }
        // ISO dates compare correctly as text, which is the whole reason for
        // storing them that way.
        from?.let { clauses.add("date >= ?"); args.add(it.iso) }
        through?.let { clauses.add("date <= ?"); args.add(it.iso) }
        val where = if (clauses.isEmpty()) "" else "WHERE ${clauses.joinToString(" AND ")} "

        return db.query(
            """
            SELECT id, rule_id, date, status, completed_at, moved_to
            FROM occurrence ${where}ORDER BY date;
            """.trimIndent(),
            args,
        ) { row ->
            Occurrence(
                id = UUID.fromString(row.string(0)),
                ruleID = UUID.fromString(row.string(1)),
                date = CalendarDate.parse(row.string(2)!!)
                    ?: throw StoreException("an occurrence with no date"),
                status = OccurrenceStatus.valueOf(row.string(3)!!),
                completedAt = row.string(4)?.let(Instant::parse),
                movedTo = row.string(5)?.let(CalendarDate::parse),
            )
        }
    }

    override fun removeOccurrence(ruleID: UUID, date: CalendarDate) {
        db.update(
            "DELETE FROM occurrence WHERE rule_id = ? AND date = ?;",
            listOf(ruleID.toString(), date.iso),
        )
    }

    // MARK: the whole plan, or none of it

    override fun apply(plan: EditPlan) {
        db.transaction {
            for (rule in plan.updatedRules + plan.newRules) save(rule)
            for (activation in plan.updatedActivations + plan.newActivations) save(activation)
            for (id in plan.removedActivationIDs) removeActivation(id)
            for (occurrence in plan.newOccurrences) save(occurrence)
        }
    }

    override fun close() = db.close()
}
