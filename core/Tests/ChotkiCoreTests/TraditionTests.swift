import Testing
import Foundation
@testable import ChotkiCore

@Suite("Jurisdiction and tradition")
struct JurisdictionTests {

    @Test("every listed jurisdiction is complete and self-consistent")
    func knownJurisdictionsAreWellFormed() {
        #expect(!Jurisdiction.known.isEmpty)
        for j in Jurisdiction.known {
            #expect(!j.name.isEmpty)
            #expect(j.practice == PracticeProfile.customary(for: j.tradition),
                    "\(j.name) should start from its tradition's customary practice")
            #expect(!j.practice.notes.isEmpty, "\(j.name) must say where its practice comes from")
        }
    }

    @Test("the default is ROCOR on the Old Calendar")
    func defaults() {
        #expect(Jurisdiction.default.reckoning == .julian)
        #expect(Jurisdiction.default.tradition == .russian)
    }

    // The two axes are genuinely independent, which is the reason they are
    // separate types. The OCA is Russian in tradition and New Calendar in
    // reckoning; the Patriarchate of Jerusalem is Greek and Old Calendar.
    @Test("reckoning and tradition do not track together")
    func axesAreIndependent() throws {
        let oca = try #require(Jurisdiction.known.first { $0.name.contains("America") })
        #expect(oca.tradition == .russian)
        #expect(oca.reckoning == .revisedJulian)

        let jerusalem = try #require(Jurisdiction.known.first { $0.name.contains("Jerusalem") })
        #expect(jerusalem.tradition == .greek)
        #expect(jerusalem.reckoning == .julian)
    }

    @Test("the Julian jurisdictions are the ones that actually keep it")
    func julianJurisdictions() {
        let julian = Set(Jurisdiction.known.filter { $0.reckoning == .julian }.map(\.name))
        #expect(julian.contains { $0.contains("Outside Russia") })
        #expect(julian.contains { $0.contains("Serbian") })
        #expect(julian.contains { $0.contains("Georgian") })
        #expect(!julian.contains { $0.contains("Greek Orthodox Archdiocese") })
        #expect(!julian.contains { $0.contains("Romanian") })
    }

    @Test("practice differs where it genuinely differs")
    func practiceProfiles() {
        let russian = PracticeProfile.customary(for: .russian)
        #expect(russian.confession == .beforeEachCommunion)
        #expect(russian.preparatoryCanons)

        let greek = PracticeProfile.customary(for: .greek)
        #expect(greek.confession == .periodic)
        #expect(!greek.preparatoryCanons)

        // The eucharistic fast is common ground; confession frequency is not.
        #expect(russian.eucharisticFastFromMidnight)
        #expect(greek.eucharisticFastFromMidnight)
    }

    // Everything the app says about practice must be attributable and must
    // point at a priest rather than asserting a rule.
    @Test("every practice profile defers to a priest", arguments: Tradition.allCases)
    func practiceDefersToAPriest(tradition: Tradition) {
        let notes = PracticeProfile.customary(for: tradition).notes.joined(separator: " ").lowercased()
        #expect(notes.contains("priest") || notes.contains("varies"),
                "\(tradition) practice notes must acknowledge variation or point to a priest")
        for forbidden in ["you must", "required to", "obliged"] {
            #expect(!notes.contains(forbidden), "\(tradition) notes read as instruction: \(forbidden)")
        }
    }

    @Test("a jurisdiction can override its tradition's customary practice")
    func practiceIsOverridable() {
        let unusual = Jurisdiction(
            name: "A parish that differs", reckoning: .julian, tradition: .russian,
            practice: PracticeProfile(confession: .periodic, notes: ["Set by my priest."])
        )
        #expect(unusual.confessionNormDiffersFromTradition)
    }
}

@Suite("Glossary scoping")
struct GlossaryScopingTests {
    let glossary = Glossary.shared

    @Test("ROCOR-specific terms reach Russian readers only")
    func russianOnlyTerms() {
        #expect(glossary.scoped(to: .russian).entry(slug: "rocor") != nil)
        #expect(glossary.scoped(to: .greek).entry(slug: "rocor") == nil)
        #expect(glossary.scoped(to: .romanian).entry(slug: "kursk-root-icon") == nil)
        #expect(glossary.scoped(to: .russian).entry(slug: "john-of-shanghai") != nil)
    }

    @Test("Slavic usage reaches the Slavic traditions")
    func slavicTerms() {
        for tradition in [Tradition.russian, .serbian, .bulgarian] {
            #expect(glossary.scoped(to: tradition).entry(slug: "panikhida") != nil,
                    "panikhida should reach \(tradition)")
        }
        #expect(glossary.scoped(to: .greek).entry(slug: "zapivka") == nil)
        #expect(glossary.scoped(to: .antiochian).entry(slug: "radonitsa") == nil)
    }

    @Test("universal terms reach everyone", arguments: Tradition.allCases)
    func universalTerms(tradition: Tradition) {
        let scoped = glossary.scoped(to: tradition)
        for slug in ["pascha", "theotokos", "great-lent", "prayer-rule", "divine-liturgy"] {
            #expect(scoped.entry(slug: slug) != nil, "\(slug) missing for \(tradition)")
        }
    }

    // A scoped glossary that links to an entry the reader cannot open would
    // produce a dead cross-reference in the education pane.
    @Test("scoping never leaves a dangling cross-reference", arguments: Tradition.allCases)
    func noDanglingLinks(tradition: Tradition) {
        let scoped = glossary.scoped(to: tradition)
        let slugs = Set(scoped.entries.map(\.slug))
        for entry in scoped.entries {
            for link in entry.related {
                #expect(slugs.contains(link), "\(entry.slug) links to missing \(link) for \(tradition)")
            }
        }
    }

    @Test("scoping only ever removes entries", arguments: Tradition.allCases)
    func scopingIsSubtractive(tradition: Tradition) {
        let scoped = glossary.scoped(to: tradition)
        #expect(scoped.entries.count <= glossary.entries.count)
        #expect(!scoped.entries.isEmpty)
        #expect(scoped.entries.allSatisfy { $0.appliesTo(tradition) })
    }
}

/// The calendar is its own setting, because a parish is not always its
/// jurisdiction.
@Suite("Setting the calendar apart from the jurisdiction")
struct ReckoningOverrideTests {

    @Test("a known jurisdiction kept as it ships differs from nothing")
    func unchanged() {
        for jurisdiction in Jurisdiction.known {
            #expect(!jurisdiction.reckoningDiffersFromJurisdiction, "\(jurisdiction.name)")
        }
    }

    @Test("changing only the calendar is recorded as a difference")
    func changed() {
        var rocor = Jurisdiction.default
        #expect(rocor.reckoning == .julian)
        rocor.reckoning = .revisedJulian
        #expect(rocor.reckoningDiffersFromJurisdiction)
        #expect(rocor.tradition == .russian, "the practice family is untouched")
    }

    @Test("setting it back stops it being a difference")
    func changedBack() {
        var jurisdiction = Jurisdiction.default
        jurisdiction.reckoning = .revisedJulian
        jurisdiction.reckoning = .julian
        #expect(!jurisdiction.reckoningDiffersFromJurisdiction)
    }

    // Someone may type their own parish in rather than pick from the list.
    @Test("a jurisdiction the app does not know differs from nothing")
    func unknownJurisdiction() {
        let mine = Jurisdiction(name: "St Nicholas, somewhere", reckoning: .revisedJulian, tradition: .russian)
        #expect(!mine.reckoningDiffersFromJurisdiction)
        #expect(mine.asShipped == nil)
    }

    @Test("both calendars reach the right orthocal endpoint")
    func endpoints() {
        #expect(Reckoning.julian.endpointPath == "julian")
        #expect(Reckoning.revisedJulian.endpointPath == "gregorian")
        #expect(Reckoning.allCases.count == 2)
    }
}
