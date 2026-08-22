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

    // Modern prayer books, the Jordanville book included, are in copyright.
    // The wording here must come from older public-domain translations.
    @Test("no prayer cites a source still in copyright")
    func sourcesArePublicDomain() {
        let forbidden = ["jordanville", "holy trinity monastery", "st vladimir",
                         "antiochian archdiocese", "oca.org", "ancient faith"]
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

    @Test("every prayer rule opens the same way")
    func rulesOpenAlike() throws {
        for id in ["morning-prayers", "evening-prayers", "trisagion-prayers"] {
            let template = try #require(library.template(id: id))
            #expect(template.prayerIDs.prefix(2) == ["beginning", "heavenly-king"])
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
