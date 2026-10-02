import Testing
@testable import ChotkiCore

@Suite("Pascha, without asking the network")
struct PaschaTests {
    private func on(_ year: Int, _ month: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: year, month: month, day: day)!
    }

    @Test("the civil date and the distance match the church calendar")
    func distances() {
        #expect(Pascha.civil(year: 2026) == on(2026, 4, 12))
        #expect(Pascha.civil(year: 2027) == on(2027, 5, 2))
        #expect(Pascha.distance(on: on(2026, 4, 12)) == 0)
        #expect(Pascha.distance(on: on(2026, 4, 13)) == 1)
        #expect(Pascha.distance(on: on(2026, 12, 31)) == 263)
        #expect(Pascha.distance(on: on(2027, 1, 1)) == 264)
        #expect(Pascha.distance(on: on(2027, 2, 10)) == 304)
        #expect(Pascha.distance(on: on(2027, 2, 13)) == 307)
        #expect(Pascha.distance(on: on(2027, 2, 14)) == -77)
        #expect(Pascha.distance(on: on(2027, 4, 16)) == -16)
        #expect(Pascha.distance(on: on(2027, 5, 2)) == 0)
    }
}

@Suite("The Akathist follows the Fridays of Great Lent")
struct AkathistTests {

    @Test("Friday of the fifth week is the whole hymn, for every tradition")
    func fifthFriday() {
        for tradition in Tradition.allCases {
            #expect(Akathist.week(paschaDistance: -16, tradition: tradition) == 5)
        }
    }

    @Test("the first four Fridays are Greek and Antiochian only")
    func salutations() {
        for distance in [-44, -37, -30, -23] {
            #expect(Akathist.week(paschaDistance: distance, tradition: .greek) != nil)
            #expect(Akathist.week(paschaDistance: distance, tradition: .antiochian) != nil)
            #expect(Akathist.week(paschaDistance: distance, tradition: .russian) == nil)
            #expect(Akathist.week(paschaDistance: distance, tradition: .serbian) == nil)
            #expect(Akathist.week(paschaDistance: distance, tradition: .bulgarian) == nil)
            #expect(Akathist.week(paschaDistance: distance, tradition: .romanian) == nil)
            #expect(Akathist.week(paschaDistance: distance, tradition: .georgian) == nil)
        }
        #expect(Akathist.week(paschaDistance: -44, tradition: .greek) == 1)
        // The Saturday of the Akathist, and the Friday after it, are not the hymn.
        #expect(Akathist.week(paschaDistance: -15, tradition: .greek) == nil)
        #expect(Akathist.week(paschaDistance: -9, tradition: .greek) == nil)
    }

    @Test("a church without its own appointment is shown the OCA's, and says so")
    func ocaFallback() {
        let note = "This is how the Orthodox Church in America keeps it: the whole hymn, on Friday of the fifth week of Great Lent."
        #expect(Akathist.fallbackNote(for: .romanian)?.contains(note) == true)
        #expect(Akathist.fallbackNote(for: .romanian)?.contains("Romanian Orthodox Church") == true)
        #expect(Akathist.fallbackNote(for: .georgian)?.contains("Georgian Orthodox Church") == true)
        for tradition in [Tradition.greek, .antiochian, .russian, .serbian, .bulgarian] {
            #expect(Akathist.hasOwnAppointment(tradition))
            #expect(Akathist.fallbackNote(for: tradition) == nil)
        }
        #expect(Akathist.week(paschaDistance: -16, tradition: .romanian) == 5)
        #expect(Akathist.week(paschaDistance: -44, tradition: .georgian) == nil)
    }

    @Test("Friday 16 April 2027 is the Georgian fifth week, with nothing fetched")
    func georgianFridayDoesNotWaitOnTheCache() throws {
        let georgian = try #require(Jurisdiction.known.first { $0.name == "Georgian Orthodox Church" })
        let service = LiturgicalService(store: InMemoryStore(), jurisdiction: georgian)
        let friday = try #require(CalendarDate(year: 2027, month: 4, day: 16))
        #expect(service.cachedDay(for: friday) == nil)
        #expect(Pascha.distance(on: friday) == -16)
        #expect(service.akathistWeek(friday) == 5)
        #expect(Akathist.fallbackNote(for: .georgian)?.contains("Orthodox Church in America") == true)
    }

    @Test("the hymn's unfamiliar words are in the glossary, and link")
    func glossaryWords() {
        let glossary = Glossary.shared
        let hits = Set(glossary.scanOnce(Akathist.paragraphs(week: 5)).flatMap { $0.map(\.slug) })
        let expected = [
            "theotokos", "bride-unwedded", "incarnation", "holy-ghost", "oblation",
            "intercession", "holy-trinity", "paradise", "manna", "magi", "chaldees",
            "laver", "font", "uncircumscribed", "bodiless", "salutation", "quires",
            "supernal", "incorruption", "ark", "gabriel", "ineffable", "champion-leader",
            "stainless-conception", "type-of-the-resurrection", "redeemer", "mystery",
            "alleluia", "hades", "tabernacle", "cherubim", "seraphim",
        ]
        for slug in expected {
            #expect(hits.contains(slug), "\(slug) is not linked in the hymn")
        }
    }

    @Test("the hymn is twenty-four stanzas, and a Friday reads its part")
    func theText() {
        #expect(Akathist.stanzas.count == 24)
        let first = Akathist.paragraphs(week: 1)
        #expect(first.count == 8)
        #expect(first.first == Akathist.kontakion)
        #expect(first.last == Akathist.kontakion)
        #expect(first[1].hasPrefix("An Angel, and the chiefest"))
        let whole = Akathist.paragraphs(week: 5)
        #expect(whole.count == 28)
        #expect(whole.contains(Akathist.again))
        #expect(whole.dropLast().last?.hasPrefix("An Angel, and the chiefest") == true)
        #expect(Akathist.stanzas.contains { $0.contains("Christ our God") } == false)
    }

    @Test("taking the Akathist on does not start the fast")
    func doesNotObserveFasting() {
        var settings = ObservanceSettings()
        let fasting = settings.fasting
        #expect(settings.setting(for: .akathist) == .observed)
        #expect(ObservanceSettings.name(for: .akathist) == "the Akathist")
        settings.observe(.akathist)
        #expect(settings.fasting == fasting)
    }
}

@Suite("The four library rules")
struct AppointedRuleTests {

    @Test("prayer before meals is the Our Father and the blessing of the table")
    func meals() throws {
        let rule = try #require(RuleLibrary.bundled.first { $0.id == "prayer-before-meals" })
        #expect(rule.prayerIDs == ["our-father", "table-blessing"])
        let blessing = try #require(PrayerBook.shared.prayer(id: "table-blessing"))
        #expect(blessing.paragraphs.last == "Christ our God, bless this meat and drink to Thy servants.")
        #expect(blessing.paragraphs.contains("Lord, have mercy. Lord, have mercy. Lord, have mercy."))
        let made = rule.makeRule()
        #expect(made.reference == .prayers)
    }

    @Test("the Akathist and the departed prayer open on the Reading tab")
    func readings() throws {
        let akathist = try #require(RuleLibrary.bundled.first { $0.id == "akathist" })
        #expect(akathist.prayerIDs.isEmpty)
        #expect(akathist.makeRule().reference == .reading)
        let departed = try #require(RuleLibrary.bundled.first { $0.id == "prayer-for-the-departed" })
        #expect(departed.recurrence == .daily)
        #expect(departed.makeRule().reference == .reading)
        #expect(DepartedCommemoration.paragraphs.count == 3)
    }

    @Test("spiritual reading is gone from the library, and the word remains")
    func spiritualReadingRemoved() {
        #expect(RuleLibrary.bundled.contains { $0.id == "spiritual-reading" } == false)
        #expect(Glossary.shared.entries.contains { $0.slug == "spiritual-reading" })
    }
}
