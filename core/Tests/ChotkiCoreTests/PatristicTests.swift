import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

@Suite("Patristic readings")
struct PatristicTests {
    let readings = PatristicReadings.shared

    @Test("every passage is complete and attributed")
    func wellFormed() {
        #expect(readings.readings.count >= 30)
        for reading in readings.readings {
            #expect(!reading.text.isEmpty)
            #expect(!reading.author.isEmpty)
            #expect(!reading.source.isEmpty, "\(reading.id) must name a work so it can be checked")
            #expect(reading.text.count < 400, "\(reading.id) is too long to sit under the readings")
        }
    }

    @Test("ids are unique")
    func uniqueIDs() {
        let ids = readings.readings.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    // Modern translations are in copyright. The Philokalia in particular is a
    // tempting source and must not be added.
    @Test("no source is a modern translation still in copyright")
    func onlyPublicDomainSources() {
        let forbidden = ["philokalia", "sfs", "popular patristics", "st vladimir"]
        for reading in readings.readings {
            let source = reading.source.lowercased()
            for phrase in forbidden {
                #expect(!source.contains(phrase), "\(reading.id) cites \(phrase)")
            }
        }
    }

    @Test("a day always gives the same passage")
    func stableForADay() {
        let date = d(2026, 8, 19)
        let first = readings.reading(for: date)
        #expect(first != nil)
        #expect(readings.reading(for: date) == first, "reopening must not reshuffle it")
    }

    @Test("consecutive days give different passages")
    func variesAcrossDays() {
        var seen: Set<String> = []
        for day in 1...28 {
            if let reading = readings.reading(for: d(2026, 2, day)) {
                seen.insert(reading.id)
            }
        }
        #expect(seen.count == 28, "a month should not repeat")
    }

    @Test("the whole set is reached over a year")
    func coversTheSet() {
        var seen: Set<String> = []
        for month in 1...12 {
            for day in 1...CalendarDate.daysInMonth(year: 2026, month: month) {
                if let reading = readings.reading(for: d(2026, month, day)) {
                    seen.insert(reading.id)
                }
            }
        }
        #expect(seen.count == readings.readings.count, "nothing is unreachable")
    }

    @Test("an empty set is handled rather than trapping")
    func emptySetIsSafe() {
        #expect(PatristicReadings(readings: []).reading(for: d(2026, 8, 19)) == nil)
    }
}
