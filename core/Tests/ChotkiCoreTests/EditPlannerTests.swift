import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

@Suite("The three-way edit")
struct EditPlannerTests {
    let planner = EditPlanner()
    let engine = RecurrenceEngine()

    private func fixture() -> (Rule, [Activation]) {
        let rule = Rule(
            title: "Evening prayers",
            recurrence: .daily,
            timeOfDay: TimeOfDay(hour: 21, minute: 30)
        )
        return (rule, [Activation(ruleID: rule.id, from: d(2026, 3, 1))])
    }

    // MARK: deleting

    @Test("deleting one day records a single exception and leaves the series alone")
    func deleteThisDay() {
        let (rule, activations) = fixture()
        let plan = planner.delete(
            rule: rule, activations: activations, on: d(2026, 8, 19), scope: .thisDay
        )
        #expect(plan.newOccurrences.count == 1)
        #expect(plan.newOccurrences[0].status == .cancelled)
        #expect(plan.newOccurrences[0].date == d(2026, 8, 19))
        #expect(plan.updatedActivations.isEmpty, "the series is untouched")
        #expect(plan.updatedRules.isEmpty)
    }

    @Test("deleting this and future closes the stretch the day before")
    func deleteThisAndFuture() {
        let (rule, activations) = fixture()
        let plan = planner.delete(
            rule: rule, activations: activations, on: d(2026, 8, 19), scope: .thisAndFuture
        )
        #expect(plan.updatedActivations.count == 1)
        #expect(plan.updatedActivations[0].to == d(2026, 8, 18))
        #expect(plan.updatedRules.isEmpty, "the rule itself is not archived")

        // Nothing on or after the deletion day is due; everything before survives.
        let due = engine.dueDates(
            rule: rule, activations: plan.updatedActivations,
            from: d(2026, 3, 1), through: d(2026, 12, 31)
        )
        #expect(due.last == d(2026, 8, 18))
        #expect(!due.contains(d(2026, 8, 19)))
        #expect(due.contains(d(2026, 3, 1)), "history is intact")
    }

    @Test("deleting the whole series archives the rule but keeps its history")
    func deleteWholeSeries() {
        let (rule, activations) = fixture()
        let plan = planner.delete(
            rule: rule, activations: activations, on: d(2026, 8, 19), scope: .wholeSeries
        )
        #expect(plan.updatedRules.count == 1)
        #expect(plan.updatedRules[0].isArchived)
        #expect(plan.updatedRules[0].id == rule.id, "archived, not replaced")
        #expect(plan.updatedActivations[0].to == d(2026, 8, 18))
    }

    // Closing a stretch that has not started yet would produce `to` before
    // `from` — a silently broken range that would make the rule due forever.
    @Test("deleting before a stretch begins removes it instead of inverting it")
    func deleteBeforeActivationStarts() {
        let rule = Rule(title: "Later rule", recurrence: .daily)
        let future = Activation(ruleID: rule.id, from: d(2026, 9, 1))
        let plan = planner.delete(
            rule: rule, activations: [future], on: d(2026, 8, 19), scope: .thisAndFuture
        )
        #expect(plan.removedActivationIDs == [future.id])
        #expect(plan.updatedActivations.isEmpty)
    }

    // MARK: editing

    @Test("editing the whole series rewrites the rule in place")
    func editWholeSeries() {
        let (rule, activations) = fixture()
        var changes = rule
        changes.timeOfDay = TimeOfDay(hour: 22, minute: 0)
        let plan = planner.edit(
            rule: rule, changes: changes, activations: activations,
            on: d(2026, 8, 19), scope: .wholeSeries
        )
        #expect(plan.updatedRules.count == 1)
        #expect(plan.updatedRules[0].id == rule.id)
        #expect(plan.updatedRules[0].timeOfDay == TimeOfDay(hour: 22, minute: 0))
        #expect(plan.newRules.isEmpty)
    }

    @Test("editing this and future splits into two series with no gap and no overlap")
    func editThisAndFuture() throws {
        let (rule, activations) = fixture()
        var changes = rule
        changes.timeOfDay = TimeOfDay(hour: 22, minute: 0)
        let split = d(2026, 8, 19)
        let plan = planner.edit(
            rule: rule, changes: changes, activations: activations,
            on: split, scope: .thisAndFuture
        )

        let successor = try #require(plan.newRules.first)
        #expect(successor.id != rule.id, "a new series, so history keeps the old shape")
        #expect(successor.timeOfDay == TimeOfDay(hour: 22, minute: 0))
        #expect(plan.updatedActivations[0].to == d(2026, 8, 18))
        #expect(plan.newActivations[0].from == split)

        let oldDue = engine.dueDates(
            rule: rule, activations: plan.updatedActivations,
            from: d(2026, 3, 1), through: d(2026, 12, 31)
        )
        let newDue = engine.dueDates(
            rule: successor, activations: plan.newActivations,
            from: d(2026, 3, 1), through: d(2026, 12, 31)
        )
        #expect(oldDue.last == d(2026, 8, 18))
        #expect(newDue.first == split)
        #expect(Set(oldDue).isDisjoint(with: Set(newDue)), "no day is due twice")
        #expect(oldDue.count + newDue.count == 306, "and no day between March and December is lost")
    }

    @Test("editing one day cancels the original and stands a one-off in its place")
    func editThisDay() throws {
        let (rule, activations) = fixture()
        var changes = rule
        changes.timeOfDay = TimeOfDay(hour: 18, minute: 0)
        let day = d(2026, 8, 19)
        let plan = planner.edit(
            rule: rule, changes: changes, activations: activations, on: day, scope: .thisDay
        )

        #expect(plan.newOccurrences.first?.status == .cancelled)
        #expect(plan.newOccurrences.first?.date == day)
        let oneOff = try #require(plan.newRules.first)
        #expect(oneOff.recurrence == .once(day))
        #expect(oneOff.timeOfDay == TimeOfDay(hour: 18, minute: 0))
        #expect(plan.updatedActivations.isEmpty, "the series continues unchanged")

        let oneOffDue = engine.dueDates(
            rule: oneOff, activations: plan.newActivations,
            from: d(2026, 1, 1), through: d(2026, 12, 31)
        )
        #expect(oneOffDue == [day], "the replacement exists on exactly one day")
    }

    // MARK: pausing

    @Test("pausing keeps the day it was paused on")
    func pauseIsInclusive() {
        let (rule, activations) = fixture()
        let plan = planner.pause(rule: rule, activations: activations, on: d(2026, 8, 19))
        #expect(plan.updatedActivations[0].to == d(2026, 8, 19))

        let due = engine.dueDates(
            rule: rule, activations: plan.updatedActivations,
            from: d(2026, 3, 1), through: d(2026, 12, 31)
        )
        #expect(due.last == d(2026, 8, 19), "standing down in the evening still counts that day")
    }

    @Test("resuming opens a fresh stretch and leaves the gap unscored")
    func resumeLeavesGapUnscored() {
        let (rule, activations) = fixture()
        let paused = planner.pause(rule: rule, activations: activations, on: d(2026, 5, 10))
        let resumed = planner.resume(rule: rule, on: d(2026, 6, 1))
        let all = paused.updatedActivations + resumed.newActivations

        let due = engine.dueDates(
            rule: rule, activations: all, from: d(2026, 3, 1), through: d(2026, 12, 31)
        )
        #expect(due.contains(d(2026, 5, 10)))
        #expect(!due.contains(d(2026, 5, 11)))
        #expect(!due.contains(d(2026, 5, 31)))
        #expect(due.contains(d(2026, 6, 1)))
        // The 21 days stood down are absent from the record entirely — neither
        // kept nor missed, which is the whole point of pausing.
        #expect(due.filter { $0 > d(2026, 5, 10) && $0 < d(2026, 6, 1) }.isEmpty)
    }
}
