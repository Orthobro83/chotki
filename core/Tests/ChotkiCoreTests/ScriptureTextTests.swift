import Testing
import Foundation
@testable import ChotkiCore

@Suite("Scripture text and paragraphs")
struct ScriptureTextTests {

    private func verse(_ chapter: Int, _ number: Int, _ text: String, book: String = "MAT", opens: Bool = false) -> ScriptureText.Verse {
        ScriptureText.Verse(book: book, chapter: chapter, verse: number, text: text, opensParagraph: opens)
    }

    @Test("verses run on with a space, and a paragraph opener gets a blank line")
    func paragraphs() {
        let text = ScriptureText.join([
            verse(1, 1, "One.", opens: true), verse(1, 2, "Two."),
            verse(1, 3, "Three.", opens: true), verse(1, 4, "Four.")
        ])
        #expect(text == "One. Two.\n\nThree. Four.")
    }

    @Test("the first verse never gets a break, and an empty list is empty")
    func firstVerse() {
        #expect(ScriptureText.join([verse(5, 1, "Alone.", opens: true)]) == "Alone.")
        #expect(ScriptureText.join([]) == "")
    }

    @Test("separate passages do not run together, but a chapter's last verse flows into the next chapter")
    func gaps() {
        let apart = ScriptureText.join([verse(1, 1, "A."), verse(1, 5, "B.")])
        #expect(apart == "A.\n\nB.")
        let across = ScriptureText.join([verse(1, 30, "A."), verse(2, 1, "B.")])
        #expect(across == "A. B.")
        let otherBook = ScriptureText.join([verse(1, 1, "A."), verse(1, 2, "B.", book: "MRK")])
        #expect(otherBook == "A.\n\nB.")
    }

    @Test("the bundled Bible has every verse, and the paragraph openers its source marks")
    func bibleIntegrity() {
        #expect(ScriptureText.Bible.shared.verseCount == 36_820)
        // Matthew 11:28 opens a paragraph in the source; verse 29 does not.
        #expect(ScriptureText.Bible.shared.verse(book: "MAT", chapter: 11, verse: 28)?.opensParagraph == true)
        #expect(ScriptureText.Bible.shared.verse(book: "MAT", chapter: 11, verse: 29)?.opensParagraph == false)
        #expect(ScriptureText.Bible.shared.verse(book: "MAT", chapter: 11, verse: 28)?.text.hasPrefix("Come unto me") == true)
    }

    @Test("no pilcrow reaches the text: paragraphs are structure, not a symbol")
    func noPilcrow() throws {
        let text = try #require(ScriptureText.text(for: [PassageRun(book: "LUK", chapter: 6, first: 17, last: 20)]))
        #expect(!text.contains("\u{00B6}"))
        #expect(text.hasPrefix("And he came down with them"))
    }

    @Test("a run with a verse the Bible does not have yields no text, not wrong text")
    func missingVerse() {
        #expect(ScriptureText.text(for: [PassageRun(book: "JHN", chapter: 3, first: 1, last: 400)]) == nil)
        #expect(ScriptureText.text(for: [PassageRun(book: "XXX", chapter: 1, first: 1, last: 1)]) == nil)
        #expect(ScriptureText.text(for: []) == nil)
    }

    @Test("a run is stored as a four-item array")
    func runCoding() throws {
        let runs = try JSONDecoder().decode([PassageRun].self, from: Data(#"[["PRO",10,1,32],["WIS",6,1,25]]"#.utf8))
        #expect(runs == [PassageRun(book: "PRO", chapter: 10, first: 1, last: 32),
                         PassageRun(book: "WIS", chapter: 6, first: 1, last: 25)])
        let back = try JSONDecoder().decode([PassageRun].self, from: JSONEncoder().encode(runs))
        #expect(back == runs)
    }

    @Test("all twenty-two Composite readings resolve to scripture")
    func composites() throws {
        let table = ScriptureText.Bible.composites
        #expect(table.count == 22)
        for (display, runs) in table {
            let text = try #require(ScriptureText.text(for: runs), "\(display)")
            #expect(!text.isEmpty)
        }
        // Composite 12 cites 3 [1] Kings 17.1-23, which is 1 Kings in the KJV and is 23 verses.
        let twelve = try #require(table["Composite 12 - 3 [1] Kings 17.1-23"])
        #expect(twelve == [PassageRun(book: "1KI", chapter: 17, first: 1, last: 23)])
        // 3 [1] Kings is not 1 Samuel: an earlier draft resolved it there by mistake.
        #expect(table.values.joined().allSatisfy { $0.book != "1SA" && $0.book != "2SA" })
    }
}
