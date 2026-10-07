import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

private func fnv1a(_ data: [UInt8], _ seed: UInt64) -> UInt64 {
    var h = seed
    for b in data { h ^= UInt64(b); h = h &* 0x100000001b3 }
    return h
}

@Suite("The bundled calendar")
struct BundledCalendarTests {

    private let bundle = BundledCalendar.standard!

    private var allDates: [CalendarDate] {
        var out: [CalendarDate] = []
        var date = bundle.first
        while date <= bundle.last { out.append(date); date = date.adding(days: 1) }
        return out
    }

    @Test("it covers the five-year window and says where it came from")
    func manifest() {
        #expect(bundle.first == d(2026, 1, 1))
        #expect(bundle.last == d(2031, 12, 31))
        #expect(bundle.manifest.schema == 1)
        #expect(bundle.manifest.tradition == "slavic")
        #expect(bundle.manifest.orthocalCommit.count == 40)
        #expect(bundle.manifest.files.count == 12)
        #expect(bundle.covers(d(2028, 2, 29)))
        #expect(!bundle.covers(d(2025, 12, 31)))
        #expect(!bundle.covers(d(2032, 1, 1)))
    }

    @Test("every day of the window is there, under both reckonings, filed under its civil date")
    func everyDay() {
        for reckoning in Reckoning.allCases {
            for date in allDates {
                let day = bundle.day(civil: date, reckoning: reckoning)
                #expect(day?.civilDate == date, "\(reckoning) \(date)")
                #expect(day?.reckoning == reckoning)
            }
        }
        #expect(bundle.day(civil: d(2032, 1, 1), reckoning: .julian) == nil)
        #expect(bundle.day(civil: d(2025, 12, 31), reckoning: .julian) == nil)
    }

    @Test("29 February 2028 exists under both, and the Old Calendar is thirteen days behind")
    func leapDayAndOffset() throws {
        for reckoning in Reckoning.allCases {
            #expect(bundle.day(civil: d(2028, 2, 29), reckoning: reckoning) != nil)
        }
        for date in allDates {
            let julian = try #require(bundle.day(civil: date, reckoning: .julian))
            let revised = try #require(bundle.day(civil: date, reckoning: .revisedJulian))
            #expect(julian.observedDate == date.adding(days: -13), "\(date)")
            #expect(revised.observedDate == date, "\(date)")
        }
    }

    @Test("both reckonings agree on Pascha, so Great Lent and Pentecost fall on the same days")
    func movableCycleIsShared() throws {
        for date in allDates {
            let julian = try #require(bundle.day(civil: date, reckoning: .julian))
            let revised = try #require(bundle.day(civil: date, reckoning: .revisedJulian))
            #expect(julian.paschaDistance == revised.paschaDistance, "\(date)")
            #expect(julian.paschaDistance == Pascha.distance(on: date), "\(date)")
        }
    }

    @Test("every reading has scripture, with no pilcrow, stray space or run of blank lines")
    func readingsAreClean() throws {
        var readings = 0
        var composites = 0
        for reckoning in Reckoning.allCases {
            for date in allDates {
                let day = try #require(bundle.day(civil: date, reckoning: reckoning))
                for reading in day.readings {
                    readings += 1
                    if reading.display.hasPrefix("Composite") { composites += 1 }
                    #expect(!reading.text.isEmpty, "\(date) \(reading.display)")
                    #expect(!reading.text.contains("\u{00B6}"))
                    #expect(!reading.text.contains("\n\n\n"))
                    #expect(reading.text == reading.text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        #expect(readings == 17_437)
        #expect(composites == 612)
    }

    @Test("the text resolves exactly as the bundle builder computed it (digest)")
    func digest() throws {
        var h: UInt64 = 0xcbf29ce484222325
        for reckoning in Reckoning.allCases {          // julian, then revisedJulian, as the builder runs them
            for date in allDates {
                let day = try #require(bundle.day(civil: date, reckoning: reckoning))
                for reading in day.readings {
                    h = fnv1a(Array(reading.text.utf8), h)
                    h = fnv1a([0x1f], h)
                }
            }
        }
        #expect(String(format: "%016llx", h) == bundle.manifest.textDigest)
    }

    @Test("every field of every day matches the audited source it was built from (digest)")
    func fieldsDigest() throws {
        var h: UInt64 = 0xcbf29ce484222325
        for reckoning in Reckoning.allCases {
            for date in allDates {
                let day = try #require(bundle.day(civil: date, reckoning: reckoning))
                let observed = day.observedDate
                var parts: [String] = [
                    String(format: "%04d-%02d-%02d", observed.year, observed.month, observed.day),
                    day.tone.map(String.init) ?? "-",
                    day.title ?? "-",
                    day.summaryTitle,
                    day.saints.joined(separator: "|"), day.feasts.joined(separator: "|"),
                    String(day.fastLevel), day.fastLevelDescription, String(day.fastException),
                    day.fastExceptionDescription ?? "-",
                    day.abstentions.joined(separator: "|"),
                    String(day.feastLevel), day.feastLevelDescription, String(day.paschaDistance)
                ]
                parts += day.readings.map { "\($0.source)\u{1d}\($0.display)\u{1d}\($0.shortDisplay)" }
                h = fnv1a(Array(parts.joined(separator: "\u{1e}").utf8), h)
                h = fnv1a([0x1f], h)
            }
        }
        #expect(String(format: "%016llx", h) == bundle.manifest.fieldsDigest)
    }

    @Test("the bundled day equals the day decoded from each recorded API response")
    func parityWithTheRecordedFixtures() throws {
        let fixtures = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let names = try FileManager.default.contentsOfDirectory(atPath: fixtures.path).filter { $0.hasSuffix(".json") }
        #expect(names.count == 10)
        for name in names {
            let stem = String(name.dropLast(5))                       // julian-2026-12-25
            let parts = stem.split(separator: "-", maxSplits: 1)
            let reckoning: Reckoning = parts[0] == "julian" ? .julian : .revisedJulian
            let date = try #require(CalendarDate(iso: String(parts[1])))
            let data = try Data(contentsOf: fixtures.appendingPathComponent(name))
            let recorded = try OrthocalClient.decode(data, civilDate: date, reckoning: reckoning, now: Date())
            let shipped = try #require(bundle.day(civil: date, reckoning: reckoning), "\(stem)")

            #expect(shipped.observedDate == recorded.observedDate, "\(stem)")
            #expect(shipped.tone == recorded.tone)
            #expect(shipped.title == recorded.title)
            #expect(shipped.feasts == recorded.feasts)
            #expect(shipped.fastLevel == recorded.fastLevel)
            #expect(shipped.fastLevelDescription == recorded.fastLevelDescription)
            #expect(shipped.fastException == recorded.fastException)
            #expect(shipped.fastExceptionDescription == recorded.fastExceptionDescription)
            #expect(shipped.abstentions == recorded.abstentions)
            #expect(shipped.feastLevel == recorded.feastLevel)
            #expect(shipped.feastLevelDescription == recorded.feastLevelDescription)
            #expect(shipped.paschaDistance == recorded.paschaDistance)
            // Upstream has added commemorations since some of these were recorded, never removed any.
            #expect(Set(recorded.saints).isSubset(of: Set(shipped.saints)), "\(stem)")
            if shipped.saints == recorded.saints { #expect(shipped.summaryTitle == recorded.summaryTitle, "\(stem)") }
            #expect(shipped.readings.count == recorded.readings.count, "\(stem)")
            for (a, b) in zip(shipped.readings, recorded.readings) {
                #expect(a.source == b.source); #expect(a.display == b.display); #expect(a.shortDisplay == b.shortDisplay)
                // Both paths join the same keyed verses by the same paragraph rule.
                if !a.display.hasPrefix("Composite") {
                    #expect(a.text == b.text, Comment(rawValue: "\(stem) \(a.display)"))
                }
            }
        }
    }
}
