import Testing
import Foundation
@testable import ChotkiCore

/// Moves the bundled content to the Kotlin side, mechanically.
///
/// The prayers, the glossary, the rule library and the patristic readings are
/// data, and three of the four are liturgical text where a transcription error
/// is a real error rather than a typo. Nobody retypes them: this writes them
/// out, and CI fails if what is committed no longer matches what the Swift
/// content says.
///
/// **The Swift literals remain the place content is authored.** They carry the
/// provenance in their comments — Hapgood 1906, ANF and NPNF, which prayers are
/// counted on a rope and why — and JSON cannot hold any of that. This is a
/// generated artefact, committed so the Android build needs no Swift toolchain.
///
/// The shape is designed rather than dumped. Swift's synthesised encoding of an
/// enum with associated values produces `{"liturgical":{"_0":{"season":{"_0":
/// "greatLent"}}}}`, which is both unreadable and awkward to decode anywhere
/// else. It is also the shape already written into the `recurrence` column of
/// every existing database, so it cannot be changed — hence a separate wire
/// format used only here.
///
/// To regenerate after changing content: `CHOTKI_WRITE_CONTENT=1 swift test
/// --package-path core --filter ContentExport`
@Suite("Content export")
struct ContentExportTests {

    private static let directory =
        "/Volumes/2TB/claude-vault/projects/chotki/android/core/src/main/resources/content"

    // MARK: the wire shape

    private func recurrence(_ recurrence: Recurrence) -> [String: Any] {
        switch recurrence {
        case .once(let date):
            return ["kind": "once", "date": date.iso]
        case .daily:
            return ["kind": "daily"]
        case .weekly(let days):
            return ["kind": "weekly", "days": days.map(\.name).sorted()]
        case .monthly(let day, let whenShort):
            return ["kind": "monthly", "day": day, "whenShort": whenShort.rawValue]
        case .liturgical(let trigger):
            switch trigger {
            case .fastDay: return ["kind": "liturgical", "trigger": "fastDay"]
            case .greatFeast: return ["kind": "liturgical", "trigger": "greatFeast"]
            case .season(let season):
                return ["kind": "liturgical", "trigger": "season", "season": season.rawValue]
            }
        }
    }

    private func glossary() -> [[String: Any]] {
        Glossary.bundled.map { entry in
            var out: [String: Any] = [
                "slug": entry.slug, "term": entry.term, "aliases": entry.aliases,
                "short": entry.short, "full": entry.full,
                "category": entry.category.rawValue, "related": entry.related,
                "traditions": entry.traditions.map(\.rawValue).sorted()
            ]
            if let pronunciation = entry.pronunciation { out["pronunciation"] = pronunciation }
            return out
        }
    }

    private func prayers() -> [[String: Any]] {
        PrayerBook.shared.prayers.map { prayer in
            var out: [String: Any] = [
                "id": prayer.id, "title": prayer.title, "paragraphs": prayer.paragraphs,
                "source": prayer.source, "isForRope": prayer.isForRope,
                "traditions": prayer.traditions.map(\.rawValue).sorted()
            ]
            if let rubric = prayer.rubric { out["rubric"] = rubric }
            if let url = prayer.sourceURL { out["sourceURL"] = url }
            return out
        }
    }

    private func sequences() -> [[String: Any]] {
        PrayerSequence.all.map { ["id": $0.id, "title": $0.title, "prayerIDs": $0.prayerIDs] }
    }

    private func library() -> [[String: Any]] {
        RuleLibrary.bundled.map { template in
            var out: [String: Any] = [
                "id": template.id, "title": template.title, "summary": template.summary,
                "recurrence": recurrence(template.recurrence),
                "category": template.category.rawValue,
                "reminders": [
                    "enabled": template.reminders.enabled,
                    "leads": template.reminders.leads.map(\.name)
                ],
                "traditions": template.traditions.map(\.rawValue).sorted(),
                "glossarySlugs": template.glossarySlugs,
                "prayerIDs": template.prayerIDs
            ]
            if let note = template.note { out["note"] = note }
            if let time = template.timeOfDay {
                out["timeOfDay"] = String(format: "%02d:%02d", time.hour, time.minute)
            }
            return out
        }
    }

    private func readings() -> [[String: Any]] {
        PatristicReadings.bundled.map {
            ["id": $0.id, "text": $0.text, "author": $0.author, "source": $0.source]
        }
    }

    private func sources() -> [[String: Any]] {
        PrayerSources.further.map {
            ["title": $0.title, "organisation": $0.organisation, "url": $0.url]
        }
    }

    // MARK: writing and checking

    private func json(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self)
    }

    private var files: [(String, Any)] {
        [
            ("glossary", glossary()), ("prayers", prayers()),
            ("prayer-sequences", sequences()), ("rule-library", library()),
            ("patristic-readings", readings()), ("prayer-sources", sources())
        ]
    }

    @Test("the committed content matches what the Swift content says")
    func contentIsFresh() throws {
        let writing = ProcessInfo.processInfo.environment["CHOTKI_WRITE_CONTENT"] == "1"

        for (name, value) in files {
            let wanted = try json(value)
            let path = "\(ContentExportTests.directory)/\(name).json"

            if writing {
                try wanted.write(toFile: path, atomically: true, encoding: .utf8)
                continue
            }

            let onDisk = try? String(contentsOfFile: path, encoding: .utf8)
            #expect(
                onDisk == wanted,
                """
                \(name).json is out of date with the Swift content. \
                Regenerate: CHOTKI_WRITE_CONTENT=1 swift test --package-path core \
                --filter ContentExport
                """
            )
        }
    }

    @Test("nothing is exported empty")
    func nothingIsEmpty() throws {
        for (name, value) in files {
            let array = try #require(value as? [[String: Any]])
            #expect(!array.isEmpty, "\(name) exported nothing")
        }
    }
}

private extension Weekday {
    /// Names rather than numbers, so the file reads and cannot silently shift
    /// if anyone ever renumbers the enum.
    var name: String {
        ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][rawValue - 1]
    }
}

private extension ReminderLead {
    var name: String {
        switch self {
        case .atTheTime: return "atTheTime"
        case .tenMinutes: return "tenMinutes"
        case .thirtyMinutes: return "thirtyMinutes"
        case .oneHour: return "oneHour"
        case .twoHours: return "twoHours"
        case .theEveningBefore: return "theEveningBefore"
        }
    }
}
