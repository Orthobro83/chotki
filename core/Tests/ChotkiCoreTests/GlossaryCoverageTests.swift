import Testing
import Foundation
@testable import ChotkiCore

/// New text must bring its glossary with it.
///
/// A prayer or a passage added without entries for the words in it leaves a
/// reader stranded exactly where the app promises not to: "Theotokos",
/// "Trisagion", "kathisma" mean nothing to a newcomer, and the whole point of
/// the glossary is that the explanation is one tap from the word.
///
/// Nobody needs an entry for "so". The test looks for the words that plausibly
/// need one — capitalised terms that are not simply the start of a sentence,
/// which in liturgical English is very nearly the definition of a term of art —
/// and fails when one appears that the glossary cannot explain.
///
/// It is a ratchet, not a proof. `known` below is the set already judged not to
/// need an entry. Adding to it is a decision to be made deliberately, in a
/// commit someone can see, rather than by the test quietly going green.
@Suite("New text brings its glossary")
struct GlossaryCoverageTests {

    /// Ordinary English, scripture names, and words a reader will not stumble
    /// on. Everything here has been looked at once and judged not a term.
    private let known: Set<String> = [
        // Divine names and pronouns, which are not obscure to anyone reading a
        // prayer book, and appear in nearly every line.
        "god", "lord", "jesus", "christ", "holy", "spirit", "father", "son",
        "thee", "thou", "thy", "thine", "ye", "o", "amen", "alleluia",
        // Sentence-initial words that happen to recur.
        "and", "but", "for", "the", "a", "i", "in", "of", "to", "we", "let",
        "glory", "blessed", "have", "grant", "who", "now", "then", "may",
        "from", "with", "by", "as", "it", "he", "she", "they", "this", "that",
        "again", "again.", "both", "if", "when", "so", "yet", "all", "every",
        // Places and people from scripture, which the readings name constantly
        // and which are not liturgical terms.
        "israel", "sion", "jerusalem", "david", "moses", "abraham", "jacob",
        "egypt", "jordan", "galilee", "judea", "bethlehem", "nazareth",
        "mary", "pontius", "pilate", "sisoes",
        // Divine titles. A reader of a prayer book does not stumble on
        // "Almighty" or "Maker"; they are English, and their meaning is the
        // plain one.
        "almighty", "maker", "creator", "master", "saviour", "immortal",
        "mighty", "heavenly", "king", "light", "life", "truth", "word",
        "giver", "good", "one", "most", "whom", "what", "him", "himself",
        "thyself", "mother", "virgin", "angel", "humility", "christians",
        "scripture", "scriptures",
    ]

    /// Terms that plausibly need an entry, where writing the definition is not
    /// mine to make.
    ///
    /// "Catholic" is the sharp one: in the Creed it means universal, and a
    /// newcomer reads it as Roman Catholic every time. But what a glossary
    /// entry should *say* about it is a matter for Ryan and a priest, not for
    /// me — the house rule is to ask for a reference rather than infer one.
    ///
    /// Listed here so the coverage test can pass while the debt stays visible,
    /// and pinned to checklist.md by the test below so it cannot be forgotten
    /// by being quietly deleted from this file.
    ///
    /// "Spiritual father" was here and has been written — Ryan supplied the
    /// definition. It is worth remembering how it was found: not by this scan,
    /// which looks for capitals, but by reading the Brotherhood's plain prose.
    static let awaitingAnEntry = ["Abba", "Apostolic", "Catholic", "Church"]

    private var glossary: Glossary { Glossary.shared }

    /// Every word that looks like a term of art, across everything bundled.
    private func candidates(in paragraphs: [String]) -> Set<String> {
        var found: Set<String> = []
        for paragraph in paragraphs {
            // Split into sentences so a capital at the start is not mistaken
            // for a term.
            for sentence in paragraph.components(separatedBy: CharacterSet(charactersIn: ".!?;:")) {
                let words = sentence
                    .components(separatedBy: CharacterSet.whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                for (index, raw) in words.enumerated() where index > 0 {
                    let word = raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                    guard word.count > 2, let first = word.first, first.isUppercase else { continue }
                    let lowered = word.lowercased()
                    guard !known.contains(lowered) else { continue }
                    guard !Self.awaitingAnEntry.contains(where: { $0.lowercased() == lowered }) else { continue }
                    guard glossary.entry(forTerm: word) == nil else { continue }
                    found.insert(word)
                }
            }
        }
        return found
    }

    @Test("every prayer's terms of art are in the glossary")
    func prayersAreCovered() {
        let unexplained = candidates(in: PrayerBook.bundled.flatMap(\.paragraphs))
        let complaint: Comment = """
            no glossary entry for: \(unexplained.sorted().joined(separator: ", ")). \
            Add entries, or add the word to `known` if a reader needs no help with it.
            """
        #expect(unexplained.isEmpty, complaint)
    }

    @Test("every passage from the fathers is covered too")
    func patristicIsCovered() {
        let unexplained = candidates(in: PatristicReadings.shared.readings.map(\.text))
        let complaint: Comment = """
            no glossary entry for: \(unexplained.sorted().joined(separator: ", ")). \
            Add entries, or add the word to `known` if a reader needs no help with it.
            """
        #expect(unexplained.isEmpty, complaint)
    }

    /// The seven reflections are bundled text like any other, so they are held
    /// to the same rule.
    ///
    /// **What this catches and what it does not.** The scan looks for
    /// capitalised words mid-sentence, which in liturgical English is very
    /// nearly the definition of a term of art. The Brotherhood's prose is plain
    /// modern English and capitalises nothing, so this test guards future edits
    /// to the seven rather than finding much today. Terms of art that appear in
    /// lowercase — "liturgy", "confession", "communion", "spiritual father" —
    /// have to be found by reading. Three of those four the glossary already
    /// explains; the fourth is in `awaitingAnEntry` above.
    @Test("the reflections' terms of art are in the glossary")
    func reflectionsAreCovered() {
        // Titles are excluded: they are headings in title case — "Notice the
        // Resistance" — and the scan reads every capital after the first word
        // as a term. A heading is a label rather than something a reader
        // stumbles through, and the rule is about the prose.
        let text = Reflection.bundled.flatMap { [$0.notice, $0.task] }
        let unexplained = candidates(in: text)
        let complaint: Comment = """
            no glossary entry for: \(unexplained.sorted().joined(separator: ", ")). \
            Add entries, or add the word to `known` if a reader needs no help with it.
            """
        #expect(unexplained.isEmpty, complaint)
    }

    /// The rule stated as a test of the glossary itself: a term the app links
    /// must be explainable.
    @Test("nothing is linked that cannot be opened")
    func everyLinkResolves() {
        for entry in glossary.entries {
            for slug in entry.related {
                #expect(glossary.entry(slug: slug) != nil, "\(entry.term) links to a missing \(slug)")
            }
        }
    }

    /// The debt above has to be written down where a person will see it.
    ///
    /// Otherwise `awaitingAnEntry` becomes the place terms go to be forgotten:
    /// a list in a test file that makes the test pass and tells nobody.
    @Test("terms awaiting an entry are recorded for review")
    func debtIsRecorded() throws {
        let checklist = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("checklist.md"),
            encoding: .utf8
        )
        for term in Self.awaitingAnEntry {
            #expect(checklist.contains(term), "\(term) needs an entry and is not in checklist.md")
        }
    }
}
