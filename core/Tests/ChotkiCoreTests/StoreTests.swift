import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

enum StoreKind: String, Sendable, CaseIterable {
    case memory, sqlite

    func make() throws -> any Store {
        switch self {
        case .memory: return InMemoryStore()
        case .sqlite: return try SQLiteStore.inMemory()
        }
    }
}

/// Every behaviour runs against both implementations. Two stores that disagree
/// would mean the test suite is only checking one of them.
@Suite("Store")
struct StoreTests {

    @Test("a rule survives a round trip with every field intact", arguments: StoreKind.allCases)
    func ruleRoundTrip(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(
            title: "Jesus prayer",
            note: "Start with 50 knots and build up",
            source: "my godfather",
            recurrence: .weekly(days: [.wednesday, .friday]),
            timeOfDay: TimeOfDay(hour: 6, minute: 30),
            category: "prayer"
        )
        try store.save(rule)

        let loaded = try #require(try store.rule(id: rule.id))
        #expect(loaded.title == rule.title)
        #expect(loaded.note == rule.note)
        #expect(loaded.source == rule.source, "the origin of a rule must survive")
        #expect(loaded.recurrence == rule.recurrence)
        #expect(loaded.timeOfDay == rule.timeOfDay)
        #expect(loaded.category == rule.category)
    }

    @Test("every recurrence kind survives storage", arguments: StoreKind.allCases)
    func recurrenceKinds(kind: StoreKind) throws {
        let store = try kind.make()
        let kinds: [Recurrence] = [
            .daily,
            .once(d(2026, 8, 19)),
            .weekly(days: [.sunday]),
            .monthly(day: 31, whenShort: .lastDay),
            .monthly(day: 15, whenShort: .skip),
            .liturgical(.fastDay),
            .liturgical(.greatFeast),
            .liturgical(.season(.greatLent))
        ]
        for recurrence in kinds {
            let rule = Rule(title: "r", recurrence: recurrence)
            try store.save(rule)
            let loaded = try #require(try store.rule(id: rule.id))
            #expect(loaded.recurrence == recurrence, "\(recurrence) did not survive")
        }
    }

    @Test("archived rules are hidden by default but never lost", arguments: StoreKind.allCases)
    func archivedRules(kind: StoreKind) throws {
        let store = try kind.make()
        var rule = Rule(title: "Saturday Vespers", recurrence: .weekly(days: [.saturday]))
        try store.save(rule)
        rule.archivedAt = Date()
        try store.save(rule)

        #expect(try store.rules(includeArchived: false).isEmpty)
        #expect(try store.rules(includeArchived: true).count == 1)
        #expect(try store.rule(id: rule.id) != nil, "still retrievable by id")
    }

    @Test("activations update and remove", arguments: StoreKind.allCases)
    func activations(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(title: "Evening prayers", recurrence: .daily)
        try store.save(rule)

        var activation = Activation(ruleID: rule.id, from: d(2026, 3, 1))
        try store.save(activation)
        #expect(try store.activations(ruleID: rule.id).first?.to == nil)

        activation.to = d(2026, 5, 10)
        try store.save(activation)
        #expect(try store.activations(ruleID: rule.id).count == 1, "updated, not duplicated")
        #expect(try store.activations(ruleID: rule.id).first?.to == d(2026, 5, 10))

        try store.removeActivation(id: activation.id)
        #expect(try store.activations(ruleID: rule.id).isEmpty)
    }

    // A day cannot be both completed and skipped. The model says so; storage
    // must enforce it rather than accumulate contradictory rows.
    @Test("one occurrence per rule per day", arguments: StoreKind.allCases)
    func oneOccurrencePerDay(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(title: "Morning prayers", recurrence: .daily)
        try store.save(rule)
        let day = d(2026, 8, 19)

        try store.save(Occurrence(ruleID: rule.id, date: day, status: .completed))
        try store.save(Occurrence(ruleID: rule.id, date: day, status: .skipped))

        let all = try store.occurrences(ruleID: rule.id, from: nil, through: nil)
        #expect(all.count == 1, "the second save replaces rather than adds")
        #expect(all[0].status == .skipped)
    }

    @Test("occurrences filter by date range", arguments: StoreKind.allCases)
    func occurrenceRange(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(title: "Daily", recurrence: .daily)
        try store.save(rule)
        for day in 10...20 {
            try store.save(Occurrence(ruleID: rule.id, date: d(2026, 8, day), status: .completed))
        }
        let window = try store.occurrences(ruleID: nil, from: d(2026, 8, 14), through: d(2026, 8, 16))
        #expect(window.count == 3)
        #expect(window.first?.date == d(2026, 8, 14))
        #expect(window.last?.date == d(2026, 8, 16))
    }

    @Test("an edit plan applies as a unit", arguments: StoreKind.allCases)
    func applyPlan(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(title: "Evening prayers", recurrence: .daily)
        let activation = Activation(ruleID: rule.id, from: d(2026, 3, 1))
        try store.save(rule)
        try store.save(activation)

        let plan = EditPlanner().edit(
            rule: rule,
            changes: { var c = rule; c.timeOfDay = TimeOfDay(hour: 22, minute: 0); return c }(),
            activations: [activation],
            on: d(2026, 8, 19),
            scope: .thisAndFuture
        )
        try store.apply(plan)

        #expect(try store.rules(includeArchived: false).count == 2, "old series plus successor")
        let stretches = try store.activations(ruleID: nil)
        #expect(stretches.count == 2)
        #expect(stretches.contains { $0.to == d(2026, 8, 18) })
        #expect(stretches.contains { $0.from == d(2026, 8, 19) && $0.to == nil })
    }

    @Test("a backup round trips through JSON", arguments: StoreKind.allCases)
    func backupRoundTrip(kind: StoreKind) throws {
        let source = try kind.make()
        let rule = Rule(
            title: "Read the day's Gospel",
            source: "the parish bulletin",
            recurrence: .daily,
            timeOfDay: TimeOfDay(hour: 12, minute: 0)
        )
        try source.save(rule)
        try source.save(Activation(ruleID: rule.id, from: d(2026, 3, 1), to: d(2026, 5, 10)))
        try source.save(Occurrence(ruleID: rule.id, date: d(2026, 4, 2), status: .completedLate))

        let json = try source.exportJSON()

        let restored = try kind.make()
        try restored.importJSON(json)

        #expect(try restored.rules(includeArchived: true).count == 1)
        #expect(try restored.rule(id: rule.id)?.source == "the parish bulletin")
        #expect(try restored.activations(ruleID: rule.id).first?.to == d(2026, 5, 10))
        let occurrences = try restored.occurrences(ruleID: nil, from: nil, through: nil)
        #expect(occurrences.first?.status == .completedLate)
    }
}

@Suite("SQLite specifics")
struct SQLiteStoreTests {

    @Test("data survives closing and reopening the file")
    func persistsAcrossReopen() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-test-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        let rule = Rule(title: "Sunday Liturgy", recurrence: .weekly(days: [.sunday]))
        do {
            let store = try SQLiteStore(path: path)
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: d(2026, 3, 1)))
        }
        let reopened = try SQLiteStore(path: path)
        #expect(try reopened.rule(id: rule.id)?.title == "Sunday Liturgy")
        #expect(try reopened.activations(ruleID: rule.id).count == 1)
    }

    @Test("migrations are idempotent")
    func migrationsRunOnce() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-migrate-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        _ = try SQLiteStore(path: path)
        _ = try SQLiteStore(path: path)
        let third = try SQLiteStore(path: path)
        #expect(try third.rules(includeArchived: true).isEmpty, "reopening does not wipe or fail")
    }
}

@Suite("Settings persistence")
struct SettingsPersistenceTests {

    @Test("settings survive storage", arguments: StoreKind.allCases)
    func roundTrip(kind: StoreKind) throws {
        let store = try kind.make()
        #expect(try store.loadSettings() == nil, "nothing stored yet")

        var settings = AppSettings.default
        settings.observances.fasting = .observed
        settings.hasCompletedFirstRun = true
        settings.jurisdiction = Jurisdiction(name: "Greek", reckoning: .revisedJulian, tradition: .greek)
        try store.saveSettings(settings)

        #expect(try store.loadSettings() == settings)
    }

    @Test("saving twice updates rather than duplicating", arguments: StoreKind.allCases)
    func saveIsIdempotent(kind: StoreKind) throws {
        let store = try kind.make()
        var settings = AppSettings.default
        try store.saveSettings(settings)
        settings.showOldStyleDates = true
        try store.saveSettings(settings)
        #expect(try store.loadSettings()?.showOldStyleDates == true)
    }

    // The failure this replaces: settings lived in UserDefaults and were not
    // persisting at all, so an observance turned on by taking a rule on was
    // lost on the next launch and the rule silently vanished.
    @Test("settings survive closing and reopening the database")
    func survivesReopen() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-settings-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        do {
            let store = try SQLiteStore(path: path)
            var settings = AppSettings.default
            settings.observances.fasting = .observed
            try store.saveSettings(settings)
        }
        let reopened = try SQLiteStore(path: path)
        #expect(try reopened.loadSettings()?.observances.fasting == .observed)
    }

    @Test("a backup carries settings", arguments: StoreKind.allCases)
    func backupIncludesSettings(kind: StoreKind) throws {
        let source = try kind.make()
        var settings = AppSettings.default
        settings.observances.feasts = .observed
        settings.showOldStyleDates = true
        try source.saveSettings(settings)

        let restored = try kind.make()
        try restored.importJSON(try source.exportJSON())
        #expect(try restored.loadSettings()?.observances.feasts == .observed)
        #expect(try restored.loadSettings()?.showOldStyleDates == true)
    }

    @Test("a backup written before settings moved here still restores")
    func olderBackupWithoutSettings() throws {
        let json = """
        {"version":1,"exportedAt":"2026-08-19T12:00:00Z","rules":[],"activations":[],"occurrences":[]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: Data(json.utf8))
        #expect(backup.settings == nil)

        let store = InMemoryStore()
        try store.importBackup(backup)
        #expect(try store.loadSettings() == nil)
    }
}
