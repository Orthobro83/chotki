import Testing
import Foundation
@testable import ChotkiCore

@Suite("Rule library")
struct RuleLibraryTests {
    let library = RuleLibrary.shared
    let glossary = Glossary.shared

    @Test("every template is complete and well formed")
    func wellFormed() {
        #expect(!library.templates.isEmpty)
        for template in library.templates {
            #expect(!template.id.isEmpty)
            #expect(!template.title.isEmpty)
            #expect(!template.summary.isEmpty, "\(template.id) must say what taking it on means")
            #expect(template.summary.count < 130, "\(template.id) summary is too long for a library row")
        }
    }

    @Test("template ids are unique")
    func uniqueIDs() {
        let ids = library.templates.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("every glossary reference resolves")
    func glossaryReferencesResolve() {
        for template in library.templates {
            for slug in template.glossarySlugs {
                #expect(glossary.entry(slug: slug) != nil,
                        "\(template.id) references missing glossary entry \(slug)")
            }
        }
    }

    @Test("every category in the library has something in it")
    func categoriesPopulated() {
        let grouped = library.byCategory()
        #expect(grouped.count == RuleCategory.allCases.count)
        for (category, templates) in grouped {
            #expect(!templates.isEmpty, "\(category) is empty")
        }
    }

    // Enabling copies. A rule taken from the library and one written from
    // scratch must be the same kind of thing afterwards.
    @Test("enabling a template produces an independent rule")
    func makeRuleCopies() throws {
        let template = try #require(library.template(id: "morning-prayers"))
        let first = template.makeRule(source: "the library")
        let second = template.makeRule()

        #expect(first.id != second.id, "each copy is its own rule")
        #expect(first.title == template.title)
        #expect(first.timeOfDay == template.timeOfDay)
        #expect(first.source == "the library")
        #expect(first.category == RuleCategory.prayer.rawValue)

        // And it can be changed without touching the template.
        var edited = first
        edited.title = "Morning prayers, short form"
        #expect(template.title == "Morning prayers")
        #expect(edited.title != first.title)
    }

    @Test("tradition-specific templates are scoped")
    func scoping() {
        #expect(library.scoped(to: .russian).template(id: "prayer-for-the-departed") != nil)
        #expect(library.scoped(to: .greek).template(id: "prayer-for-the-departed") == nil)
        // Universal ones reach everyone.
        for tradition in Tradition.allCases {
            #expect(library.scoped(to: tradition).template(id: "morning-prayers") != nil)
        }
    }

    // The library is the first thing a newcomer reads. It must describe, never
    // grade, and never imply a standard they are already failing.
    @Test("no template implies a standard or shames")
    func toneIsClean() {
        let forbidden = [
            "you must", "you should", "required", "obliged", "at minimum",
            "failure", "fall short", "properly", "serious christian", "real orthodox"
        ]
        for template in library.templates {
            let text = ([template.title, template.summary, template.note ?? ""])
                .joined(separator: " ").lowercased()
            for phrase in forbidden {
                #expect(!text.contains(phrase), "\(template.id) contains \"\(phrase)\"")
            }
        }
    }

    // Where practice genuinely varies, the library says so instead of picking
    // a side and presenting it as the norm.
    @Test("templates about contested practice defer to a priest")
    func contestedPracticeDefers() throws {
        for id in ["confession", "communion"] {
            let template = try #require(library.template(id: id))
            let text = (template.summary + " " + (template.note ?? "")).lowercased()
            #expect(text.contains("priest") || text.contains("practice"),
                    "\(id) should acknowledge that practice varies")
        }
    }

    @Test("a template that not everyone can keep says so")
    func unattendableTemplatesAcknowledgeIt() throws {
        let feast = try #require(library.template(id: "great-feast-liturgy"))
        let text = (feast.summary + " " + (feast.note ?? "")).lowercased()
        #expect(text.contains("able") || text.contains("reach"),
                "attending a feast Liturgy assumes a parish within reach")
    }
}

@Suite("App settings")
struct AppSettingsTests {

    @Test("defaults are the cautious ones")
    func defaults() {
        let settings = AppSettings.default
        #expect(settings.jurisdiction.reckoning == .julian)
        #expect(settings.observances.fasting == .shown, "shown, not observed")
        #expect(settings.observances.feasts == .shown)
        #expect(settings.reminders.notificationsEnabled)
        #expect(!settings.hasCompletedFirstRun)
    }

    @Test("settings survive a round trip")
    func codable() throws {
        var settings = AppSettings.default
        settings.jurisdiction = Jurisdiction(name: "Greek", reckoning: .revisedJulian, tradition: .greek)
        settings.observances = ObservanceSettings(fasting: .hidden, feasts: .observed)
        settings.reminders.defaultLead = .oneHour
        settings.showOldStyleDates = true

        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == settings)
    }
}

/// Rules taken from the library before rules carried prayers.
@Suite("Restoring prayers to older rules")
struct RestoredPrayersTests {
    let library = RuleLibrary.shared

    private func rule(_ title: String, prayers: [String]? = nil) -> Rule {
        Rule(title: title, recurrence: .daily, prayerIDs: prayers)
    }

    // The rule that found this: taken on 20 August, two days before prayers
    // existed, so its column was null and it offered no way to the words.
    @Test("evening prayers gets the evening rule back")
    func eveningPrayers() {
        let restored = library.restoredPrayerIDs(for: rule("Evening prayers"))
        #expect(restored == PrayerSequence.evening.prayerIDs)
        #expect(!(restored ?? []).isEmpty)
    }

    @Test("so does every template that carries prayers")
    func everyTemplateWithPrayers() {
        for template in library.templates where !template.prayerIDs.isEmpty {
            let restored = library.restoredPrayerIDs(for: rule(template.title))
            #expect(restored == template.prayerIDs, "\(template.id)")
        }
    }

    @Test("a rule that already has prayers is left alone")
    func alreadySet() {
        #expect(library.restoredPrayerIDs(for: rule("Evening prayers", prayers: ["jesus-prayer"])) == nil)
    }

    // Empty is a decision — someone cleared them — and nil is an absence.
    @Test("prayers deliberately set to none are not overwritten")
    func deliberatelyEmpty() {
        #expect(library.restoredPrayerIDs(for: rule("Evening prayers", prayers: [])) == nil)
    }

    @Test("a rule of one's own is not guessed at")
    func ownRule() {
        #expect(library.restoredPrayerIDs(for: rule("Morning Prayer")) == nil, "singular: his own rule")
        #expect(library.restoredPrayerIDs(for: rule("Workout")) == nil)
    }

    @Test("the title match ignores case")
    func caseInsensitive() {
        #expect(library.restoredPrayerIDs(for: rule("evening PRAYERS")) == PrayerSequence.evening.prayerIDs)
    }

    @Test("a template without prayers restores nothing")
    func noPrayers() {
        #expect(library.restoredPrayerIDs(for: rule("The Wednesday and Friday fast")) == nil)
    }

    @Test("only what changed comes back")
    func onlyChanged() {
        let repaired = library.restoringPrayers(in: [
            rule("Evening prayers"),
            rule("Workout"),
            rule("Morning prayers"),
            rule("The Jesus Prayer", prayers: ["jesus-prayer"]),
        ])
        #expect(repaired.count == 2)
        #expect(repaired.allSatisfy { !($0.prayerIDs ?? []).isEmpty })
        #expect(repaired.contains { $0.title == "Evening prayers" })
        #expect(repaired.contains { $0.title == "Morning prayers" })
    }

    @Test("every restored id is a prayer that exists")
    func restoredIDsResolve() {
        for template in library.templates {
            for id in template.prayerIDs {
                #expect(PrayerBook.shared.prayer(id: id) != nil, "\(template.id) → \(id)")
            }
        }
    }
}

/// Rules of one's own, kept so they can be taken up again.
@Suite("The custom library")
struct CustomLibraryTests {

    private func own(_ title: String, days: Int = 0, hidden: Bool? = nil) -> Rule {
        Rule(
            title: title, recurrence: .daily,
            createdAt: Date().addingTimeInterval(TimeInterval(days) * 86_400),
            hiddenFromLibrary: hidden
        )
    }

    @Test("a rule of one's own is one the bundled library does not have")
    func isOwn() {
        #expect(CustomLibrary.isOwn(own("Cold plunge")))
        #expect(CustomLibrary.isOwn(own("Workout")))
        #expect(!CustomLibrary.isOwn(own("Evening prayers")), "that one is the library's")
        #expect(!CustomLibrary.isOwn(own("evening PRAYERS")), "and case does not change it")
    }

    // source looks like provenance and is not: it is a free-text note the
    // person edits, so it cannot be trusted to say where a rule came from.
    @Test("the free-text source is not what decides it")
    func sourceIsNotProvenance() {
        var rule = own("Cold plunge")
        rule.source = "the library"
        #expect(CustomLibrary.isOwn(rule), "still his own, whatever the note says")
    }

    @Test("entries are newest first")
    func newestFirst() {
        let entries = CustomLibrary.entries(from: [
            own("Older", days: -3), own("Newest", days: -1), own("Oldest", days: -9),
        ])
        #expect(entries.map(\.title) == ["Newest", "Older", "Oldest"])
    }

    @Test("the library's own rules are not offered as custom")
    func bundledExcluded() {
        let entries = CustomLibrary.entries(from: [own("Cold plunge"), own("Evening prayers")])
        #expect(entries.map(\.title) == ["Cold plunge"])
    }

    @Test("a rule set aside is not offered")
    func setAsideExcluded() {
        let entries = CustomLibrary.entries(from: [own("Cold plunge", hidden: true), own("Kathisma")])
        #expect(entries.map(\.title) == ["Kathisma"])
    }

    @Test("setting aside touches nothing else")
    func settingAsideIsNarrow() {
        var rule = own("Cold plunge")
        rule.archivedAt = nil
        let aside = CustomLibrary.settingAside(rule)
        #expect(aside.hiddenFromLibrary == true)
        #expect(aside.id == rule.id)
        #expect(aside.title == rule.title)
        #expect(aside.recurrence == rule.recurrence)
        #expect(aside.createdAt == rule.createdAt)
        #expect(aside.archivedAt == nil, "still on the rule; only the listing changed")
    }

    // The reason the whole feature exists: the same rule, with its history,
    // rather than a fresh one that splits the record in two.
    @Test("taking one up again keeps its identity")
    func takingUpKeepsIdentity() {
        var rule = own("Cold plunge")
        rule.archivedAt = Date()
        rule.hiddenFromLibrary = true

        let restored = CustomLibrary.takingUp(rule)
        #expect(restored.id == rule.id, "the same rule, so its history follows it")
        #expect(restored.archivedAt == nil)
        #expect(restored.hiddenFromLibrary == nil, "back in the library too")
        #expect(restored.createdAt == rule.createdAt)
    }

    @Test("an archived rule of one's own is still offered")
    func archivedStillOffered() {
        var rule = own("Cold plunge")
        rule.archivedAt = Date()
        #expect(CustomLibrary.entries(from: [rule]).count == 1, "that is the point")
    }
}

/// The library after the move to Jordanville.
///
/// The templates that name a whole sequence updated themselves when the
/// sequences did. The ones that named prayers directly, or named none at all,
/// did not — and a template offering a rule with no words behind it is the
/// quiet failure here, because it looks perfectly fine in the list.
@Suite("The library offers the book's daily prayers")
struct JordanvilleLibraryTests {

    private let library = RuleLibrary.shared
    private let book = PrayerBook.shared

    @Test("every prayer a template names still exists")
    func everyNamedPrayerResolves() {
        for template in RuleLibrary.bundled {
            for id in template.prayerIDs {
                #expect(book.prayer(id: id) != nil, "\(template.id) names missing \(id)")
            }
        }
    }

    /// Two prayer rules have no text on purpose: an akathist is chosen from the
    /// service texts, and a kathisma comes from the Psalter. Everything else in
    /// the section should lead somewhere.
    @Test("prayer rules lead to words, apart from the two that cannot")
    func prayerRulesHaveText() {
        let withoutText = Set(["akathist", "psalter-kathisma"])
        for template in RuleLibrary.bundled where template.category == .prayer {
            guard !withoutText.contains(template.id) else { continue }
            #expect(!template.prayerIDs.isEmpty, "\(template.id) offers a rule with no words")
        }
    }

    /// The prayers the book gives for the day are reachable as rules, not only
    /// as items in a dropdown. Someone who wants grace before meals should find
    /// it in the library.
    @Test("the book's daily prayers are offered as rules")
    func dailyPrayersAreOffered() {
        let named = Set(RuleLibrary.bundled.flatMap(\.prayerIDs))
        for id in [
            "before-noon-and-evening-meals", "after-noon-and-evening-meals",
            "before-the-beginning-of-any-work", "after-the-completion-of-any-work",
            "before-lessons", "after-lessons",
            "creed", "daily-confession-of-sins", "ephrem",
            "for-the-living", "for-the-departed",
            "prayerful-invocation-of-the-saint-whose-name",
        ] {
            #expect(named.contains(id), "no library rule offers \(id)")
        }
    }

    @Test("the Lenten prayer is seasonal, not daily all year")
    func ephraimIsSeasonal() {
        let template = library.template(id: "prayer-of-st-ephraim")
        #expect(template?.recurrence == .liturgical(.season(.greatLent)))
    }
}
