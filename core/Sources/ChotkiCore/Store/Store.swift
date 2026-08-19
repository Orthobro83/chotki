import Foundation

public enum StoreError: Error, Sendable {
    case open(String)
    case query(String)
    case notFound
}

/// Persistence, kept behind a protocol so the semantics above never depend on it.
///
/// `apply(_:)` exists so a three-way edit lands atomically — a split that closed
/// the old stretch but failed to open the new one would make a rule silently
/// vanish.
public protocol Store: Sendable {
    func save(_ rule: Rule) throws
    func rule(id: UUID) throws -> Rule?
    func rules(includeArchived: Bool) throws -> [Rule]

    func save(_ activation: Activation) throws
    func removeActivation(id: UUID) throws
    func activations(ruleID: UUID?) throws -> [Activation]

    func save(_ occurrence: Occurrence) throws
    func occurrences(ruleID: UUID?, from: CalendarDate?, through: CalendarDate?) throws -> [Occurrence]

    func apply(_ plan: EditPlan) throws
}

public extension Store {
    /// Non-atomic fallback. `SQLiteStore` overrides this with a transaction.
    func apply(_ plan: EditPlan) throws {
        for rule in plan.updatedRules + plan.newRules { try save(rule) }
        for activation in plan.updatedActivations + plan.newActivations { try save(activation) }
        for id in plan.removedActivationIDs { try removeActivation(id: id) }
        for occurrence in plan.newOccurrences { try save(occurrence) }
    }
}

/// A portable snapshot of everything, for backup and for moving between machines.
/// Deliberately plain JSON: the record of what someone kept should outlive this
/// application.
public struct Backup: Sendable, Codable {
    public var version: Int = 1
    public var exportedAt: Date
    public var rules: [Rule]
    public var activations: [Activation]
    public var occurrences: [Occurrence]

    public init(exportedAt: Date = Date(), rules: [Rule], activations: [Activation], occurrences: [Occurrence]) {
        self.exportedAt = exportedAt
        self.rules = rules
        self.activations = activations
        self.occurrences = occurrences
    }
}

public extension Store {
    func exportBackup(now: Date = Date()) throws -> Backup {
        Backup(
            exportedAt: now,
            rules: try rules(includeArchived: true),
            activations: try activations(ruleID: nil),
            occurrences: try occurrences(ruleID: nil, from: nil, through: nil)
        )
    }

    func exportJSON(now: Date = Date()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(try exportBackup(now: now))
    }

    func importBackup(_ backup: Backup) throws {
        for rule in backup.rules { try save(rule) }
        for activation in backup.activations { try save(activation) }
        for occurrence in backup.occurrences { try save(occurrence) }
    }

    func importJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try importBackup(try decoder.decode(Backup.self, from: data))
    }
}
