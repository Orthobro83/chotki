import Testing
import Foundation
@testable import ChotkiCore

@Suite("Atomic SQLite restore")
struct AtomicBackupTests {
    private let date = CalendarDate(year: 2026, month: 10, day: 3)!
    private let instant = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("failed merge rolls back new rules, overwritten rules and earlier activations")
    func failedMerge() throws {
        // Exercise the Store witness used by the shared JSON restore helper.
        let store: any Store = try SQLiteStore.inMemory()
        let held = Rule(title: "Held rule", recurrence: .daily, createdAt: instant)
        try store.save(held)
        try store.saveSettings(.default)
        let added = Rule(title: "Imported rule", recurrence: .daily, createdAt: instant)
        var overwritten = held
        overwritten.title = "Overwritten before failure"
        let valid = Activation(ruleID: added.id, from: date)
        let dangling = Activation(ruleID: UUID(), from: date)
        let backup = Backup(exportedAt: instant, rules: [overwritten, added],
                            activations: [valid, dangling], occurrences: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        #expect(throws: (any Error).self) { try store.importJSON(encoder.encode(backup)) }
        #expect(try store.rule(id: held.id) == held)
        #expect(try store.rule(id: added.id) == nil)
        #expect(try store.activations(ruleID: nil).isEmpty)
        #expect(try store.loadSettings() == .default)
        // Rollback must release both the transaction and its lock for later writes.
        try store.importBackup(Backup(exportedAt: instant, rules: [added], activations: [valid], occurrences: []))
        #expect(try store.rule(id: added.id) == added)
        #expect(try store.activations(ruleID: nil) == [valid])
    }

    @Test("a failed occurrence write also rolls back successful earlier writes")
    func failedOccurrence() throws {
        let store = try SQLiteStore.inMemory()
        let rule = Rule(title: "Restore candidate", recurrence: .daily, createdAt: instant)
        let backup = Backup(exportedAt: instant, rules: [rule],
                            activations: [Activation(ruleID: rule.id, from: date)],
                            occurrences: [Occurrence(ruleID: UUID(), date: date, status: .completed)])
        #expect(throws: (any Error).self) { try store.importBackup(backup) }
        #expect(try store.rules(includeArchived: true).isEmpty)
        #expect(try store.activations(ruleID: nil).isEmpty)
        #expect(try store.occurrences(ruleID: nil, from: nil, through: nil).isEmpty)
    }

    @Test("failed scoped edits keep their original rule and activation")
    func failedEdit() throws {
        let store = try SQLiteStore.inMemory()
        let rule = Rule(title: "Original", recurrence: .daily, createdAt: instant)
        let activation = Activation(ruleID: rule.id, from: date)
        try store.save(rule); try store.save(activation)
        var revised = rule
        revised.title = "Revised"
        var closed = activation
        closed.to = date
        var plan = EditPlan()
        plan.updatedRules = [revised]
        plan.updatedActivations = [closed]
        plan.newActivations = [Activation(ruleID: UUID(), from: date)]
        #expect(throws: (any Error).self) { try store.apply(plan) }
        #expect(try store.rule(id: rule.id) == rule)
        #expect(try store.activations(ruleID: nil) == [activation])
    }
}
