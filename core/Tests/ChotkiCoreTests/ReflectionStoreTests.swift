import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

/// Everything runs against both stores. Two that disagree would mean the suite
/// is only checking one of them — and `SQLiteStore` is the one his record is in.
@Suite("Reflections in the store")
struct ReflectionStoreTests {

    @Test("a reflection survives a round trip with every field intact",
          arguments: StoreKind.allCases)
    func reflectionRoundTrip(kind: StoreKind) throws {
        let store = try kind.make()
        let edited = Date(timeIntervalSince1970: 1_780_000_000)
        let reflection = Reflection(
            weekday: .thursday,
            question: ReflectionQuestion(
                title: "Notice the Pattern", notice: "what keeps showing up", task: "write it down"),
            editedAt: edited)

        try store.save(reflection)
        let back = try store.reflections()

        #expect(back.count == 1)
        #expect(back.first?.weekday == .thursday)
        #expect(back.first?.question == reflection.question)
        #expect(back.first?.editedAt?.timeIntervalSince1970 == edited.timeIntervalSince1970)
    }

    @Test("saving a weekday twice rewrites it rather than adding a second",
          arguments: StoreKind.allCases)
    func oneReflectionPerWeekday(kind: StoreKind) throws {
        let store = try kind.make()
        let sunday = Reflection.bundled(for: .sunday)
        try store.save(sunday)
        try store.save(sunday.rewritten(
            ReflectionQuestion(title: "Mine", notice: "n", task: "t")))

        let back = try store.reflections()
        #expect(back.count == 1)
        #expect(back.first?.title == "Mine")
        #expect(back.first?.isEdited == true)
    }

    @Test("they come back in weekday order", arguments: StoreKind.allCases)
    func weekdayOrder(kind: StoreKind) throws {
        let store = try kind.make()
        for reflection in Reflection.bundled.reversed() { try store.save(reflection) }
        #expect(try store.reflections().map(\.weekday) == Weekday.allCases)
    }

    // MARK: seeding

    @Test("seeding puts all seven in place", arguments: StoreKind.allCases)
    func seeding(kind: StoreKind) throws {
        let store = try kind.make()
        #expect(try store.reflections().isEmpty)

        let seeded = try store.seedReflections()
        #expect(seeded.count == 7)
        #expect(try store.reflections().count == 7)
        #expect(try store.reflection(for: .sunday).title == "Notice the Resistance")
    }

    @Test("seeding twice adds nothing the second time", arguments: StoreKind.allCases)
    func seedingIsIdempotent(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        #expect(try store.seedReflections().isEmpty)
        #expect(try store.reflections().count == 7)
    }

    /// Seeding runs on every launch, so it must be incapable of undoing an edit.
    @Test("seeding never overwrites a question the user has rewritten",
          arguments: StoreKind.allCases)
    func seedingLeavesEditsAlone(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        try store.save(Reflection.bundled(for: .friday).rewritten(
            ReflectionQuestion(title: "My own Friday", notice: "n", task: "t")))

        try store.seedReflections()

        #expect(try store.reflection(for: .friday).title == "My own Friday")
        #expect(try store.reflections().count == 7)
    }

    /// A row lost somehow should not leave a hole in the week.
    @Test("seeding fills a gap without touching the rest", arguments: StoreKind.allCases)
    func seedingFillsGaps(kind: StoreKind) throws {
        let store = try kind.make()
        for reflection in Reflection.bundled where reflection.weekday != .tuesday {
            try store.save(reflection)
        }
        let filled = try store.seedReflections()
        #expect(filled.map(\.weekday) == [.tuesday])
        #expect(try store.reflections().count == 7)
    }

    // MARK: answers

    @Test("an answer survives a round trip, question and all",
          arguments: StoreKind.allCases)
    func entryRoundTrip(kind: StoreKind) throws {
        let store = try kind.make()
        let written = Date(timeIntervalSince1970: 1_781_000_000)
        let entry = ReflectionEntry(
            answering: Reflection.bundled(for: .sunday), on: d(2026, 9, 6),
            text: "It came up first thing.", writtenAt: written)

        try store.save(entry)
        let back = try store.reflectionEntries(weekday: nil, from: nil, through: nil)

        #expect(back.count == 1)
        #expect(back.first?.id == entry.id)
        #expect(back.first?.weekday == .sunday)
        #expect(back.first?.date == d(2026, 9, 6))
        #expect(back.first?.text == "It came up first thing.")
        #expect(back.first?.question == Reflection.bundled(for: .sunday).question)
        #expect(back.first?.writtenAt.timeIntervalSince1970 == written.timeIntervalSince1970)
    }

    /// The snapshot at the storage layer: an answer keeps the words it was
    /// written against even after the question is rewritten underneath it.
    @Test("rewriting a question does not change an answer already stored",
          arguments: StoreKind.allCases)
    func storedAnswersKeepTheirQuestion(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        let sunday = try store.reflection(for: .sunday)
        try store.save(ReflectionEntry(answering: sunday, on: d(2026, 9, 6), text: "then"))

        try store.save(sunday.rewritten(
            ReflectionQuestion(title: "Rewritten", notice: "new", task: "new")))

        let back = try store.reflectionEntries(weekday: .sunday, from: nil, through: nil)
        #expect(back.first?.question.title == "Notice the Resistance")
        #expect(try store.reflection(for: .sunday).title == "Rewritten")
    }

    @Test("one answer per weekday per date", arguments: StoreKind.allCases)
    func oneAnswerPerDate(kind: StoreKind) throws {
        let store = try kind.make()
        let sunday = Reflection.bundled(for: .sunday)
        try store.save(ReflectionEntry(answering: sunday, on: d(2026, 9, 6), text: "first"))
        try store.save(ReflectionEntry(answering: sunday, on: d(2026, 9, 6), text: "second"))

        let back = try store.reflectionEntries(weekday: nil, from: nil, through: nil)
        #expect(back.count == 1)
        #expect(back.first?.text == "second")
    }

    @Test("answers come back newest first", arguments: StoreKind.allCases)
    func newestFirst(kind: StoreKind) throws {
        let store = try kind.make()
        let sunday = Reflection.bundled(for: .sunday)
        for day in [6, 20, 13] {
            try store.save(ReflectionEntry(answering: sunday, on: d(2026, 9, day), text: "\(day)"))
        }
        #expect(try store.reflectionEntries(weekday: nil, from: nil, through: nil)
            .map(\.date.day) == [20, 13, 6])
    }

    @Test("they can be narrowed by weekday and by date", arguments: StoreKind.allCases)
    func filtering(kind: StoreKind) throws {
        let store = try kind.make()
        try store.save(ReflectionEntry(
            answering: Reflection.bundled(for: .sunday), on: d(2026, 9, 6), text: "s"))
        try store.save(ReflectionEntry(
            answering: Reflection.bundled(for: .sunday), on: d(2026, 9, 13), text: "s2"))
        try store.save(ReflectionEntry(
            answering: Reflection.bundled(for: .wednesday), on: d(2026, 9, 9), text: "w"))

        #expect(try store.reflectionEntries(weekday: .sunday, from: nil, through: nil).count == 2)
        #expect(try store.reflectionEntries(weekday: .wednesday, from: nil, through: nil).count == 1)
        #expect(try store.reflectionEntries(weekday: nil, from: d(2026, 9, 9), through: nil).count == 2)
        #expect(try store.reflectionEntries(weekday: nil, from: nil, through: d(2026, 9, 9)).count == 2)
        #expect(try store.reflectionEntries(
            weekday: nil, from: d(2026, 9, 7), through: d(2026, 9, 12)).count == 1)
    }

    // MARK: backup

    @Test("the whole backup carries reflections and answers", arguments: StoreKind.allCases)
    func backupRoundTrip(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        try store.save(ReflectionEntry(
            answering: try store.reflection(for: .sunday), on: d(2026, 9, 6), text: "kept"))

        let data = try store.exportJSON()
        let restored = try StoreKind.memory.make()
        try restored.importJSON(data)

        #expect(try restored.reflections().count == 7)
        #expect(try restored.reflectionEntries(weekday: nil, from: nil, through: nil)
            .first?.text == "kept")
    }

    /// A backup written before Reflections existed must still restore, which is
    /// what the two optional fields are for.
    @Test("a backup from before this feature still restores")
    func oldBackupStillRestores() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "2026-08-01T00:00:00Z",
          "rules": [],
          "activations": [],
          "occurrences": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: Data(json.utf8))

        #expect(backup.reflections == nil)
        #expect(backup.reflectionEntries == nil)

        let store = InMemoryStore()
        try store.importBackup(backup)
        #expect(try store.reflections().isEmpty)
    }
}

@Suite("The journal as a file")
struct ReflectionArchiveTests {

    @Test("export and import round trip", arguments: StoreKind.allCases)
    func roundTrip(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        try store.save(ReflectionEntry(
            answering: try store.reflection(for: .sunday), on: d(2026, 9, 6), text: "one"))
        try store.save(ReflectionEntry(
            answering: try store.reflection(for: .friday), on: d(2026, 9, 4), text: "two"))

        let data = try store.exportReflectionsJSON()
        let fresh = try StoreKind.memory.make()
        let result = try fresh.importReflectionsJSON(data)

        #expect(result.addedCount == 2)
        #expect(result.alreadyPresent == 0)
        #expect(try fresh.reflections().count == 7)
        #expect(try fresh.reflectionEntries(weekday: nil, from: nil, through: nil).count == 2)
    }

    @Test("importing the same file twice changes nothing the second time",
          arguments: StoreKind.allCases)
    func idempotent(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        try store.save(ReflectionEntry(
            answering: try store.reflection(for: .sunday), on: d(2026, 9, 6), text: "one"))
        let data = try store.exportReflectionsJSON()

        let second = try store.importReflectionsJSON(data)
        #expect(second.addedCount == 0)
        #expect(second.alreadyPresent == 1)
        #expect(try store.reflectionEntries(weekday: nil, from: nil, through: nil).count == 1)
    }

    /// An import is additive. A file from a stale export must never be able to
    /// overwrite an answer written since.
    @Test("an import never overwrites an answer already held",
          arguments: StoreKind.allCases)
    func neverOverwrites(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        let sunday = try store.reflection(for: .sunday)
        try store.save(ReflectionEntry(answering: sunday, on: d(2026, 9, 6), text: "mine"))

        let stale = ReflectionArchive(reflections: [], entries: [
            ReflectionEntry(answering: sunday, on: d(2026, 9, 6), text: "theirs"),
            ReflectionEntry(answering: sunday, on: d(2026, 9, 13), text: "new one")
        ])
        let result = try store.importReflections(stale)

        #expect(result.addedCount == 1)
        #expect(result.alreadyPresent == 1)
        #expect(try store.reflectionEntries(weekday: .sunday, from: d(2026, 9, 6), through: d(2026, 9, 6))
            .first?.text == "mine")
    }

    /// An import must not be able to undo an edit either.
    @Test("an import never rewrites a question this record already holds",
          arguments: StoreKind.allCases)
    func neverRewritesQuestions(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        try store.save(try store.reflection(for: .sunday).rewritten(
            ReflectionQuestion(title: "My own Sunday", notice: "n", task: "t")))

        try store.importReflections(
            ReflectionArchive(reflections: Reflection.bundled, entries: []))

        #expect(try store.reflection(for: .sunday).title == "My own Sunday")
    }
}

@Suite("Reading the web artifact's journal")
struct NepsisImportTests {

    /// The artifact's shape: `days` keyed "1"…"7" by position in the cycle,
    /// entries carrying no question because on the web the seven were fixed.
    private let legacy = """
    {
      "days": {
        "1": [{"date": "2026-08-30", "text": "It came up first thing."},
              {"date": "2026-08-23", "text": "Less this week."}],
        "4": [{"date": "2026-08-26", "text": "Put off the call again."}]
      },
      "reflections": [{"date": "2026-08-31", "text": "a pass", "deep": false}],
      "dismissed": false
    }
    """

    @Test("it is read, and the entries come across")
    func reads() throws {
        let archive = try ReflectionImport.read(Data(legacy.utf8))
        #expect(archive.entries.count == 3)
        #expect(archive.reflections.isEmpty)
    }

    /// On the web the seven were a cycle rather than a week — "day 4" was the
    /// fourth prompt, whatever day it was answered on. So an entry is filed
    /// under the weekday it was actually written on and keeps the question it
    /// actually answered. 30 August 2026 was a Sunday; 26 August a Wednesday.
    @Test("an entry is filed by its date and keeps the question it answered")
    func filedByDate() throws {
        let archive = try ReflectionImport.read(Data(legacy.utf8))
        let aug30 = try #require(archive.entries.first { $0.date == d(2026, 8, 30) })

        #expect(aug30.weekday == .sunday)
        #expect(aug30.question.title == "Notice the Resistance")

        // Cycle day 4 is Wednesday's question, and 26 August happens to be a
        // Wednesday too — so this one agrees. The point is that the question
        // comes from the cycle number and the weekday from the date.
        let aug26 = try #require(archive.entries.first { $0.date == d(2026, 8, 26) })
        #expect(aug26.weekday == .wednesday)
        #expect(aug26.question.title == "Notice the Avoidance")
    }

    @Test("the AI reflections in the file are ignored rather than imported")
    func ignoresReflectPasses() throws {
        let archive = try ReflectionImport.read(Data(legacy.utf8))
        #expect(archive.entries.allSatisfy { $0.text.contains("a pass") == false })
    }

    @Test("blank and unreadable entries are skipped, not stored")
    func skipsRubbish() throws {
        let messy = """
        {"days": {"1": [{"date": "2026-08-30", "text": "   "},
                        {"date": "not-a-date", "text": "x"},
                        {"date": "2026-08-23", "text": "kept"}],
                  "9": [{"date": "2026-08-16", "text": "no such day"}]}}
        """
        let archive = try ReflectionImport.read(Data(messy.utf8))
        #expect(archive.entries.count == 1)
        #expect(archive.entries.first?.text == "kept")
    }

    @Test("it lands in the store and merges rather than replacing",
          arguments: StoreKind.allCases)
    func importsIntoTheStore(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        try store.save(ReflectionEntry(
            answering: try store.reflection(for: .sunday), on: d(2026, 8, 30), text: "already mine"))

        let result = try store.importReflectionsJSON(Data(legacy.utf8))

        #expect(result.addedCount == 2)
        #expect(result.alreadyPresent == 1)
        #expect(try store.reflectionEntries(
            weekday: .sunday, from: d(2026, 8, 30), through: d(2026, 8, 30))
            .first?.text == "already mine")
    }

    @Test("a file that is neither shape is refused and nothing is touched",
          arguments: StoreKind.allCases)
    func refusesRubbish(kind: StoreKind) throws {
        let store = try kind.make()
        try store.seedReflections()
        try store.save(ReflectionEntry(
            answering: try store.reflection(for: .sunday), on: d(2026, 9, 6), text: "mine"))

        #expect(throws: ReflectionImportError.unrecognised) {
            try store.importReflectionsJSON(Data("{\"something\": 1}".utf8))
        }
        #expect(try store.reflectionEntries(weekday: nil, from: nil, through: nil).count == 1)
    }
}
