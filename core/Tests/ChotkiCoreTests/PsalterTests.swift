import Testing
import Foundation
@testable import ChotkiCore

/// The Psalter, as it came from Brenton.
///
/// Nothing here was typed by hand, so these check that the move was faithful
/// rather than that the wording is right — the wording is Brenton's and can be
/// checked against him.
@Suite("The Psalter")
struct PsalterTests {

    @Test("all hundred and fifty-one are there")
    func allThere() {
        #expect(Psalter.all.count == 151)
        #expect(Psalter.all.map(\.number) == Array(1...151))
        for psalm in Psalter.all {
            #expect(!psalm.verses.isEmpty, "psalm \(psalm.number) has no verses")
        }
    }

    /// The markup had to come off cleanly. A stray `\add*` in a psalm is the
    /// kind of thing nobody notices until it is being read aloud.
    @Test("no markup survived the move")
    func noMarkupSurvived() {
        for psalm in Psalter.all {
            for verse in psalm.verses {
                #expect(!verse.text.contains("\\"), "psalm \(psalm.number):\(verse.number) kept markup")
                #expect(!verse.text.contains("  "), "psalm \(psalm.number):\(verse.number) has doubled spaces")
                #expect(verse.text == verse.text.trimmingCharacters(in: .whitespaces))
            }
            #expect(psalm.superscription?.contains("\\") != true)
        }
    }

    /// The titles are verse 1 in the Septuagint, so a psalm that has one begins
    /// its body at 2 — and Psalm 50, whose title runs to two verses, at 3.
    @Test("the superscriptions came off the body")
    func superscriptionsAreSeparate() {
        let third = Psalter.psalm(3)!
        #expect(third.superscription == "A Psalm of David, when he fled from the presence of his son Abessalom.")
        #expect(third.verses.first?.number == "2")

        let fiftieth = Psalter.psalm(50)!
        #expect(fiftieth.superscription?.hasPrefix("For the end, a Psalm of David, when Nathan") == true)
        #expect(fiftieth.verses.first?.number == "3")
        #expect(fiftieth.verses.first?.text.hasPrefix("Have mercy upon me, O God") == true)

        // The first psalm has no title at all.
        #expect(Psalter.psalm(1)?.superscription == nil)
        #expect(Psalter.psalm(1)?.verses.first?.number == "1")
    }

    @Test("the kathismata resolve to real psalms")
    func kathismataResolve() {
        for number in 1...20 {
            let psalms = Psalter.kathisma(number)
            #expect(!psalms.isEmpty, "the \(number)th kathisma is empty")
            let range = Kathisma.psalms(in: number)!
            #expect(psalms.count == range.count, "the \(number)th is short")
        }
        #expect(Psalter.kathisma(17).map(\.number) == [118])
        #expect(Psalter.kathisma(17).first?.verses.count == 175)
    }

    @Test("the source is named, so the wording can be checked")
    func sourceIsNamed() {
        #expect(Psalter.source.contains("Brenton"))
        #expect(Psalter.source.contains("1851"))
        #expect(Psalter.sourceURL.hasPrefix("https://"))
    }
}
