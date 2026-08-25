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

    /// Derived from this file's own location, so it is right on a CI checkout
    /// as well as on the machine it was written on. An absolute path here made
    /// the Linux and macOS jobs fail while every local run passed.
    private static let directory: String = {
        URL(fileURLWithPath: #filePath)               // .../core/Tests/ChotkiCoreTests/this.swift
            .deletingLastPathComponent()              // ChotkiCoreTests
            .deletingLastPathComponent()              // Tests
            .deletingLastPathComponent()              // core
            .deletingLastPathComponent()              // the repository
            .appendingPathComponent("android/core/src/main/resources/content")
            .path
    }()

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

    /// The churches offered, and what each tradition customarily expects.
    ///
    /// Exported for the same reason as everything else here: these were
    /// hand-copied into the Kotlin side once, and the first change to the
    /// wording went into Swift only. Content that lives in two places diverges
    /// the moment anyone edits it.
    private func jurisdictions() -> [[String: Any]] {
        Jurisdiction.known.map { jurisdiction in
            [
                "name": jurisdiction.name,
                "reckoning": jurisdiction.reckoning.rawValue,
                "tradition": jurisdiction.tradition.rawValue
            ]
        }
    }

    private func practiceProfiles() -> [[String: Any]] {
        Tradition.allCases.map { tradition in
            let profile = PracticeProfile.customary(for: tradition)
            return [
                "tradition": tradition.rawValue,
                "confession": profile.confession.rawValue,
                "eucharisticFastFromMidnight": profile.eucharisticFastFromMidnight,
                "preparatoryCanons": profile.preparatoryCanons,
                "notes": profile.notes
            ]
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
            ("patristic-readings", readings()), ("prayer-sources", sources()),
            ("jurisdictions", jurisdictions()), ("practice-profiles", practiceProfiles()),
            ("welcome", welcome())
        ]
    }

    /// Ryan's words, moved rather than retyped — the whole reason this lives in
    /// core is that the two platforms must say exactly the same thing.
    private func welcome() -> [String: Any] {
        [
            "title": Welcome.title,
            "beginLabel": Welcome.beginLabel,
            "paragraphs": Welcome.paragraphs.map { paragraph in
                [
                    "isAside": paragraph.isAside,
                    "spans": paragraph.spans.map { span -> [String: Any] in
                        var out: [String: Any] = ["text": span.text]
                        if let url = span.url { out["url"] = url }
                        return out
                    }
                ] as [String: Any]
            }
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
            if let array = value as? [[String: Any]] {
                #expect(!array.isEmpty, "\(name) exported nothing")
            } else if let object = value as? [String: Any] {
                // The welcome is one object rather than a list of them.
                #expect(!object.isEmpty, "\(name) exported nothing")
            } else {
                Issue.record("\(name) is neither a list nor an object")
            }
        }
    }

    /// The Psalter is shipped, not authored, so it is not exported here — the
    /// generator writes both copies at once. This is the guard that they are
    /// still the same file.
    ///
    /// It is 388KB of psalms and neither copy is ever edited by hand, so the
    /// only way they diverge is someone regenerating one and not committing the
    /// other. That would leave the two platforms reading different psalms.
    @Test("both copies of the Psalter are the same file")
    func psalterCopiesMatch() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()

        let swift = try Data(contentsOf: root.appendingPathComponent(
            "core/Sources/ChotkiCore/Resources/psalter.json"))
        let kotlin = try Data(contentsOf: root.appendingPathComponent(
            "android/core/src/main/resources/content/psalter.json"))

        #expect(swift == kotlin, "the two Psalters have drifted — rerun core/Tools/psalter-from-brenton.py")
        #expect(swift.count > 300_000, "the Psalter looks truncated")
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
