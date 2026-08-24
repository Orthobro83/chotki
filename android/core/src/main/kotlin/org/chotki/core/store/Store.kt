package org.chotki.core.store

import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.EditPlan
import org.chotki.core.Occurrence
import org.chotki.core.Rule
import java.util.UUID

class StoreException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Persistence, kept behind an interface so the semantics never depend on it.
 *
 * [apply] exists so a three-way edit lands atomically — a split that closed the
 * old stretch but failed to open the new one would make a rule silently vanish.
 *
 * Settings and the liturgical cache are not here yet. Their tables are created
 * by the migration ladder, because the ladder must match step for step, but
 * `AppSettings` and `LiturgicalDay` are not ported until phases 5 and 6 and
 * there is nothing honest to store until they are.
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

    fun close()
}
