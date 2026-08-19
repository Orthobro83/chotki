import Foundation

/// Which occurrences an edit or deletion should affect.
///
/// Every change to a repeating rule asks this. Offering it from the start is
/// what makes the model hold: retrofitting `thisAndFuture` onto a schema that
/// assumed whole-series edits is a rewrite, not a patch.
public enum EditScope: String, Sendable, Hashable, Codable {
    /// Leaves the series alone and records a single deviation.
    case thisDay
    /// Ends the series here and starts a new one carrying the change, so the
    /// past keeps reporting what was actually kept at the time.
    case thisAndFuture
    /// Rewrites the rule everywhere, including in history.
    case wholeSeries
}

/// The mutations an edit implies. Pure data, so the whole three-way edit is
/// testable without a database.
public struct EditPlan: Sendable, Equatable {
    public var updatedRules: [Rule] = []
    public var newRules: [Rule] = []
    public var updatedActivations: [Activation] = []
    public var newActivations: [Activation] = []
    public var removedActivationIDs: [UUID] = []
    public var newOccurrences: [Occurrence] = []

    public var isEmpty: Bool {
        updatedRules.isEmpty && newRules.isEmpty && updatedActivations.isEmpty
            && newActivations.isEmpty && removedActivationIDs.isEmpty && newOccurrences.isEmpty
    }
}

public struct EditPlanner: Sendable {

    public init() {}

    /// Stop a rule, from `date` onwards or entirely.
    ///
    /// Nothing is ever destroyed. Deleting closes the activation and archives
    /// the rule, so every occurrence already kept stays in the record and the
    /// score does not move.
    public func delete(
        rule: Rule,
        activations: [Activation],
        on date: CalendarDate,
        scope: EditScope,
        now: Date = Date()
    ) -> EditPlan {
        var plan = EditPlan()
        let mine = activations.filter { $0.ruleID == rule.id }

        switch scope {
        case .thisDay:
            plan.newOccurrences.append(
                Occurrence(ruleID: rule.id, date: date, status: .cancelled)
            )

        case .thisAndFuture:
            plan.merge(closing: mine, at: date)

        case .wholeSeries:
            plan.merge(closing: mine, at: date)
            var archived = rule
            archived.archivedAt = now
            plan.updatedRules.append(archived)
        }
        return plan
    }

    /// Apply `changes` — a copy of `rule` with fields altered — at `date`.
    public func edit(
        rule: Rule,
        changes: Rule,
        activations: [Activation],
        on date: CalendarDate,
        scope: EditScope
    ) -> EditPlan {
        var plan = EditPlan()
        let mine = activations.filter { $0.ruleID == rule.id }

        switch scope {
        case .wholeSeries:
            var updated = changes
            updated.archivedAt = rule.archivedAt
            plan.updatedRules.append(updated)

        case .thisAndFuture:
            // End the old series the day before, and start a fresh rule
            // carrying the change. History keeps reporting the old shape,
            // which is the point.
            plan.merge(closing: mine, at: date)
            let successor = Rule(
                title: changes.title,
                note: changes.note,
                source: changes.source,
                recurrence: changes.recurrence,
                timeOfDay: changes.timeOfDay,
                category: changes.category,
                createdAt: rule.createdAt
            )
            plan.newRules.append(successor)
            plan.newActivations.append(Activation(ruleID: successor.id, from: date))

        case .thisDay:
            // Cancel the original for that day and stand a one-off in its place.
            plan.newOccurrences.append(
                Occurrence(ruleID: rule.id, date: date, status: .cancelled)
            )
            let oneOff = Rule(
                title: changes.title,
                note: changes.note,
                source: changes.source,
                recurrence: .once(date),
                timeOfDay: changes.timeOfDay,
                category: changes.category
            )
            plan.newRules.append(oneOff)
            plan.newActivations.append(Activation(ruleID: oneOff.id, from: date, to: date))
        }
        return plan
    }

    /// Pause a rule as of `date`, inclusive — the day it is paused still counts,
    /// which is what someone means when they stand down in the evening.
    public func pause(rule: Rule, activations: [Activation], on date: CalendarDate) -> EditPlan {
        var plan = EditPlan()
        for activation in activations where activation.ruleID == rule.id && activation.isOpen {
            var closed = activation
            closed.to = date
            plan.updatedActivations.append(closed)
        }
        return plan
    }

    /// Resume from `date`, opening a fresh stretch. The gap between is neither
    /// kept nor missed — it simply is not scored.
    public func resume(rule: Rule, on date: CalendarDate) -> EditPlan {
        var plan = EditPlan()
        plan.newActivations.append(Activation(ruleID: rule.id, from: date))
        return plan
    }
}

private extension EditPlan {
    /// Close every stretch at `date`, so nothing on or after it is due.
    mutating func merge(closing activations: [Activation], at date: CalendarDate) {
        let dayBefore = date.adding(days: -1)
        for activation in activations {
            if activation.from >= date {
                // Never started; closing it would produce a backwards range.
                removedActivationIDs.append(activation.id)
            } else if activation.covers(date) || activation.isOpen {
                var closed = activation
                closed.to = dayBefore
                updatedActivations.append(closed)
            }
        }
    }
}
