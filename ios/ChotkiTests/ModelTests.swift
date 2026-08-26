import Testing
import Foundation
@testable import Chotki
import ChotkiCore

/// The model, driven rather than looked at.
///
/// Core already carries every decision and has its own 353 tests, so these
/// check only what this layer adds: that the right thing reaches the store and
/// that the screen is reading back what was written. That is the seam where
/// every interface bug in this project has lived.
@Suite("The iOS model")
struct ModelTests {

    private func model() throws -> Model {
        // On disk, in a temporary place. The model takes a SQLiteStore, and a
        // test must never touch the real one.
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-test-\(UUID().uuidString).sqlite").path
        return Model(store: try SQLiteStore(path: path))
    }

    private var morningPrayers: RuleTemplate {
        RuleLibrary.bundled.first { $0.id == "morning-prayers" }!
    }

    @Test("a rule taken on appears on the day")
    func takingOnPutsItOnTheDay() throws {
        let model = try model()
        #expect(model.entries(on: model.today).isEmpty)

        model.take(morningPrayers)

        #expect(model.rules.count == 1)
        #expect(model.entries(on: model.today).map(\.rule.title) == ["Morning prayers"])
    }

    @Test("it carries its prayers and its time")
    func itCarriesWhatTheTemplateSaid() throws {
        let model = try model()
        model.take(morningPrayers)

        let rule = try #require(model.rules.first)
        #expect(rule.hasPrayers)
        #expect(rule.timeOfDay?.hour == 6)
        #expect(rule.timeOfDay?.minute == 30)
    }

    @Test("ticking marks the day kept")
    func tickingKeepsIt() throws {
        let model = try model()
        model.take(morningPrayers)
        let entry = try #require(model.entries(on: model.today).first)
        #expect(!entry.isKept)

        model.toggleKept(entry)

        let after = try #require(model.entries(on: model.today).first)
        #expect(after.isKept)
    }

    /// Un-ticking removes the record rather than writing "skipped". Absence is
    /// the default state; skipped means a day deliberately stood down, which
    /// leaves both sides of the score.
    @Test("un-ticking takes the record away rather than writing skipped")
    func unTickingRemovesTheRecord() throws {
        let model = try model()
        model.take(morningPrayers)

        var entry = try #require(model.entries(on: model.today).first)
        model.toggleKept(entry)
        entry = try #require(model.entries(on: model.today).first)
        model.toggleKept(entry)

        let after = try #require(model.entries(on: model.today).first)
        #expect(!after.isKept)
        #expect(after.status == nil, "un-ticking wrote \(String(describing: after.status))")
    }

    /// A rule tied to the church calendar turns on the observance it needs, or
    /// it would sit there never coming due. Android shipped without this on the
    /// hand-written path and a fast-day rule silently never arrived.
    @Test("taking on a fasting rule starts observing fasting")
    func fastingRuleStartsObservance() throws {
        let model = try model()
        let lent = try #require(RuleLibrary.bundled.first { $0.title == "Great Lent" })

        model.take(lent)

        #expect(model.settings.observances.fasting == .observed)
    }

    @Test("what is taken on is known to be taken on")
    func takenIsReported() throws {
        let model = try model()
        #expect(!model.isTaken(morningPrayers))
        model.take(morningPrayers)
        #expect(model.isTaken(morningPrayers))
    }
}

/// The shape of the navigation, as a decision rather than an accident.
///
/// iOS shows five tabs before folding the rest into "More", so the glossary is
/// not one — it is reached by tapping a word that puzzled you, which is how
/// anyone actually arrives there. That is a per-platform arrangement, and it
/// must never become a per-platform *capability*: macOS uses three tabs and
/// Android six, and all three reach the same screens.
@Suite("The shape of the navigation")
struct NavigationTests {

    @Test("five places, which is what a phone shows without an overflow")
    func fivePlaces() {
        #expect(Place.allCases.count == 5)
        #expect(!Place.allCases.map(\.rawValue).contains("Glossary"))
    }

    /// The glossary is not a tab, so it must be a route. If this stops
    /// compiling or the case is removed, the screen has quietly become
    /// unreachable — which is exactly how Android lost its first-run screen.
    @Test("the glossary is reachable even though it is not a tab")
    func glossaryIsReachable() {
        let byTerm = Route.term(slug: "prayer-rule")
        let browsing = Route.term(slug: nil)
        #expect(byTerm != browsing)
    }

    /// Held as values, so a stack cannot guess. Android's navigation was
    /// "which screen is showing" and the back button guessed wrongly for three
    /// rounds before it went back one reliably.
    @Test("routes are values, and distinguish themselves")
    func routesAreValues() {
        let a = UUID(), b = UUID()
        #expect(Route.prayers(ruleID: a) == Route.prayers(ruleID: a))
        #expect(Route.prayers(ruleID: a) != Route.prayers(ruleID: b))
        #expect(Route.editor(ruleID: nil) != Route.editor(ruleID: a))
        #expect(Route.psalter != Route.rope)
    }
}
