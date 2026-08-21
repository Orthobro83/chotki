import Foundation
import CSQLite

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite persistence over the C API directly.
///
/// Enums with associated values (`Recurrence`) are stored as JSON text. They are
/// never queried on, only read back whole, so a column per case would buy
/// nothing and cost a migration every time a recurrence kind is added.
///
/// Dates are stored as `YYYY-MM-DD` text, which sorts lexicographically — SQLite
/// can range-scan them with no date handling of its own, and the file stays
/// readable by anything.
public final class SQLiteStore: Store, @unchecked Sendable {

    private var db: OpaquePointer?
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(path: String) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            throw StoreError.open(String(cString: sqlite3_errmsg(handle)))
        }
        self.db = handle
        try exec("PRAGMA journal_mode = WAL;")
        try exec("PRAGMA foreign_keys = ON;")
        try migrate()
    }

    /// A private database that never touches disk. Used by the test suite.
    public static func inMemory() throws -> SQLiteStore {
        try SQLiteStore(path: ":memory:")
    }

    deinit { if let db { sqlite3_close_v2(db) } }

    // MARK: raw helpers

    /// Internal rather than private so tests can build a historical schema and
    /// prove the migration path, which a fresh database never exercises.
    func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw StoreError.query("\(message) — while running: \(sql)")
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw StoreError.query(String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private func bind(_ statement: OpaquePointer, _ values: [String?]) {
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            if let value {
                sqlite3_bind_text(statement, position, value, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, position)
            }
        }
    }

    private func run(_ sql: String, _ values: [String?]) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, values)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.query(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(_ sql: String, _ values: [String?], _ row: (OpaquePointer) throws -> T?) throws -> [T] {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        bind(statement, values)
        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = try row(statement) { results.append(value) }
        }
        return results
    }

    private func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: pointer)
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    // MARK: schema

    private func migrate() throws {
        try exec("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL);")
        let versions: [Int] = try query("SELECT version FROM schema_version;", []) {
            Int(sqlite3_column_int(($0), 0))
        }
        let current = versions.max() ?? 0

        if current < 1 {
            try exec("""
                CREATE TABLE rule (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    note TEXT,
                    source TEXT,
                    recurrence TEXT NOT NULL,
                    time_of_day TEXT,
                    category TEXT,
                    created_at TEXT NOT NULL,
                    archived_at TEXT
                );

                CREATE TABLE activation (
                    id TEXT PRIMARY KEY,
                    rule_id TEXT NOT NULL REFERENCES rule(id) ON DELETE CASCADE,
                    from_date TEXT NOT NULL,
                    to_date TEXT
                );
                CREATE INDEX activation_by_rule ON activation(rule_id);

                -- One deviation per rule per day. The unique constraint is the
                -- model's rule made structural: a day cannot be both completed
                -- and skipped.
                CREATE TABLE occurrence (
                    id TEXT PRIMARY KEY,
                    rule_id TEXT NOT NULL REFERENCES rule(id) ON DELETE CASCADE,
                    date TEXT NOT NULL,
                    status TEXT NOT NULL,
                    completed_at TEXT,
                    moved_to TEXT,
                    UNIQUE(rule_id, date)
                );
                CREATE INDEX occurrence_by_date ON occurrence(date);

                INSERT INTO schema_version (version) VALUES (1);
                """)
        }

        if current < 2 {
            // Keyed by CIVIL date. The API answers a civil request with the
            // date in the requested reckoning, so keying on what it reports
            // would misfile every Old Calendar day by thirteen days.
            try exec("""
                CREATE TABLE liturgical_day (
                    civil_date TEXT NOT NULL,
                    reckoning TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    fetched_at TEXT NOT NULL,
                    PRIMARY KEY (civil_date, reckoning)
                );
                INSERT INTO schema_version (version) VALUES (2);
                """)
        }

        if current < 3 {
            // Per-rule reminder settings. Nullable, so rules written before this
            // existed keep working and fall back to the default.
            try exec("""
                ALTER TABLE rule ADD COLUMN reminders TEXT;
                INSERT INTO schema_version (version) VALUES (3);
                """)
        }

        if current < 4 {
            // Settings, kept beside the data. They were previously in
            // UserDefaults, where they were not persisting at all — and where
            // they would not have travelled with a backup or to another
            // platform even if they had.
            try exec("""
                CREATE TABLE app_settings (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    payload TEXT NOT NULL
                );
                INSERT INTO schema_version (version) VALUES (4);
                """)
        }

        if current < 5 {
            // The prayers a rule carries. Nullable, so rules written before
            // this existed keep working.
            try exec("""
                ALTER TABLE rule ADD COLUMN prayer_ids TEXT;
                INSERT INTO schema_version (version) VALUES (5);
                """)
        }
    }

    // MARK: liturgical cache

    public func saveLiturgicalDay(_ day: LiturgicalDay) throws {
        try locked {
            guard let payload = try encodeJSON(day) else { throw StoreError.query("encode failed") }
            try run("""
                INSERT INTO liturgical_day (civil_date, reckoning, payload, fetched_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(civil_date, reckoning) DO UPDATE SET
                    payload = excluded.payload, fetched_at = excluded.fetched_at;
                """, [day.civilDate.iso, day.reckoning.rawValue, payload, encode(day.fetchedAt)])
        }
    }

    public func liturgicalDay(civilDate: CalendarDate, reckoning: Reckoning) throws -> LiturgicalDay? {
        try locked {
            try query(
                "SELECT payload FROM liturgical_day WHERE civil_date = ? AND reckoning = ?;",
                [civilDate.iso, reckoning.rawValue]
            ) { try decodeJSON(LiturgicalDay.self, text($0, 0)) }.first
        }
    }

    public func liturgicalDays(
        reckoning: Reckoning, from: CalendarDate, through: CalendarDate
    ) throws -> [LiturgicalDay] {
        try locked {
            try query("""
                SELECT payload FROM liturgical_day
                WHERE reckoning = ? AND civil_date >= ? AND civil_date <= ?
                ORDER BY civil_date;
                """, [reckoning.rawValue, from.iso, through.iso]) {
                try decodeJSON(LiturgicalDay.self, text($0, 0))
            }
        }
    }

    public func clearLiturgicalCache(reckoning: Reckoning?) throws {
        try locked {
            if let reckoning {
                try run("DELETE FROM liturgical_day WHERE reckoning = ?;", [reckoning.rawValue])
            } else {
                try run("DELETE FROM liturgical_day;", [])
            }
        }
    }

    // MARK: coding helpers

    private func encodeJSON<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        return String(data: try encoder.encode(value), encoding: .utf8)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, _ string: String?) throws -> T? {
        guard let string, let data = string.data(using: .utf8) else { return nil }
        return try decoder.decode(type, from: data)
    }

    /// An instance rather than a shared static: every call site runs inside
    /// `locked`, so the formatter is never touched from two threads at once.
    private let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func encode(_ date: Date?) -> String? { date.map { stamp.string(from: $0) } }
    private func decode(_ string: String?) -> Date? { string.flatMap { stamp.date(from: $0) } }

    // MARK: rules

    public func save(_ rule: Rule) throws {
        try locked {
            try run("""
                INSERT INTO rule (id, title, note, source, recurrence, time_of_day, category, created_at, archived_at, reminders, prayer_ids)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    title = excluded.title, note = excluded.note, source = excluded.source,
                    recurrence = excluded.recurrence, time_of_day = excluded.time_of_day,
                    category = excluded.category, archived_at = excluded.archived_at,
                    reminders = excluded.reminders, prayer_ids = excluded.prayer_ids;
                """, [
                    rule.id.uuidString, rule.title, rule.note, rule.source,
                    try encodeJSON(rule.recurrence), try encodeJSON(rule.timeOfDay),
                    rule.category, encode(rule.createdAt), encode(rule.archivedAt),
                    try encodeJSON(rule.reminders), try encodeJSON(rule.prayerIDs)
                ])
        }
    }

    private func decodeRule(_ s: OpaquePointer) throws -> Rule? {
        guard let id = text(s, 0).flatMap(UUID.init(uuidString:)),
              let title = text(s, 1),
              let recurrence = try decodeJSON(Recurrence.self, text(s, 4)),
              let createdAt = decode(text(s, 7))
        else { return nil }
        return Rule(
            id: id, title: title, note: text(s, 2), source: text(s, 3),
            recurrence: recurrence,
            timeOfDay: try decodeJSON(TimeOfDay.self, text(s, 5)),
            category: text(s, 6),
            reminders: try decodeJSON(RuleReminders.self, text(s, 9)),
            prayerIDs: try decodeJSON([String].self, text(s, 10)),
            createdAt: createdAt, archivedAt: decode(text(s, 8))
        )
    }

    private static let ruleColumns =
        "id, title, note, source, recurrence, time_of_day, category, created_at, archived_at, reminders, prayer_ids"

    public func rule(id: UUID) throws -> Rule? {
        try locked {
            try query("SELECT \(Self.ruleColumns) FROM rule WHERE id = ?;", [id.uuidString]) {
                try decodeRule($0)
            }.first
        }
    }

    public func rules(includeArchived: Bool) throws -> [Rule] {
        let filter = includeArchived ? "" : "WHERE archived_at IS NULL"
        return try locked {
            try query("SELECT \(Self.ruleColumns) FROM rule \(filter) ORDER BY created_at;", []) {
                try decodeRule($0)
            }
        }
    }

    // MARK: activations

    public func save(_ activation: Activation) throws {
        try locked {
            try run("""
                INSERT INTO activation (id, rule_id, from_date, to_date) VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET from_date = excluded.from_date, to_date = excluded.to_date;
                """, [
                    activation.id.uuidString, activation.ruleID.uuidString,
                    activation.from.iso, activation.to?.iso
                ])
        }
    }

    public func removeActivation(id: UUID) throws {
        try locked { try run("DELETE FROM activation WHERE id = ?;", [id.uuidString]) }
    }

    public func activations(ruleID: UUID?) throws -> [Activation] {
        let filter = ruleID == nil ? "" : "WHERE rule_id = ?"
        let values = ruleID.map { [$0.uuidString] } ?? []
        return try locked {
            try query("SELECT id, rule_id, from_date, to_date FROM activation \(filter) ORDER BY from_date;", values) { s in
                guard let id = text(s, 0).flatMap(UUID.init(uuidString:)),
                      let ruleID = text(s, 1).flatMap(UUID.init(uuidString:)),
                      let from = text(s, 2).flatMap(CalendarDate.init(iso:))
                else { return nil }
                return Activation(id: id, ruleID: ruleID, from: from,
                                  to: text(s, 3).flatMap(CalendarDate.init(iso:)))
            }
        }
    }

    // MARK: occurrences

    public func save(_ occurrence: Occurrence) throws {
        try locked {
            try run("""
                INSERT INTO occurrence (id, rule_id, date, status, completed_at, moved_to)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(rule_id, date) DO UPDATE SET
                    status = excluded.status, completed_at = excluded.completed_at,
                    moved_to = excluded.moved_to;
                """, [
                    occurrence.id.uuidString, occurrence.ruleID.uuidString, occurrence.date.iso,
                    occurrence.status.rawValue, encode(occurrence.completedAt), occurrence.movedTo?.iso
                ])
        }
    }

    public func occurrences(
        ruleID: UUID?, from: CalendarDate?, through: CalendarDate?
    ) throws -> [Occurrence] {
        var clauses: [String] = []
        var values: [String?] = []
        if let ruleID { clauses.append("rule_id = ?"); values.append(ruleID.uuidString) }
        if let from { clauses.append("date >= ?"); values.append(from.iso) }
        if let through { clauses.append("date <= ?"); values.append(through.iso) }
        let filter = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")

        return try locked {
            try query("""
                SELECT id, rule_id, date, status, completed_at, moved_to
                FROM occurrence \(filter) ORDER BY date, rule_id;
                """, values) { s in
                guard let id = text(s, 0).flatMap(UUID.init(uuidString:)),
                      let ruleID = text(s, 1).flatMap(UUID.init(uuidString:)),
                      let date = text(s, 2).flatMap(CalendarDate.init(iso:)),
                      let status = text(s, 3).flatMap(OccurrenceStatus.init(rawValue:))
                else { return nil }
                return Occurrence(id: id, ruleID: ruleID, date: date, status: status,
                                  completedAt: decode(text(s, 4)),
                                  movedTo: text(s, 5).flatMap(CalendarDate.init(iso:)))
            }
        }
    }

    public func removeOccurrence(ruleID: UUID, date: CalendarDate) throws {
        try locked {
            try run("DELETE FROM occurrence WHERE rule_id = ? AND date = ?;",
                    [ruleID.uuidString, date.iso])
        }
    }

    // MARK: settings

    public func loadSettings() throws -> AppSettings? {
        try locked {
            let rows: [AppSettings] = try query("SELECT payload FROM app_settings WHERE id = 1;", []) { s in
                try decodeJSON(AppSettings.self, text(s, 0))
            }
            return rows.first
        }
    }

    public func saveSettings(_ settings: AppSettings) throws {
        try locked {
            try run("""
                INSERT INTO app_settings (id, payload) VALUES (1, ?)
                ON CONFLICT(id) DO UPDATE SET payload = excluded.payload;
                """, [try encodeJSON(settings)])
        }
    }

    // MARK: atomic edits

    /// A split that closed the old stretch but failed to open the new one would
    /// make a rule silently disappear. All of it lands, or none of it does.
    public func apply(_ plan: EditPlan) throws {
        try locked { try exec("BEGIN IMMEDIATE;") }
        do {
            for rule in plan.updatedRules + plan.newRules { try save(rule) }
            for activation in plan.updatedActivations + plan.newActivations { try save(activation) }
            for id in plan.removedActivationIDs { try removeActivation(id: id) }
            for occurrence in plan.newOccurrences { try save(occurrence) }
            try locked { try exec("COMMIT;") }
        } catch {
            try? locked { try exec("ROLLBACK;") }
            throw error
        }
    }
}
