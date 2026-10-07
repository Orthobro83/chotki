import Foundation

/// A run of verses in one chapter of one book, `first` through `last`.
///
/// Books use the USFX three-letter codes Orthocal itself uses ("MAT", "1KI").
/// On disk a run is the array `[book, chapter, first, last]`.
public struct PassageRun: Sendable, Hashable, Codable {
    public let book: String
    public let chapter: Int
    public let first: Int
    public let last: Int

    public init(book: String, chapter: Int, first: Int, last: Int) {
        self.book = book; self.chapter = chapter; self.first = first; self.last = last
    }

    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        book = try c.decode(String.self)
        chapter = try c.decode(Int.self)
        first = try c.decode(Int.self)
        last = try c.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(book); try c.encode(chapter); try c.encode(first); try c.encode(last)
    }
}

/// The words of scripture the app shows, and how verses become paragraphs.
///
/// **Where the text comes from.** One King James Version (with the Apocrypha),
/// public domain, from eBible.org, shipped in the core bundle (`calendar/kjv.json`).
/// A day in the bundled calendar stores only *which verses* each reading is, and
/// they are resolved here. So the licence audit is one file, and nothing Orthocal
/// serves as prose is trusted: its Composite readings carry a translation that is
/// not ours to show, and are resolved from the verses their titles cite instead.
///
/// **Paragraphs.** The Bible marks which verses open a paragraph. A blank line is
/// put before such a verse, and before any verse that does not follow on from the one
/// before it (separate passages must not run together); otherwise verses are joined
/// by a single space. The first verse never gets one. This is the same rule the
/// bundle builder (`core/Tools/calendar-bundle.py`) uses, and a test holds them to
/// each other through a digest.
public enum ScriptureText {

    public struct Verse: Sendable, Hashable {
        public let book: String
        public let chapter: Int
        public let verse: Int
        public let text: String
        public let opensParagraph: Bool

        public init(book: String, chapter: Int, verse: Int, text: String, opensParagraph: Bool) {
            self.book = book; self.chapter = chapter; self.verse = verse
            self.text = text; self.opensParagraph = opensParagraph
        }
    }

    /// The paragraph break, a blank line. Views that show `Reading.text` as it is
    /// render it as one.
    public static let paragraphBreak = "\n\n"

    private static func follows(_ previous: Verse, _ next: Verse) -> Bool {
        guard previous.book == next.book else { return false }
        if previous.chapter == next.chapter { return next.verse == previous.verse + 1 }
        return next.chapter == previous.chapter + 1 && next.verse == 1
    }

    /// Verses to text, by the paragraph rule above.
    public static func join(_ verses: [Verse]) -> String {
        var out = ""
        var previous: Verse?
        for verse in verses {
            if let previous {
                out += (verse.opensParagraph || !follows(previous, verse)) ? paragraphBreak : " "
            }
            out += verse.text
            previous = verse
        }
        return out
    }

    /// The text of the runs, resolved from the bundled Bible. Nil when any verse is
    /// not in it: better no text than the wrong text.
    public static func text(for runs: [PassageRun]) -> String? {
        let bible = Bible.shared
        var verses: [Verse] = []
        for run in runs where run.first <= run.last {
            for number in run.first...run.last {
                guard let found = bible.verse(book: run.book, chapter: run.chapter, verse: number) else { return nil }
                verses.append(found)
            }
        }
        return verses.isEmpty ? nil : join(verses)
    }

    /// The runs a Composite reading's title cites ("Composite 4 - Proverbs 10; ..."),
    /// or nil for any other reading.
    public static func composite(display: String) -> [PassageRun]? {
        Bible.composites[display]
    }

    /// A day read back from the cache may carry Composite text from an older build
    /// of the app, which fetched it from the network as served. Replace it.
    public static func sanitised(_ day: LiturgicalDay) -> LiturgicalDay {
        guard day.readings.contains(where: { composite(display: $0.display) != nil }) else { return day }
        return day.replacing(readings: day.readings.map { reading in
            guard let runs = composite(display: reading.display) else { return reading }
            return Reading(source: reading.source, display: reading.display,
                           shortDisplay: reading.shortDisplay, text: text(for: runs) ?? "")
        })
    }

    // MARK: the bundled Bible

    final class Bible: Sendable {
        struct Chapter: Decodable {
            let v: [String?]
            let p: [Int]
        }

        /// book -> chapters, where index 0 is chapter 1.
        private let books: [String: [Chapter]]
        private let openers: [String: [Set<Int>]]

        static let shared: Bible = {
            guard let url = BundledFile.url("kjv", extension: "json", subdirectory: "calendar"),
                  let data = try? Data(contentsOf: url),
                  let books = try? JSONDecoder().decode([String: [Chapter]].self, from: data)
            else {
                // A missing resource is a build fault, not a runtime condition.
                fatalError("the Bible is missing from the bundle")
            }
            return Bible(books: books)
        }()

        static let composites: [String: [PassageRun]] = {
            guard let url = BundledFile.url("composites", extension: "json", subdirectory: "calendar"),
                  let data = try? Data(contentsOf: url),
                  let table = try? JSONDecoder().decode([String: [PassageRun]].self, from: data)
            else { fatalError("the composite table is missing from the bundle") }
            return table
        }()

        private init(books: [String: [Chapter]]) {
            self.books = books
            self.openers = books.mapValues { $0.map { Set($0.p) } }
        }

        func verse(book: String, chapter: Int, verse: Int) -> Verse? {
            guard let chapters = books[book], chapter >= 1, chapter <= chapters.count else { return nil }
            let entry = chapters[chapter - 1]
            guard verse >= 1, verse <= entry.v.count, let text = entry.v[verse - 1] else { return nil }
            return Verse(book: book, chapter: chapter, verse: verse, text: text,
                         opensParagraph: openers[book]?[chapter - 1].contains(verse) ?? false)
        }

        var bookCount: Int { books.count }
        var verseCount: Int { books.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.v.compactMap { $0 }.count } } }
    }
}
