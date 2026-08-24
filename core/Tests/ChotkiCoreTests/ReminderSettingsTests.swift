import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}
private let zone = TimeZone(identifier: "Europe/London")!

private func localTime(_ instant: Date) -> String {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = zone
    let p = c.dateComponents([.hour, .minute], from: instant)
    return String(format: "%02d:%02d", p.hour!, p.minute!)
}

@Suite("Turning reminders off")
struct ReminderTogglesTests {

    private func liturgy(_ reminders: RuleReminders? = nil) -> (Rule, [Activation]) {
        let rule = Rule(
            title: "Sunday Liturgy", recurrence: .daily,
            timeOfDay: TimeOfDay(hour: 9, minute: 0), reminders: reminders
        )
        return (rule, [Activation(ruleID: rule.id, from: d(2026, 1, 1))])
    }

    @Test("the master switch silences everything")
    func masterSwitch() {
        let (rule, activations) = liturgy()
        let loud = Scheduler(policy: .default, timeZone: zone)
        let silent = Scheduler(policy: .silent, timeZone: zone)

        #expect(!loud.plan(rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)).isEmpty)
        #expect(silent.plan(rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)).isEmpty)
    }

    // The property that matters. Silence is not standing down: a rule with
    // reminders off is still due and still scored exactly as before, so someone
    // who knows their own routine can stop the buzzing without the app
    // deciding for them that they have given the rule up.
    @Test("silencing a rule does not change whether it is due")
    func silenceDoesNotAffectScoring() {
        let (loud, activations) = liturgy(.default)
        var quiet = loud
        quiet.reminders = .silent

        let engine = RecurrenceEngine()
        let loudDue = engine.dueDates(rule: loud, activations: activations, from: d(2026, 8, 1), through: d(2026, 8, 31))
        let quietDue = engine.dueDates(rule: quiet, activations: activations, from: d(2026, 8, 1), through: d(2026, 8, 31))

        #expect(loudDue == quietDue)
        #expect(quietDue.count == 31, "still due every day, still scored")
    }

    @Test("a silenced rule is skipped while its neighbours still remind")
    func perRuleSilence() {
        let (noisy, noisyActivations) = liturgy(.default)
        var silent = Rule(
            title: "Morning prayers", recurrence: .daily,
            timeOfDay: TimeOfDay(hour: 6, minute: 30), reminders: .silent
        )
        silent.category = "prayer"
        let silentActivations = [Activation(ruleID: silent.id, from: d(2026, 1, 1))]

        let planned = Scheduler(timeZone: zone).plan(
            rules: [noisy, silent],
            activations: noisyActivations + silentActivations,
            occurrences: [], on: d(2026, 8, 19)
        )
        #expect(planned.allSatisfy { $0.ruleID == noisy.id })
        #expect(planned.count == 1)
    }

    @Test("a rule with no reminder settings uses the default")
    func defaultsApply() {
        let (rule, activations) = liturgy(nil)
        #expect(rule.effectiveReminders == .default)
        let planned = Scheduler(timeZone: zone).plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        #expect(planned.count == 1)
        #expect(localTime(planned[0].fireAt) == "08:50", "ten minutes before 09:00")
    }
}

@Suite("Reminder lead times")
struct ReminderLeadTests {

    private func rule(_ leads: [ReminderLead]) -> (Rule, [Activation]) {
        let r = Rule(
            title: "Sunday Liturgy", recurrence: .daily,
            timeOfDay: TimeOfDay(hour: 9, minute: 0),
            reminders: RuleReminders(leads: leads)
        )
        return (r, [Activation(ruleID: r.id, from: d(2026, 1, 1))])
    }

    private func fireTimes(_ leads: [ReminderLead]) -> [String] {
        let (r, activations) = rule(leads)
        return Scheduler(timeZone: zone)
            .plan(rules: [r], activations: activations, occurrences: [], on: d(2026, 8, 19))
            .map { localTime($0.fireAt) }
    }

    @Test("each lead fires at the right offset", arguments: [
        (ReminderLead.atTheTime, "09:00"),
        (.tenMinutes, "08:50"),
        (.thirtyMinutes, "08:30"),
        (.oneHour, "08:00"),
        (.twoHours, "07:00")
    ])
    func leadOffsets(lead: ReminderLead, expected: String) {
        #expect(fireTimes([lead]) == [expected])
    }

    @Test("the evening before fires at a predictable hour the previous day")
    func eveningBefore() throws {
        let (r, activations) = rule([.theEveningBefore])
        let planned = Scheduler(timeZone: zone)
            .plan(rules: [r], activations: activations, occurrences: [], on: d(2026, 8, 19))
        let notification = try #require(planned.first)
        #expect(localTime(notification.fireAt) == "20:00")
        #expect(notification.date == d(2026, 8, 19), "it belongs to the day it is about")
        #expect(notification.request.body == "Tomorrow at 09:00")
    }

    // An hour before to get ready, ten minutes before to actually leave.
    @Test("several leads produce several reminders, in order")
    func multipleLeads() {
        #expect(fireTimes([.tenMinutes, .oneHour]) == ["08:00", "08:50"])
        #expect(fireTimes([.twoHours, .thirtyMinutes, .atTheTime]) == ["07:00", "08:30", "09:00"])
    }

    @Test("each lead gets its own id so none overwrites another")
    func leadsHaveDistinctIDs() {
        let (r, activations) = rule([.tenMinutes, .oneHour, .atTheTime])
        let planned = Scheduler(timeZone: zone)
            .plan(rules: [r], activations: activations, occurrences: [], on: d(2026, 8, 19))
        #expect(Set(planned.map(\.id)).count == 3)
    }

    @Test("completing cancels every lead, not just the next one")
    func cancellationCoversAllLeads() {
        let (r, activations) = rule([.tenMinutes, .oneHour, .theEveningBefore])
        let scheduler = Scheduler(timeZone: zone)
        let planned = scheduler.plan(rules: [r], activations: activations, occurrences: [], on: d(2026, 8, 19))
        let cancelled = scheduler.cancellationIDs(
            ruleID: r.id, date: d(2026, 8, 19), rules: [r], activations: activations
        )
        #expect(Set(cancelled) == Set(planned.map(\.id)))
        #expect(cancelled.count == 3)
    }

    @Test("an empty lead list falls back to the policy default")
    func emptyLeadsFallBack() {
        let (r, activations) = rule([])
        let planned = Scheduler(policy: ReminderPolicy(defaultLead: .thirtyMinutes), timeZone: zone)
            .plan(rules: [r], activations: activations, occurrences: [], on: d(2026, 8, 19))
        #expect(planned.map { localTime($0.fireAt) } == ["08:30"])
    }

    @Test("every offered choice has a label and no guilt language")
    func choicesAreWellFormed() {
        #expect(ReminderLead.choices.count == ReminderLead.allCases.count)
        for lead in ReminderLead.choices {
            #expect(!lead.label.isEmpty)
            let label = lead.label.lowercased()
            for word in ["overdue", "late", "missed", "!"] {
                #expect(!label.contains(word))
            }
        }
    }
}

@Suite("Reminder settings persist")
struct ReminderPersistenceTests {

    @Test("settings survive storage", arguments: StoreKind.allCases)
    func roundTrip(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(
            title: "Sunday Liturgy", recurrence: .weekly(days: [.sunday]),
            timeOfDay: TimeOfDay(hour: 9, minute: 0),
            reminders: .forService
        )
        try store.save(rule)
        let loaded = try #require(try store.rule(id: rule.id))
        #expect(loaded.reminders == .forService)
        #expect(loaded.effectiveReminders.leads == [.oneHour, .tenMinutes])
    }

    @Test("a rule stored without settings still loads", arguments: StoreKind.allCases)
    func absentSettingsLoad(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(title: "Evening prayers", recurrence: .daily)
        try store.save(rule)
        let loaded = try #require(try store.rule(id: rule.id))
        #expect(loaded.reminders == nil)
        #expect(loaded.effectiveReminders == .default)
    }

    // A backup written before per-rule reminders existed must still restore.
    @Test("an older backup without the field decodes")
    func olderBackupDecodes() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "2026-08-19T12:00:00Z",
          "rules": [{
            "id": "\(UUID().uuidString)",
            "title": "Morning prayers",
            "recurrence": {"daily": {}},
            "createdAt": "2026-08-19T12:00:00Z"
          }],
          "activations": [],
          "occurrences": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: Data(json.utf8))
        #expect(backup.rules.first?.reminders == nil)
        #expect(backup.rules.first?.effectiveReminders == .default)
    }
}

/// A fresh database runs every migration at once, so it never proves the
/// upgrade path. These build the schema as it stood before per-rule reminders
/// existed, then open it normally and check the data survives.
@Suite("Schema migration")
struct SchemaMigrationTests {

    private func makeLegacyDatabase(at path: String) throws {
        let store = try SQLiteStore(path: path)
        // Wind the file back to exactly what version 2 left behind.
        //
        // **Every later migration must be undone here**, not just the most
        // recent one. This has now broken twice — once when version 4 arrived
        // and again at version 5 — because a new migration was added without
        // teaching this fixture to reverse it. If you add a migration, add its
        // reversal to this list.
        for column in ["reminders", "prayer_ids", "hidden_from_library"] {
            try? store.exec("ALTER TABLE rule DROP COLUMN \(column);")
        }
        try store.exec("DROP TABLE IF EXISTS app_settings;")
        try store.exec("DELETE FROM schema_version WHERE version > 2;")
    }

    @Test("a version 2 database upgrades in place without losing rules")
    func upgradesFromVersionTwo() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-migrate-v2-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        let ruleID = UUID()
        try makeLegacyDatabase(at: path)

        // Write a rule the old way, with no reminders column in sight.
        do {
            let legacy = try SQLiteStore(path: path)
            try legacy.exec("""
                INSERT INTO rule (id, title, recurrence, created_at)
                VALUES ('\(ruleID.uuidString)', 'Morning prayers',
                        '{"daily":{}}', '2026-08-19T06:30:00.000Z');
                """)
        }

        // Reopening runs the migration.
        let upgraded = try SQLiteStore(path: path)
        let loaded = try #require(try upgraded.rule(id: ruleID))
        #expect(loaded.title == "Morning prayers", "the existing rule survived")
        #expect(loaded.reminders == nil)
        #expect(loaded.effectiveReminders == .default, "and picks up the default")

        // And the upgraded database accepts the new field.
        var updated = loaded
        updated.reminders = .forService
        try upgraded.save(updated)
        #expect(try upgraded.rule(id: ruleID)?.reminders == .forService)
    }

    @Test("upgrading twice is harmless")
    func upgradeIsIdempotent() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-migrate-twice-\(UUID().uuidString).sqlite").path
        defer { try? FileManager.default.removeItem(atPath: path) }

        try makeLegacyDatabase(at: path)
        _ = try SQLiteStore(path: path)
        _ = try SQLiteStore(path: path)
        let third = try SQLiteStore(path: path)
        #expect(try third.rules(includeArchived: true).isEmpty)
    }
}
