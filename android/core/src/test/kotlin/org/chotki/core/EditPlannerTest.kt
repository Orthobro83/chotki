package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

private fun day(y: Int, m: Int, d: Int): CalendarDate =
    CalendarDate.of(y, m, d) ?: error("$y-$m-$d is not a date")

/** Translated from suite "The three-way edit". */
class EditPlannerTest {
    private val planner = EditPlanner()
    private val engine = RecurrenceEngine()

    private fun fixture(): Pair<Rule, List<Activation>> {
        val rule = Rule(
            title = "Evening prayers",
            recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(21, 30),
        )
        return rule to listOf(Activation(ruleID = rule.id, from = day(2026, 3, 1)))
    }

    // MARK: deleting

    @Test
    fun `deleting one day records a single exception and leaves the series alone`() {
        val (rule, activations) = fixture()
        val plan = planner.delete(rule, activations, day(2026, 8, 19), EditScope.THIS_DAY)
        assertEquals(1, plan.newOccurrences.size)
        assertEquals(OccurrenceStatus.CANCELLED, plan.newOccurrences[0].status)
        assertEquals(day(2026, 8, 19), plan.newOccurrences[0].date)
        assertTrue(plan.updatedActivations.isEmpty(), "the series is untouched")
        assertTrue(plan.updatedRules.isEmpty())
    }

    @Test
    fun `deleting this and future closes the stretch the day before`() {
        val (rule, activations) = fixture()
        val plan = planner.delete(rule, activations, day(2026, 8, 19), EditScope.THIS_AND_FUTURE)
        assertEquals(1, plan.updatedActivations.size)
        assertEquals(day(2026, 8, 18), plan.updatedActivations[0].to)
        assertTrue(plan.updatedRules.isEmpty(), "the rule itself is not archived")

        val due = engine.dueDates(
            rule, plan.updatedActivations, day(2026, 3, 1), day(2026, 12, 31),
        )
        assertEquals(day(2026, 8, 18), due.last())
        assertTrue(!due.contains(day(2026, 8, 19)))
        assertTrue(due.contains(day(2026, 3, 1)), "history is intact")
    }

    @Test
    fun `deleting the whole series archives the rule but keeps its history`() {
        val (rule, activations) = fixture()
        val plan = planner.delete(rule, activations, day(2026, 8, 19), EditScope.WHOLE_SERIES)
        assertEquals(1, plan.updatedRules.size)
        assertTrue(plan.updatedRules[0].isArchived)
        assertEquals(rule.id, plan.updatedRules[0].id, "archived, not replaced")
        assertEquals(day(2026, 8, 18), plan.updatedActivations[0].to)
    }

    // Closing a stretch that has not started yet would produce `to` before
    // `from` — a silently broken range that would make the rule due forever.
    @Test
    fun `deleting before a stretch begins removes it instead of inverting it`() {
        val rule = Rule(title = "Later rule", recurrence = Recurrence.Daily)
        val future = Activation(ruleID = rule.id, from = day(2026, 9, 1))
        val plan = planner.delete(
            rule, listOf(future), day(2026, 8, 19), EditScope.THIS_AND_FUTURE,
        )
        assertEquals(listOf(future.id), plan.removedActivationIDs)
        assertTrue(plan.updatedActivations.isEmpty())
    }

    // MARK: editing

    @Test
    fun `editing the whole series rewrites the rule in place`() {
        val (rule, activations) = fixture()
        val changes = rule.copy(timeOfDay = TimeOfDay.of(22, 0))
        val plan = planner.edit(
            rule, changes, activations, day(2026, 8, 19), EditScope.WHOLE_SERIES,
        )
        assertEquals(1, plan.updatedRules.size)
        assertEquals(rule.id, plan.updatedRules[0].id)
        assertEquals(TimeOfDay.of(22, 0), plan.updatedRules[0].timeOfDay)
        assertTrue(plan.newRules.isEmpty())
    }

    @Test
    fun `editing this and future splits into two series with no gap and no overlap`() {
        val (rule, activations) = fixture()
        val changes = rule.copy(timeOfDay = TimeOfDay.of(22, 0))
        val split = day(2026, 8, 19)
        val plan = planner.edit(rule, changes, activations, split, EditScope.THIS_AND_FUTURE)

        val successor = plan.newRules.firstOrNull()
        assertNotNull(successor)
        assertTrue(successor.id != rule.id, "a new series, so history keeps the old shape")
        assertEquals(TimeOfDay.of(22, 0), successor.timeOfDay)
        assertEquals(day(2026, 8, 18), plan.updatedActivations[0].to)
        assertEquals(split, plan.newActivations[0].from)

        val oldDue = engine.dueDates(
            rule, plan.updatedActivations, day(2026, 3, 1), day(2026, 12, 31),
        )
        val newDue = engine.dueDates(
            successor, plan.newActivations, day(2026, 3, 1), day(2026, 12, 31),
        )
        assertEquals(day(2026, 8, 18), oldDue.last())
        assertEquals(split, newDue.first())
        assertTrue(oldDue.toSet().intersect(newDue.toSet()).isEmpty(), "no day is due twice")
        assertEquals(
            306, oldDue.size + newDue.size,
            "and no day between March and December is lost",
        )
    }

    @Test
    fun `editing one day cancels the original and stands a one-off in its place`() {
        val (rule, activations) = fixture()
        val changes = rule.copy(timeOfDay = TimeOfDay.of(18, 0))
        val d = day(2026, 8, 19)
        val plan = planner.edit(rule, changes, activations, d, EditScope.THIS_DAY)

        assertEquals(OccurrenceStatus.CANCELLED, plan.newOccurrences.first().status)
        assertEquals(d, plan.newOccurrences.first().date)
        val oneOff = plan.newRules.firstOrNull()
        assertNotNull(oneOff)
        assertEquals(Recurrence.Once(d), oneOff.recurrence)
        assertEquals(TimeOfDay.of(18, 0), oneOff.timeOfDay)
        assertTrue(plan.updatedActivations.isEmpty(), "the series continues unchanged")

        val oneOffDue = engine.dueDates(
            oneOff, plan.newActivations, day(2026, 1, 1), day(2026, 12, 31),
        )
        assertEquals(listOf(d), oneOffDue, "the replacement exists on exactly one day")
    }

    // MARK: pausing

    @Test
    fun `pausing keeps the day it was paused on`() {
        val (rule, activations) = fixture()
        val plan = planner.pause(rule, activations, day(2026, 8, 19))
        assertEquals(day(2026, 8, 19), plan.updatedActivations[0].to)

        val due = engine.dueDates(
            rule, plan.updatedActivations, day(2026, 3, 1), day(2026, 12, 31),
        )
        assertEquals(
            day(2026, 8, 19), due.last(),
            "standing down in the evening still counts that day",
        )
    }

    @Test
    fun `resuming opens a fresh stretch and leaves the gap unscored`() {
        val (rule, activations) = fixture()
        val paused = planner.pause(rule, activations, day(2026, 5, 10))
        val resumed = planner.resume(rule, day(2026, 6, 1))
        val all = paused.updatedActivations + resumed.newActivations

        val due = engine.dueDates(rule, all, day(2026, 3, 1), day(2026, 12, 31))
        assertTrue(due.contains(day(2026, 5, 10)))
        assertTrue(!due.contains(day(2026, 5, 11)))
        assertTrue(!due.contains(day(2026, 5, 31)))
        assertTrue(due.contains(day(2026, 6, 1)))
        // The 21 days stood down are absent from the record entirely — neither
        // kept nor missed, which is the whole point of pausing.
        assertTrue(due.none { it > day(2026, 5, 10) && it < day(2026, 6, 1) })
    }
}

/**
 * What an edit must carry across, beyond the fields the form puts on screen.
 *
 * Translated from suite "An edit carries the whole rule", which was written
 * during this port: the Swift planner built a successor rule from a handful of
 * named fields, so every edit from today onwards silently dropped the rule's
 * prayers and its reminder settings. Here the successor is a copy of the whole
 * rule with the differences overridden, which cannot lose a field that exists
 * now or one added later.
 */
class EditCarriesEverythingTest {
    private val planner = EditPlanner()

    private fun fixture(): Pair<Rule, List<Activation>> {
        val rule = Rule(
            title = "Morning prayers",
            note = "on rising",
            recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(6, 30),
            category = RuleCategory.PRAYER,
            prayerIDs = listOf("opening-prayer", "heavenly-king", "our-father"),
        )
        return rule to listOf(Activation(ruleID = rule.id, from = day(2026, 3, 1)))
    }

    @Test
    fun `a successor keeps the prayers and everything else`() {
        for (scope in listOf(EditScope.THIS_AND_FUTURE, EditScope.THIS_DAY)) {
            val (rule, activations) = fixture()
            val changes = rule.copy(timeOfDay = TimeOfDay.of(7, 0))
            val plan = planner.edit(rule, changes, activations, day(2026, 8, 19), scope)

            val successor = plan.newRules.firstOrNull()
            assertNotNull(successor, "$scope produced no rule")
            assertEquals(rule.prayerIDs, successor.prayerIDs, "$scope: the prayers went with it")
            assertTrue(successor.hasPrayers)
            assertEquals("on rising", successor.note, "$scope")
            assertEquals(RuleCategory.PRAYER, successor.category, "$scope")
            assertEquals(TimeOfDay.of(7, 0), successor.timeOfDay, "$scope: the edit still applied")
            assertTrue(successor.id != rule.id, "$scope: a new rule")
        }
    }

    @Test
    fun `the whole series keeps them too, having never lost them`() {
        val (rule, activations) = fixture()
        val changes = rule.copy(timeOfDay = TimeOfDay.of(7, 0))
        val plan = planner.edit(
            rule, changes, activations, day(2026, 8, 19), EditScope.WHOLE_SERIES,
        )
        val updated = plan.updatedRules.firstOrNull()
        assertNotNull(updated)
        assertEquals(rule.prayerIDs, updated.prayerIDs)
    }

    // A successor is a new rule, so it starts offered in the library rather
    // than inheriting a decision made about the rule it replaced.
    @Test
    fun `a successor is not born hidden or archived`() {
        val (rule, activations) = fixture()
        val old = rule.copy(hiddenFromLibrary = true, archivedAt = java.time.Instant.now())
        val plan = planner.edit(
            old, old.copy(title = "Morning rule"), activations,
            day(2026, 8, 19), EditScope.THIS_AND_FUTURE,
        )
        val successor = plan.newRules.first()
        assertEquals(null, successor.hiddenFromLibrary)
        assertEquals(null, successor.archivedAt)
    }
}
