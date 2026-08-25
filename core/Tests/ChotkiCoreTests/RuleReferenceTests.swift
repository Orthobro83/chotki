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

    @Test("every rule carrying prayers leads to them")
    func prayerRulesLeadToTheirPrayers() {
        let carrying = library.filter { $0.hasPrayers }
        #expect(!carrying.isEmpty)
        for rule in carrying {
            #expect(rule.reference == .prayers, "\(rule.title) has no way to its prayers")
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
}
