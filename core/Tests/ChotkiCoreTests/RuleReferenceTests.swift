import Testing
import Foundation
@testable import ChotkiCore

/// A rule that names a text the app is holding must be one tap from it.
///
/// The reading rules were not, on either platform, for months: the row asked
/// `hasPrayers` and the day's Gospel does not carry prayers. It is a text the
/// app holds all the same, and the question the row should have been asking is
/// whether there is anything to read.
@Suite("What a rule points at")
struct RuleReferenceTests {

    private var library: [Rule] { RuleLibrary.bundled.map { $0.makeRule() } }

    @Test("every reading rule leads to the readings")
    func readingRulesLeadToTheReadings() {
        let readings = library.filter { $0.category == RuleCategory.reading.rawValue }
        #expect(!readings.isEmpty, "the library has no reading rules, so this proves nothing")
        for rule in readings {
            #expect(rule.reference == .reading, "\(rule.title) has no way to its text")
        }
    }

    /// Carrying prayers means leading to them, but not always to the same
    /// screen: a rule whose whole text is one counted prayer belongs on the
    /// rope, with the count already running, rather than on a page holding a
    /// single short paragraph.
    @Test("every rule carrying prayers leads to them")
    func prayerRulesLeadToTheirPrayers() {
        let carrying = library.filter { $0.hasPrayers }
        #expect(!carrying.isEmpty)
        for rule in carrying {
            let expected: RuleReference = rule.ropePrayerID == nil ? .prayers : .rope
            #expect(rule.reference == expected, "\(rule.title) has no way to its prayers")
        }
    }

    /// The rope has to arrive already counting something, or "ready to begin"
    /// is a claim the screen does not keep.
    @Test("a rule that leads to the rope names the prayer the rope will count")
    func ropeRulesNameTheirPrayer() {
        let onTheRope = library.filter { $0.reference == .rope }
        #expect(!onTheRope.isEmpty, "the library has no rope rules, so this proves nothing")
        for rule in onTheRope {
            let id = rule.ropePrayerID
            #expect(id != nil, "\(rule.title) leads to the rope with no prayer")
            let prayer = id.flatMap { PrayerBook.shared.prayer(id: $0) }
            #expect(prayer != nil, "\(rule.title) names a prayer that is not in the book")
            #expect(prayer?.isForRope == true, "\(rule.title) sends a read-through prayer to the rope")
        }
    }

    /// The inverse, which is the half that stops this becoming a lie: a rule
    /// offering a link must have something at the other end of it.
    @Test("nothing points at a text that is not there")
    func nothingPointsAtNothing() {
        for rule in library where rule.reference == .prayers {
            for id in rule.prayerIDs ?? [] {
                #expect(
                    PrayerBook.bundled.contains { $0.id == id },
                    "\(rule.title) points at a prayer \(id) that is not shipped"
                )
            }
        }
    }

    @Test("the Psalter rule leads to the Psalter")
    func thePsalterRuleLeadsToThePsalter() {
        let rule = library.first { $0.title == psalterRuleTitle }
        #expect(rule != nil, "the library no longer has the Psalter rule under that title")
        #expect(rule?.reference == .psalter)
    }

    /// The title is the only handle there is, so a change to it must not
    /// silently sever the link.
    @Test("the library still uses the title the reference matches on")
    func theTitleStillMatches() {
        #expect(RuleLibrary.bundled.contains { $0.title == psalterRuleTitle })
    }
}

/// Ryan: "so that information about the rule is clickable and gives the user
/// meaningful information about the rule."
@Suite("What a rule means")
struct RuleGlossaryTests {
    private var library: [Rule] { RuleLibrary.bundled.map { $0.makeRule() } }

    @Test("every rule taken from the library can be looked up")
    func everyLibraryRuleExplained() {
        let mute = library.filter { $0.glossarySlug == nil }.map(\.title)
        #expect(mute.isEmpty, "nothing to open: \(mute.joined(separator: ", "))")
    }

    @Test("the curated entry wins over anything the title happens to contain")
    func curatedWins() {
        let lent = library.first { $0.title == "Great Lent" }
        #expect(lent?.glossarySlug == "great-lent")
    }

    /// The case the scan exists for. Renaming a rule is normal and expected —
    /// the library is a starting point — and a renamed rule should not go mute.
    @Test("a renamed rule is still recognised by what its name contains")
    func renamedStillFound() {
        var rule = Rule(title: "The Jesus Prayer, 33 repetitions", recurrence: .daily)
        #expect(rule.glossarySlug == "jesus-prayer")
        rule.title = "Cold plunge"
        #expect(rule.glossarySlug == nil, "and a rule of one's own stays the person's own")
    }
}
