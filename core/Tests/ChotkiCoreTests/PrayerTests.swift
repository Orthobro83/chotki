import Testing
import Foundation
@testable import ChotkiCore

@Suite("The prayers")
struct PrayerTests {
    let book = PrayerBook.shared

    @Test("every prayer is complete and attributed")
    func wellFormed() {
        #expect(!book.prayers.isEmpty)
        for prayer in book.prayers {
            #expect(!prayer.id.isEmpty)
            #expect(!prayer.title.isEmpty)
            #expect(!prayer.paragraphs.isEmpty, "\(prayer.id) has no text")
            #expect(prayer.paragraphs.allSatisfy { !$0.isEmpty }, "\(prayer.id) has an empty line")
            #expect(!prayer.source.isEmpty, "\(prayer.id) must say where the wording comes from")
        }
    }

    @Test("ids are unique")
    func uniqueIDs() {
        let ids = book.prayers.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// Modern prayer books are in copyright, and wording must not arrive from
    /// one by habit.
    ///
    /// **Jordanville is the exception, and only Jordanville.** Ryan obtained
    /// the copyright holder's permission on 2 September 2026 and the whole
    /// prayer book is now the app's wording. Permission from one publisher is
    /// not permission from the rest, so every other name stays on this list —
    /// the guard is doing more work now than it was before, not less.
    @Test("no prayer cites a source still in copyright")
    func sourcesArePublicDomain() {
        let forbidden = ["st vladimir", "antiochian archdiocese",
                         "oca.org", "ancient faith"]
        for prayer in book.prayers {
            let source = prayer.source.lowercased()
            for phrase in forbidden {
                #expect(!source.contains(phrase), "\(prayer.id) cites \(phrase)")
            }
        }
    }

    // A rope prayer is said hundreds of times, so it must be a single unbroken
    // sentence. The upper bound allows "Rejoice, O Virgin Theotokos", which is
    // the longest one genuinely prayed this way — the Rule of the Theotokos is
    // a hundred and fifty repetitions of it.
    @Test("prayers offered for the rope are a single breath")
    func ropePrayersAreShort() {
        let rope = book.forRope()
        #expect(rope.count >= 3)
        for prayer in rope {
            #expect(prayer.paragraphs.count == 1, "\(prayer.id) is more than a single breath")
            #expect(prayer.text.count <= 200, "\(prayer.id) is too long to repeat")
        }
    }

    @Test("the Jesus Prayer is among them")
    func jesusPrayerIsOffered() throws {
        let prayer = try #require(book.prayer(id: "jesus-prayer"))
        #expect(prayer.isForRope)
        #expect(prayer.text.contains("have mercy on me"))
    }

    @Test("looking up a sequence keeps its order")
    func sequenceOrder() {
        let ids = ["our-father", "trisagion", "beginning"]
        #expect(book.prayers(ids).map(\.id) == ids)
    }

    @Test("an unknown id is skipped rather than trapping")
    func unknownIDs() {
        #expect(book.prayers(["our-father", "no-such-prayer"]).map(\.id) == ["our-father"])
        #expect(book.prayer(id: "no-such-prayer") == nil)
    }
}

@Suite("Rules and their prayers")
struct RulePrayerTests {
    let library = RuleLibrary.shared
    let book = PrayerBook.shared

    // A rule pointing at a prayer that does not exist would show an empty
    // screen with no explanation.
    @Test("every prayer a template names actually exists")
    func templateSequencesResolve() {
        for template in library.templates {
            for id in template.prayerIDs {
                #expect(book.prayer(id: id) != nil,
                        "\(template.id) names missing prayer \(id)")
            }
        }
    }

    @Test("the prayer rules carry prayers")
    func prayerRulesHaveText() throws {
        for id in ["morning-prayers", "evening-prayers", "trisagion-prayers"] {
            let template = try #require(library.template(id: id))
            #expect(!template.prayerIDs.isEmpty, "\(id) should carry its prayers")
        }
    }

    /// Every rule carries the Trisagion prayers — the common core of all of
    /// them — whatever else it opens with.
    @Test("every prayer rule carries the common core")
    func rulesShareTheirCore() throws {
        let core = ["beginning", "heavenly-king", "trisagion", "all-holy-trinity", "our-father"]
        for id in ["morning-prayers", "evening-prayers", "trisagion-prayers"] {
            let template = try #require(library.template(id: id))
            for prayer in core {
                #expect(template.prayerIDs.contains(prayer), "\(id) is missing \(prayer)")
            }
        }
    }

    @Test("a rule taken from the library carries its prayers")
    func makeRuleCarriesPrayers() throws {
        let template = try #require(library.template(id: "morning-prayers"))
        let rule = template.makeRule()
        #expect(rule.prayerIDs == template.prayerIDs)
        #expect(rule.hasPrayers)
        #expect(rule.prayers.count == template.prayerIDs.count)
    }

    @Test("a rule with no prayers says so rather than showing nothing")
    func ruleWithoutPrayers() throws {
        let template = try #require(library.template(id: "sunday-liturgy"))
        #expect(template.prayerIDs.isEmpty)
        #expect(!template.makeRule().hasPrayers)
    }

    @Test("prayers survive storage", arguments: StoreKind.allCases)
    func prayersPersist(kind: StoreKind) throws {
        let store = try kind.make()
        let template = try #require(library.template(id: "evening-prayers"))
        let rule = template.makeRule()
        try store.save(rule)
        #expect(try store.rule(id: rule.id)?.prayerIDs == template.prayerIDs)
    }

    @Test("a rule stored without prayers still loads", arguments: StoreKind.allCases)
    func absentPrayersLoad(kind: StoreKind) throws {
        let store = try kind.make()
        let rule = Rule(title: "Workout", recurrence: .daily)
        try store.save(rule)
        let loaded = try #require(try store.rule(id: rule.id))
        #expect(loaded.prayerIDs == nil)
        #expect(!loaded.hasPrayers)
    }
}

/// The places to read prayers beyond the ones bundled here. They are
/// references, not the source of the app's wording — almost all publish modern
/// translations, which are under copyright however freely they can be read.
@Suite("Where to read more")
struct PrayerSourceTests {

    @Test("every reference is complete")
    func wellFormed() {
        #expect(PrayerSources.further.count >= 20)
        for source in PrayerSources.further {
            #expect(!source.title.isEmpty)
            #expect(!source.organisation.isEmpty, "\(source.url) does not say whose it is")
        }
    }

    @Test("every reference is a usable link")
    func linksParse() {
        for source in PrayerSources.further {
            let url = URL(string: source.url)
            #expect(url != nil, "\(source.url) will not open")
            #expect(url?.host != nil, "\(source.url) has no host")
            #expect(["http", "https"].contains(url?.scheme ?? ""), "\(source.url)")
        }
    }

    @Test("no reference is listed twice")
    func noDuplicates() {
        let urls = PrayerSources.further.map(\.url)
        #expect(Set(urls).count == urls.count)
    }

    // Attribution that does not open is worse than none: it looks checkable
    // and is not.
    @Test("a prayer that cites a link has one that works")
    func prayerLinksParse() {
        for prayer in PrayerBook.shared.prayers {
            guard let link = prayer.sourceURL else { continue }
            let url = URL(string: link)
            #expect(url != nil, "\(prayer.id) has an unusable source link")
            #expect(url?.host != nil, "\(prayer.id)")
        }
    }

    // The bundled wording is public domain. If a prayer ever cites one of these
    // sites as its *source*, the text almost certainly came from there too.
    @Test("no bundled prayer claims one of these sites as its source")
    func bundledTextIsNotTakenFromThem() {
        let referenceHosts = Set(PrayerSources.further.compactMap { URL(string: $0.url)?.host })
        for prayer in PrayerBook.shared.prayers {
            guard let host = prayer.sourceURL.flatMap({ URL(string: $0)?.host }) else { continue }
            #expect(!referenceHosts.contains(host),
                    "\(prayer.id) cites \(host), whose translation is under copyright")
        }
    }
}

/// A rule said through from beginning to end, as opposed to one prayer
/// repeated. Defined once so the library and the rope cannot drift apart.
@Suite("Prayer sequences")
struct PrayerSequenceTests {
    let book = PrayerBook.shared

    @Test("every sequence names prayers that exist", arguments: PrayerSequence.all)
    func sequencesResolve(sequence: PrayerSequence) {
        #expect(!sequence.prayerIDs.isEmpty)
        for id in sequence.prayerIDs {
            #expect(book.prayer(id: id) != nil, "\(sequence.id) names missing \(id)")
        }
        #expect(book.prayers(of: sequence).count == sequence.prayerIDs.count)
    }

    @Test("morning and evening are both offered")
    func bothRulesPresent() {
        let ids = PrayerSequence.all.map(\.id)
        #expect(ids.contains("morning"))
        #expect(ids.contains("evening"))
    }

    @Test("a sequence keeps its order")
    func order() {
        #expect(book.prayers(of: .morning).map(\.id) == PrayerSequence.morning.prayerIDs)
    }

    /// Both rules begin with the Trisagion prayers, which is what makes them
    /// recognisably one tradition's rules rather than two lists.
    ///
    /// Not "the first id is the same": Jordanville opens the morning with the
    /// Publican's prayer and three bows before the Opening Prayer, and opens
    /// the evening with the Opening Prayer directly. That difference is the
    /// book's and is not ours to flatten.
    @Test("each rule opens with the Trisagion prayers")
    func opensAlike() {
        for sequence in [PrayerSequence.morning, .evening] {
            #expect(sequence.prayerIDs.prefix(3).contains("opening-prayer"), "\(sequence.id)")
            #expect(sequence.prayerIDs.contains("our-father"), "\(sequence.id)")
        }
    }

    @Test("morning and evening differ where they should")
    func rulesDiffer() {
        // Each has prayers the other does not: the morning its Troparia to the
        // Holy Trinity, the evening its Kontakion and its confession of sins.
        #expect(PrayerSequence.morning.prayerIDs.contains("troparia-to-the-holy-trinity"))
        #expect(!PrayerSequence.evening.prayerIDs.contains("troparia-to-the-holy-trinity"))
        #expect(PrayerSequence.evening.prayerIDs.contains("daily-confession-of-sins"))
        #expect(!PrayerSequence.morning.prayerIDs.contains("daily-confession-of-sins"))
    }

    // One definition, used by both. If a template ever carried its own list
    // again, the two would drift and nobody would notice.
    @Test("the library takes its sequences from here")
    func libraryUsesTheSameDefinition() throws {
        let library = RuleLibrary.shared
        for (id, sequence) in [("morning-prayers", PrayerSequence.morning),
                               ("evening-prayers", PrayerSequence.evening),
                               ("trisagion-prayers", PrayerSequence.trisagionPrayers)] {
            let template = try #require(library.template(id: id))
            #expect(template.prayerIDs == sequence.prayerIDs, "\(id) has drifted")
        }
    }

    @Test("a sequence id is never also a prayer id")
    func idsDoNotCollide() {
        // The rope picker keys on one field for both, so a collision would make
        // a sequence unselectable.
        let prayerIDs = Set(book.prayers.map(\.id))
        for sequence in PrayerSequence.all {
            #expect(!prayerIDs.contains(sequence.id), "\(sequence.id) collides with a prayer")
        }
    }
}

/// Whether the rope belongs alongside what is being prayed.
@Suite("When the rope belongs")
struct RopeBelongsTests {
    let book = PrayerBook.shared

    @Test("choosing nothing brings the rope")
    func nothingChosen() {
        #expect(book.ropeBelongs(with: nil))
        #expect(book.ropeBelongs(with: ""))
    }

    @Test("a counted prayer brings the rope", arguments: [
        "jesus-prayer", "jesus-prayer-short", "publican", "lord-have-mercy", "rejoice-o-virgin"
    ])
    func countedPrayers(id: String) {
        #expect(book.prayer(id: id)?.isForRope == true, "\(id) should be marked as counted")
        #expect(book.ropeBelongs(with: id))
    }

    // A rule is read through from beginning to end, not repeated.
    @Test("a rule does not", arguments: PrayerSequence.all.map(\.id))
    func rulesDoNot(id: String) {
        #expect(!book.ropeBelongs(with: id))
    }

    // Saint Ioannikios closes the evening rule; it is said once. It was wrongly
    // marked as counted when it was added.
    @Test("a prayer that is read does not", arguments: ["creed", "ephrem", "ioannikios", "it-is-truly-meet"])
    func readPrayersDoNot(id: String) {
        #expect(book.prayer(id: id) != nil, "\(id) should exist")
        #expect(!book.ropeBelongs(with: id))
    }

    @Test("an unknown selection brings the rope rather than nothing")
    func unknownSelection() {
        #expect(book.ropeBelongs(with: "no-such-prayer"))
    }

    @Test("every counted prayer is a single breath")
    func countedPrayersAreShort() {
        for prayer in book.forRope() {
            #expect(prayer.paragraphs.count == 1, "\(prayer.id)")
        }
    }

    @Test("the two groups together are every prayer")
    func groupsPartitionTheBook() {
        #expect(book.forRope().count + book.notForRope().count == book.prayers.count)
        #expect(!book.forRope().isEmpty)
        #expect(!book.notForRope().isEmpty)
    }
}

/// The prayers screen's state, which outlives the view it is drawn in.
@Suite("The prayers screen")
struct PrayerScreenTests {

    @Test("the rope follows the prayer")
    func ropeFollowsSelection() {
        var screen = PrayerScreen(selection: nil)
        #expect(screen.showsRope(), "nothing chosen shows the rope")

        screen.choose("jesus-prayer")
        #expect(screen.showsRope())

        screen.choose("morning")
        #expect(!screen.showsRope(), "a rule is read, not counted")
    }

    @Test("the reader can overrule it")
    func overrule() {
        var screen = PrayerScreen(selection: "morning")
        #expect(!screen.showsRope())
        screen.showRope(true)
        #expect(screen.showsRope())
    }

    // Otherwise "hide" pressed once on the Creed would silently hide the rope
    // behind the Jesus Prayer chosen ten minutes later.
    @Test("choosing again goes back to following the prayer")
    func choosingClearsTheOverride() {
        var screen = PrayerScreen(selection: "jesus-prayer")
        screen.showRope(false)
        #expect(!screen.showsRope())

        screen.choose("publican")
        #expect(screen.showsRope())
    }

    @Test("choosing what is already chosen changes nothing")
    func reChoosingIsInert() {
        var screen = PrayerScreen(selection: "jesus-prayer")
        screen.showRope(false)
        screen.choose("jesus-prayer")
        #expect(!screen.showsRope(), "the override survives")
    }

    @Test("counting stops at the target and reports the knot")
    func counting() {
        var screen = PrayerScreen(count: 0, target: 3)
        #expect(screen.advance() == false)
        #expect(screen.advance() == false)
        #expect(screen.advance() == true, "the third completes it")
        #expect(screen.isComplete)
        #expect(screen.advance() == false, "no further")
        #expect(screen.count == 3)
    }

    @Test("a new target starts the count again")
    func aiming() {
        var screen = PrayerScreen(count: 40, target: 50)
        screen.aim(at: 33)
        #expect(screen.count == 0, "40 of 33 would show a knot already complete")
        #expect(screen.target == 33)
    }

    @Test("the offered targets are the traditional ones")
    func targets() {
        #expect(PrayerScreen.targets == [33, 50, 100])
    }

    // MARK: leaning on the space bar

    /// The Mac's Count button answers the space bar, and holding a key down
    /// makes the system repeat it — fast, if that is how the reader has set
    /// their keyboard. Without a floor, one lean on the bar writes a whole
    /// knot nobody prayed.
    @Test("a second knot inside the interval does not count")
    func repeatsInsideTheIntervalAreRefused() {
        var screen = PrayerScreen(count: 0, target: 33, minimumInterval: 1)
        let start = Date(timeIntervalSince1970: 1_000)

        screen.advance(at: start)
        #expect(screen.count == 1)

        // Key repeat: twenty presses, all well inside a second.
        for tick in 1...20 {
            screen.advance(at: start.addingTimeInterval(Double(tick) * 0.03))
        }
        #expect(screen.count == 1, "twenty repeats inside a second counted more than one knot")
    }

    @Test("a knot counts again once the interval has passed")
    func advancingAfterTheIntervalCounts() {
        var screen = PrayerScreen(count: 0, target: 33, minimumInterval: 1)
        let start = Date(timeIntervalSince1970: 1_000)

        screen.advance(at: start)
        screen.advance(at: start.addingTimeInterval(1.0))
        screen.advance(at: start.addingTimeInterval(2.5))
        #expect(screen.count == 3)
    }

    /// A phone has no space bar and no key repeat, so a tap must always count.
    /// The floor is opt-in for exactly that reason.
    @Test("without an interval every press counts, which is what a tap does")
    func withoutAnIntervalEveryPressCounts() {
        var screen = PrayerScreen(count: 0, target: 33)
        let start = Date(timeIntervalSince1970: 1_000)
        for tick in 0..<10 {
            screen.advance(at: start.addingTimeInterval(Double(tick) * 0.01))
        }
        #expect(screen.count == 10)
    }

    /// Starting over is a deliberate act, not a stray repeat.
    @Test("starting again lets the next knot count at once")
    func startingAgainClearsTheInterval() {
        var screen = PrayerScreen(count: 0, target: 33, minimumInterval: 1)
        let start = Date(timeIntervalSince1970: 1_000)

        screen.advance(at: start)
        screen.startAgain()
        screen.advance(at: start.addingTimeInterval(0.01))
        #expect(screen.count == 1, "the first knot after starting again was refused")

        screen.aim(at: 50)
        screen.advance(at: start.addingTimeInterval(0.02))
        #expect(screen.count == 1, "the first knot after changing the target was refused")
    }
}

/// The parts of the book that are followed rather than kept as a rule.
@Suite("The service texts")
struct ServiceTextTests {

    @Test("the book's sections are all there, in the book's order")
    func allPresent() {
        let all = ServiceTexts.all
        #expect(all.count == 23)
        #expect(all.first?.id == "vespers")
        #expect(all.last?.id == "the-jesus-prayer")
        #expect(all.contains { $0.id == "divine-liturgy" })
    }

    @Test("every text has a title and something in it")
    func nonEmpty() {
        for text in ServiceTexts.all {
            #expect(!text.title.isEmpty, "\(text.id)")
            #expect(!text.paragraphs.isEmpty, "\(text.id)")
            #expect(text.paragraphs.allSatisfy { !$0.isEmpty }, "\(text.id)")
        }
    }

    /// The scan left marks the cleaner had to repair. A backslash or a brace
    /// surviving into the app means a repair was missed, and the reader meets
    /// "&ader" where the book says "Reader".
    @Test("no scanner damage survived into the text")
    func noResidualDamage() {
        let damage = CharacterSet(charactersIn: "\\|~^{}<>@#$%&£")
        for text in ServiceTexts.all {
            for paragraph in text.paragraphs {
                #expect(
                    paragraph.rangeOfCharacter(from: damage) == nil,
                    "\(text.id): \(paragraph.prefix(70))"
                )
            }
        }
    }

    @Test("ids are unique, so a link cannot land on two texts")
    func idsAreUnique() {
        let ids = ServiceTexts.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("the source is named, as every bundled text must be")
    func cited() {
        #expect(ServiceTexts.source.contains("Jordanville"))
        #expect(!ServiceTexts.sourceURL.isEmpty)
    }
}

/// A rule keeps the prayer ids it was taken on with, so changing the book's
/// wording moves the content out from under every rule already on someone's
/// phone. Nothing crashes — `prayers(_:)` drops what it cannot find — which is
/// exactly why it needs a test rather than a bug report.
@Suite("Rules survive the book changing under them")
struct StalePrayerRepairTests {

    private let library = RuleLibrary.shared

    @Test("a rule pointing at the old wording is given the new")
    func staleRuleIsRepaired() {
        // What a morning rule kept since August actually holds: Hapgood ids,
        // most of which Jordanville renamed.
        var rule = Rule(title: "Morning prayers", recurrence: .daily)
        rule.prayerIDs = ["opening-prayer", "beginning", "heavenly-king",
                          "having-risen", "macarius", "guardian-angel"]

        let restored = library.restoredPrayerIDs(for: rule)
        #expect(restored != nil, "a rule holding dead ids was left alone")
        #expect(restored?.count ?? 0 > 20, "the whole Jordanville morning rule should come back")
    }

    @Test("a rule that is merely edited is left alone")
    func editedRuleIsNotClobbered() {
        // Every id still resolves: the reader dropped some prayers on purpose.
        var rule = Rule(title: "Morning prayers", recurrence: .daily)
        rule.prayerIDs = ["publican", "our-father"]
        #expect(library.restoredPrayerIDs(for: rule) == nil)
    }

    @Test("a rule set to no prayers stays that way")
    func emptyStaysEmpty() {
        var rule = Rule(title: "Morning prayers", recurrence: .daily)
        rule.prayerIDs = []
        #expect(library.restoredPrayerIDs(for: rule) == nil)
    }

    @Test("a rule that never had prayers still gets them")
    func nilIsStillFilled() {
        let rule = Rule(title: "Morning prayers", recurrence: .daily)
        #expect(library.restoredPrayerIDs(for: rule)?.isEmpty == false)
    }

    @Test("a rule of someone's own is never touched")
    func customRuleUntouched() {
        var rule = Rule(title: "My own rule", recurrence: .daily)
        rule.prayerIDs = ["macarius", "having-risen"]
        #expect(library.restoredPrayerIDs(for: rule) == nil)
    }
}
