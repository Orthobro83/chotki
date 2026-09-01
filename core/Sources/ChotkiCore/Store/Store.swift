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
    /// Returns a day to having no record at all.
    ///
    /// Absence is the default state — due, or missed once its moment has passed
    /// — so restoring absence needs a real delete. Writing `.skipped` instead
    /// would quietly remove the day from scoring, which is a different thing
    /// entirely and not what un-ticking a box means.
    func removeOccurrence(ruleID: UUID, date: CalendarDate) throws

    func apply(_ plan: EditPlan) throws

    func saveLiturgicalDay(_ day: LiturgicalDay) throws
    func liturgicalDay(civilDate: CalendarDate, reckoning: Reckoning) throws -> LiturgicalDay?
    func liturgicalDays(reckoning: Reckoning, from: CalendarDate, through: CalendarDate) throws -> [LiturgicalDay]
    /// Passing nil clears every reckoning.
    func clearLiturgicalCache(reckoning: Reckoning?) throws

    /// Settings live beside the data rather than in a platform preferences
    /// system, so what someone has chosen travels with their record, survives a
    /// move between machines, and is included in a backup.
    func loadSettings() throws -> AppSettings?
    func saveSettings(_ settings: AppSettings) throws

    /// The seven reflections, in weekday order. Seeded by `seedReflections()`.
    func reflections() throws -> [Reflection]
    /// Upserts by weekday. There is one per weekday and there always will be.
    func save(_ reflection: Reflection) throws

    /// Answers, newest first. Passing nil for a bound leaves it open.
    func reflectionEntries(
        weekday: Weekday?, from: CalendarDate?, through: CalendarDate?
    ) throws -> [ReflectionEntry]

    /// Writes an answer.
    ///
    /// This upserts on (weekday, date) because a store must be able to restore
    /// a backup verbatim. The rule that an answer **locks once saved** is
    /// enforced above the store, by `ReflectionJournal.hasEntry` and by
    /// `ReflectionEntry` having no mutable field — not here, where a restore
    /// would be indistinguishable from an edit.
    func save(_ entry: ReflectionEntry) throws
}

public extension Store {
    /// Puts the bundled wording in place for any weekday that has none.
    ///
    /// Idempotent, and safe to call on every launch: it fills gaps and never
    /// overwrites, so a question the user has edited survives it. Done here
    /// rather than in a SQL migration so the text lives in exactly one place
    /// and both store implementations behave identically.
    @discardableResult
    func seedReflections() throws -> [Reflection] {
        let held = Set(try reflections().map(\.weekday))
        let missing = Reflection.bundled.filter { !held.contains($0.weekday) }
        for reflection in missing { try save(reflection) }
        return missing
    }

    /// The reflection for one weekday, seeding first if the record is empty.
    func reflection(for weekday: Weekday) throws -> Reflection {
        if let found = try reflections().first(where: { $0.weekday == weekday }) { return found }
        try seedReflections()
        return try reflections().first { $0.weekday == weekday } ?? .bundled(for: weekday)
    }

    func exportReflections(now: Date = Date()) throws -> ReflectionArchive {
        ReflectionArchive(
            exportedAt: now,
            reflections: try reflections(),
            entries: try reflectionEntries(weekday: nil, from: nil, through: nil)
        )
    }

    func exportReflectionsJSON(now: Date = Date()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(try exportReflections(now: now))
    }

    /// Merges a journal file in. Never discards what is already held.
    @discardableResult
    func importReflections(_ archive: ReflectionArchive) throws -> ReflectionImportResult {
        let existing = try reflectionEntries(weekday: nil, from: nil, through: nil)
        let result = ReflectionImport.plan(archive, into: existing)
        for entry in result.added { try save(entry) }
        // Questions are restored only where this record has none, so an import
        // cannot rewrite wording the user has since edited.
        let held = Set(try reflections().map(\.weekday))
        for reflection in archive.reflections where !held.contains(reflection.weekday) {
            try save(reflection)
        }
        return result
    }

    @discardableResult
    func importReflectionsJSON(_ data: Data, now: Date = Date()) throws -> ReflectionImportResult {
        try importReflections(try ReflectionImport.read(data, now: now))
    }
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
    /// Optional, so a backup written before settings moved here still restores.
    public var settings: AppSettings?
    /// Optional, so a backup written before Reflections existed still restores.
    public var reflections: [Reflection]?
    public var reflectionEntries: [ReflectionEntry]?

    public init(
        exportedAt: Date = Date(), rules: [Rule], activations: [Activation],
        occurrences: [Occurrence], settings: AppSettings? = nil,
        reflections: [Reflection]? = nil, reflectionEntries: [ReflectionEntry]? = nil
    ) {
        self.exportedAt = exportedAt
        self.rules = rules
        self.activations = activations
        self.occurrences = occurrences
        self.settings = settings
        self.reflections = reflections
        self.reflectionEntries = reflectionEntries
    }
}

public extension Store {
    func exportBackup(now: Date = Date()) throws -> Backup {
        Backup(
            exportedAt: now,
            rules: try rules(includeArchived: true),
            activations: try activations(ruleID: nil),
            occurrences: try occurrences(ruleID: nil, from: nil, through: nil),
            settings: try loadSettings(),
            reflections: try reflections(),
            reflectionEntries: try reflectionEntries(weekday: nil, from: nil, through: nil)
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
        if let settings = backup.settings { try saveSettings(settings) }
        for reflection in backup.reflections ?? [] { try save(reflection) }
        for entry in backup.reflectionEntries ?? [] { try save(entry) }
    }

    func importJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try importBackup(try decoder.decode(Backup.self, from: data))
    }
}
