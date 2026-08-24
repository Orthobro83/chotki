package org.chotki.core

import java.time.Instant
import java.util.UUID

/**
 * Which occurrences an edit or deletion should affect.
 *
 * Every change to a repeating rule asks this. Offering it from the start is what
 * makes the model hold: retrofitting "this and future" onto a schema that
 * assumed whole-series edits is a rewrite, not a patch.
 */
enum class EditScope {
    /** Leaves the series alone and records a single deviation. */
    THIS_DAY,

    /**
     * Ends the series here and starts a new one carrying the change, so the past
     * keeps reporting what was actually kept at the time.
     */
    THIS_AND_FUTURE,

    /** Rewrites the rule everywhere, including in history. */
    WHOLE_SERIES,
}

/**
 * The mutations an edit implies. Pure data, so the whole three-way edit is
 * testable without a database.
 */
data class EditPlan(
    val updatedRules: List<Rule> = emptyList(),
    val newRules: List<Rule> = emptyList(),
    val updatedActivations: List<Activation> = emptyList(),
    val newActivations: List<Activation> = emptyList(),
    val removedActivationIDs: List<UUID> = emptyList(),
    val newOccurrences: List<Occurrence> = emptyList(),
) {
    val isEmpty: Boolean
        get() = updatedRules.isEmpty() && newRules.isEmpty() && updatedActivations.isEmpty() &&
            newActivations.isEmpty() && removedActivationIDs.isEmpty() && newOccurrences.isEmpty()
}

class EditPlanner {

    /**
     * Stop a rule, from [date] onwards or entirely.
     *
     * Nothing is ever destroyed. Deleting closes the activation and archives the
     * rule, so every occurrence already kept stays in the record and the score
     * does not move.
     */
    fun delete(
        rule: Rule,
        activations: List<Activation>,
        date: CalendarDate,
        scope: EditScope,
        now: Instant = Instant.now(),
    ): EditPlan {
        val mine = activations.filter { it.ruleID == rule.id }
        return when (scope) {
            EditScope.THIS_DAY -> EditPlan(
                newOccurrences = listOf(
                    Occurrence(ruleID = rule.id, date = date, status = OccurrenceStatus.CANCELLED),
                ),
            )

            EditScope.THIS_AND_FUTURE -> closing(mine, date)

            EditScope.WHOLE_SERIES -> closing(mine, date)
                .copy(updatedRules = listOf(rule.copy(archivedAt = now)))
        }
    }

    /** Apply [changes] — a copy of [rule] with fields altered — at [date]. */
    fun edit(
        rule: Rule,
        changes: Rule,
        activations: List<Activation>,
        date: CalendarDate,
        scope: EditScope,
    ): EditPlan {
        val mine = activations.filter { it.ruleID == rule.id }
        return when (scope) {
            EditScope.WHOLE_SERIES ->
                EditPlan(updatedRules = listOf(changes.copy(archivedAt = rule.archivedAt)))

            EditScope.THIS_AND_FUTURE -> {
                // End the old series the day before, and start a fresh rule
                // carrying the change. History keeps reporting the old shape,
                // which is the point.
                //
                // Built by copying the whole rule and overriding what differs,
                // rather than by naming the fields to keep. Naming them is how
                // the Swift original silently dropped a rule's prayers and its
                // reminder settings on every edit from today onwards, and the
                // same would happen again the next time a field is added.
                val successor = changes.copy(
                    id = UUID.randomUUID(),
                    createdAt = rule.createdAt,
                    archivedAt = null,
                    hiddenFromLibrary = null,
                )
                closing(mine, date).copy(
                    newRules = listOf(successor),
                    newActivations = listOf(Activation(ruleID = successor.id, from = date)),
                )
            }

            EditScope.THIS_DAY -> {
                // Cancel the original for that day and stand a one-off in its
                // place.
                val oneOff = changes.copy(
                    id = UUID.randomUUID(),
                    recurrence = Recurrence.Once(date),
                    createdAt = Instant.now(),
                    archivedAt = null,
                    hiddenFromLibrary = null,
                )
                EditPlan(
                    newRules = listOf(oneOff),
                    newActivations = listOf(
                        Activation(ruleID = oneOff.id, from = date, to = date),
                    ),
                    newOccurrences = listOf(
                        Occurrence(
                            ruleID = rule.id,
                            date = date,
                            status = OccurrenceStatus.CANCELLED,
                        ),
                    ),
                )
            }
        }
    }

    /**
     * Pause a rule as of [date], inclusive — the day it is paused still counts,
     * which is what someone means when they stand down in the evening.
     */
    fun pause(rule: Rule, activations: List<Activation>, date: CalendarDate): EditPlan =
        EditPlan(
            updatedActivations = activations
                .filter { it.ruleID == rule.id && it.isOpen }
                .map { it.copy(to = date) },
        )

    /**
     * Resume from [date], opening a fresh stretch. The gap between is neither
     * kept nor missed — it simply is not scored.
     */
    fun resume(rule: Rule, date: CalendarDate): EditPlan =
        EditPlan(newActivations = listOf(Activation(ruleID = rule.id, from = date)))

    /** Close every stretch at [date], so nothing on or after it is due. */
    private fun closing(activations: List<Activation>, date: CalendarDate): EditPlan {
        val dayBefore = date.plusDays(-1)
        val removed = mutableListOf<UUID>()
        val updated = mutableListOf<Activation>()
        for (activation in activations) {
            if (activation.from >= date) {
                // Never started; closing it would produce a backwards range.
                removed.add(activation.id)
            } else if (activation.covers(date) || activation.isOpen) {
                updated.add(activation.copy(to = dayBefore))
            }
        }
        return EditPlan(updatedActivations = updated, removedActivationIDs = removed)
    }
}
