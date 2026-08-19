import Foundation

/// Used by the test suite and by anything that wants the semantics without a file.
/// Every behaviour test runs against this and against `SQLiteStore`, so the two
/// cannot drift.
public final class InMemoryStore: Store, @unchecked Sendable {
    private let lock = NSLock()
    private var ruleByID: [UUID: Rule] = [:]
    private var activationByID: [UUID: Activation] = [:]
    /// Keyed by rule and day: at most one deviation per rule per day.
    private var occurrenceByKey: [String: Occurrence] = [:]
    /// Keyed by civil date and reckoning — never by the reported date.
    private var liturgicalByKey: [String: LiturgicalDay] = [:]

    public init() {}

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    public func save(_ rule: Rule) throws {
        locked { ruleByID[rule.id] = rule }
    }

    public func rule(id: UUID) throws -> Rule? {
        locked { ruleByID[id] }
    }

    public func rules(includeArchived: Bool) throws -> [Rule] {
        locked {
            ruleByID.values
                .filter { includeArchived || !$0.isArchived }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    public func save(_ activation: Activation) throws {
        locked { activationByID[activation.id] = activation }
    }

    public func removeActivation(id: UUID) throws {
        _ = locked { activationByID.removeValue(forKey: id) }
    }

    public func activations(ruleID: UUID?) throws -> [Activation] {
        locked {
            activationByID.values
                .filter { ruleID == nil || $0.ruleID == ruleID! }
                .sorted { $0.from < $1.from }
        }
    }

    public func save(_ occurrence: Occurrence) throws {
        locked { occurrenceByKey["\(occurrence.ruleID):\(occurrence.date.iso)"] = occurrence }
    }

    public func saveLiturgicalDay(_ day: LiturgicalDay) throws {
        locked { liturgicalByKey["\(day.reckoning.rawValue):\(day.civilDate.iso)"] = day }
    }

    public func liturgicalDay(civilDate: CalendarDate, reckoning: Reckoning) throws -> LiturgicalDay? {
        locked { liturgicalByKey["\(reckoning.rawValue):\(civilDate.iso)"] }
    }

    public func liturgicalDays(
        reckoning: Reckoning, from: CalendarDate, through: CalendarDate
    ) throws -> [LiturgicalDay] {
        locked {
            liturgicalByKey.values
                .filter { $0.reckoning == reckoning && $0.civilDate >= from && $0.civilDate <= through }
                .sorted { $0.civilDate < $1.civilDate }
        }
    }

    public func clearLiturgicalCache(reckoning: Reckoning?) throws {
        locked {
            guard let reckoning else { liturgicalByKey.removeAll(); return }
            liturgicalByKey = liturgicalByKey.filter { $0.value.reckoning != reckoning }
        }
    }

    public func occurrences(
        ruleID: UUID?, from: CalendarDate?, through: CalendarDate?
    ) throws -> [Occurrence] {
        locked {
            occurrenceByKey.values
                .filter { ruleID == nil || $0.ruleID == ruleID! }
                .filter { from == nil || $0.date >= from! }
                .filter { through == nil || $0.date <= through! }
                .sorted { ($0.date, $0.ruleID.uuidString) < ($1.date, $1.ruleID.uuidString) }
        }
    }
}
