package org.chotki.core.store

import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.EditPlan
import org.chotki.core.AppSettings
import org.chotki.core.LiturgicalDay
import org.chotki.core.Occurrence
import org.chotki.core.Reckoning
import org.chotki.core.Rule
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

    fun close()
}
