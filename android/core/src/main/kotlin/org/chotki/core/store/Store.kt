package org.chotki.core.store

import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.EditPlan
import org.chotki.core.AppSettings
import org.chotki.core.LiturgicalDay
import org.chotki.core.Occurrence
import org.chotki.core.Reckoning
import org.chotki.core.Rule
import org.chotki.core.Weekday
import org.chotki.core.reflections.Reflection
import org.chotki.core.reflections.ReflectionArchive
import org.chotki.core.reflections.ReflectionEntry
import org.chotki.core.reflections.ReflectionImport
import org.chotki.core.reflections.ReflectionImportResult
import org.chotki.core.reflections.ReflectionJournal
import org.chotki.core.reflections.bundled
import java.util.UUID

class StoreException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Persistence, kept behind an interface so the semantics never depend on it.
 *
 * [apply] exists so a three-way edit lands atomically — a split that closed the
 * old stretch but failed to open the new one would make a rule silently vanish.
 *
 */
interface Store {
    fun save(rule: Rule)
    fun rule(id: UUID): Rule?
    fun rules(includeArchived: Boolean = false): List<Rule>

    fun save(activation: Activation)
    fun removeActivation(id: UUID)
    fun activations(ruleID: UUID? = null): List<Activation>

    fun save(occurrence: Occurrence)
    fun occurrences(
        ruleID: UUID? = null,
        from: CalendarDate? = null,
        through: CalendarDate? = null,
    ): List<Occurrence>

    /**
     * Returns a day to having no record at all.
     *
     * Absence is the default state — due, or missed once its moment has passed —
     * so restoring absence needs a real delete. Writing "skipped" instead would
     * quietly remove the day from scoring, which is a different thing entirely
     * and not what un-ticking a box means.
     */
    fun removeOccurrence(ruleID: UUID, date: CalendarDate)

    fun apply(plan: EditPlan)

    fun saveLiturgicalDay(day: LiturgicalDay)
    fun liturgicalDay(civilDate: CalendarDate, reckoning: Reckoning): LiturgicalDay?
    fun liturgicalDays(
        reckoning: Reckoning,
        from: CalendarDate,
        through: CalendarDate,
    ): List<LiturgicalDay>

    /** Passing null clears every reckoning. */
    fun clearLiturgicalCache(reckoning: Reckoning? = null)

    /**
     * Settings live beside the data rather than in a platform preferences
     * system, so what someone has chosen travels with their record, survives a
     * move between machines, and is included in a backup.
     */
    fun loadSettings(): AppSettings?
    fun saveSettings(settings: AppSettings)

    /** The seven reflections, in weekday order. Seeded by [seedReflections]. */
    fun reflections(): List<Reflection>

    /** Upserts by weekday. There is one per weekday and there always will be. */
    fun save(reflection: Reflection)

    /** Answers, newest first. Passing null for a bound leaves it open. */
    fun reflectionEntries(
        weekday: Weekday? = null,
        from: CalendarDate? = null,
        through: CalendarDate? = null,
    ): List<ReflectionEntry>

    /**
     * Writes an answer.
     *
     * This upserts on (weekday, date) because a store must be able to restore a
     * backup verbatim. The rule that an answer **locks once saved** is enforced
     * above the store, by [ReflectionJournal.hasEntry] and by [ReflectionEntry]
     * having no mutable field — not here, where a restore would be
     * indistinguishable from an edit.
     */
    fun save(entry: ReflectionEntry)

    fun close()
}

/**
 * Puts the bundled wording in place for any weekday that has none.
 *
 * Idempotent, and safe to call on every launch: it fills gaps and never
 * overwrites, so a question the user has edited survives it. Done here rather
 * than in a SQL migration so the text lives in exactly one place and every
 * store implementation behaves identically.
 */
fun Store.seedReflections(): List<Reflection> {
    val held = reflections().map { it.weekday }.toSet()
    val missing = Reflection.bundled.filter { it.weekday !in held }
    missing.forEach { save(it) }
    return missing
}

/** The reflection for one weekday, seeding first if the record is empty. */
fun Store.reflection(weekday: Weekday): Reflection {
    reflections().firstOrNull { it.weekday == weekday }?.let { return it }
    seedReflections()
    return reflections().firstOrNull { it.weekday == weekday } ?: Reflection.bundled(weekday)
}

fun Store.exportReflections(now: java.time.Instant = java.time.Instant.now()): ReflectionArchive =
    ReflectionArchive(
        exportedAt = now,
        reflections = reflections(),
        entries = reflectionEntries(),
    )

fun Store.exportReflectionsJson(now: java.time.Instant = java.time.Instant.now()): String =
    ReflectionImport.write(exportReflections(now))

/** Merges a journal in. Never discards what is already held. */
fun Store.importReflections(archive: ReflectionArchive): ReflectionImportResult {
    val result = ReflectionImport.plan(archive, reflectionEntries())
    result.added.forEach { save(it) }
    // Questions are restored only where this record has none, so an import
    // cannot rewrite wording the user has since edited.
    val held = reflections().map { it.weekday }.toSet()
    archive.reflections.filter { it.weekday !in held }.forEach { save(it) }
    return result
}

fun Store.importReflectionsJson(
    text: String,
    now: java.time.Instant = java.time.Instant.now(),
): ReflectionImportResult = importReflections(ReflectionImport.read(text, now))
