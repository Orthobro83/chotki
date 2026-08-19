import Testing
import Foundation
@testable import ChotkiCore

@Suite("Glossary")
struct GlossaryTests {
    let glossary = Glossary.shared

    @Test("every entry is complete and well formed")
    func entriesAreWellFormed() {
        #expect(glossary.entries.count >= 45)
        for entry in glossary.entries {
            #expect(!entry.term.isEmpty)
            #expect(!entry.short.isEmpty, "\(entry.slug) has no summary")
            #expect(!entry.full.isEmpty, "\(entry.slug) has no explanation")
            #expect(entry.short.count < 120, "\(entry.slug) summary is too long to sit inline")
            #expect(entry.full.count > entry.short.count, "\(entry.slug) explains nothing extra")
        }
    }

    @Test("slugs are unique")
    func uniqueSlugs() {
        #expect(Set(glossary.entries.map(\.slug)).count == glossary.entries.count)
    }

    // A dangling cross-reference would be a dead link in the education pane.
    @Test("every related reference resolves")
    func relatedLinksResolve() {
        for entry in glossary.entries {
            for slug in entry.related {
                #expect(glossary.entry(slug: slug) != nil, "\(entry.slug) points at missing \(slug)")
            }
        }
    }

    @Test("lookup works by term and by alias")
    func lookup() {
        #expect(glossary.entry(forTerm: "Theotokos")?.slug == "theotokos")
        #expect(glossary.entry(forTerm: "theotokos")?.slug == "theotokos", "case insensitive")
        #expect(glossary.entry(forTerm: "prayer rope")?.slug == "chotki", "alias resolves")
        #expect(glossary.entry(forTerm: "Julian calendar")?.slug == "old-calendar")
        #expect(glossary.entry(forTerm: "not a term") == nil)
    }

    @Test("search ranks exact matches above body mentions")
    func searchRanking() {
        let results = glossary.search("pascha")
        #expect(results.first?.slug == "pascha")
        #expect(results.count > 1, "other entries mention it")

        #expect(glossary.search("theo").first?.slug == "theophany", "prefix match")
        #expect(glossary.search("").count == glossary.entries.count, "empty query browses everything")
        #expect(glossary.search("zzzznotathing").isEmpty)
    }

    @Test("browsing by category covers every entry")
    func categories() {
        let grouped = glossary.byCategory
        let total = grouped.reduce(0) { $0 + $1.1.count }
        #expect(total == glossary.entries.count)
        #expect(!glossary.entries(in: .fasting).isEmpty)
        #expect(!glossary.entries(in: .saints).isEmpty)
    }
}

/// The scanner is what makes the feature work without hand-tagging every string.
@Suite("Term scanning")
struct TermScanningTests {
    let glossary = Glossary.shared

    private func slugs(_ text: String) -> [String] {
        glossary.scan(text).map(\.slug)
    }

    @Test("finds a term in running text")
    func findsTerms() {
        let found = glossary.scan("Dormition of the Most-Holy Theotokos")
        #expect(found.contains { $0.slug == "theotokos" })
        #expect(found.contains { $0.slug == "dormition" })
    }

    // Without word boundaries "Fast" lights up inside "Breakfast" and the whole
    // feature becomes noise.
    @Test("never matches inside a longer word", arguments: [
        "Breakfast is at nine", "Antone came by", "The steadfast believer", "unmercenariesx"
    ])
    func respectsWordBoundaries(text: String) {
        #expect(glossary.scan(text).isEmpty, "matched inside a word in: \(text)")
    }

    @Test("prefers the longest term over a shorter one inside it")
    func longestMatchWins() {
        let found = glossary.scan("Today is a Great Feast")
        #expect(found.count == 1)
        #expect(found.first?.slug == "great-feast")
        #expect(found.first?.matchedText == "Great Feast")
    }

    @Test("matches never overlap")
    func noOverlaps() {
        let text = "Major Feast of the Theotokos during the Dormition Fast"
        let found = glossary.scan(text)
        for (a, b) in zip(found, found.dropFirst()) {
            #expect(!a.range.overlaps(b.range))
            #expect(a.range.lowerBound <= b.range.lowerBound, "results are in reading order")
        }
    }

    @Test("ranges point at the original text, preserving its casing")
    func rangesAreUsable() {
        let text = "the theotokos is commemorated"
        let match = glossary.scan(text).first { $0.slug == "theotokos" }
        let found = try! #require(match)
        #expect(String(text[found.range]) == "theotokos", "matched lowercase as written")
    }

    @Test("a trailing apostrophe still matches")
    func apostropheFollows() {
        #expect(slugs("the Theotokos' icon").contains("theotokos"))
    }

    // The real payload: text the app actually displays should light up.
    @Test("scans strings the app really shows", arguments: [
        ("Martyr Andrew Stratelates and Companions", ["martyr", "stratelates"]),
        ("Dormition Fast — Fish, Wine and Oil are Allowed", ["dormition-fast", "wine-and-oil"]),
        ("Leavetaking of the Nativity", ["leavetaking", "nativity"]),
        ("Ven. Melania the Younger of Rome", ["venerable"]),
        ("Wednesday of the 12th week after Pentecost", ["pentecost"])
    ])
    func realDisplayStrings(text: String, expected: [String]) {
        let found = Set(slugs(text))
        for slug in expected {
            #expect(found.contains(slug), "\(text) should surface \(slug); found \(found)")
        }
    }

    @Test("plain text produces nothing")
    func plainText() {
        #expect(glossary.scan("Read the day's chapter and go for a walk").isEmpty)
    }
}
