import Testing
import Foundation
@testable import ChotkiCore

/// The Psalter's divisions and the order they are read in.
///
/// The tables are transcribed from a source rather than worked out, so what
/// these check is that the transcription is internally sound — the arithmetic
/// the Typikon itself guarantees. A slip in one row shows up as a psalm read
/// twice in a week or not at all.
@Suite("The kathismata")
struct KathismaTests {

    @Test("the twenty divisions cover psalms 1 to 150 exactly once")
    func divisionsCoverThePsalter() {
        var covered: [Int] = []
        for division in Kathisma.divisions {
            #expect(division.first <= division.last)
            covered.append(contentsOf: division.first...division.last)
        }
        #expect(covered.count == 150, "the divisions cover \(covered.count) psalms")
        #expect(Set(covered) == Set(1...150))
        #expect(Kathisma.divisions.map(\.kathisma) == Array(1...20))
    }

    /// Psalm 151 is in the Septuagint and in the app, and in no kathisma.
    @Test("psalm 151 belongs to no kathisma")
    func psalm151IsOutside() {
        #expect(Kathisma.divisions.allSatisfy { $0.last < 151 })
    }

    @Test("the seventeenth is the whole of psalm 118")
    func theSeventeenthIsPsalm118() {
        #expect(Kathisma.psalms(in: 17) == 118...118)
    }

    /// Ordinarily the Psalter is read once through in the week.
    @Test("the ordinary week reads all twenty, once each")
    func theOrdinaryWeekReadsThePsalterOnce() {
        var read: [Int] = []
        for weekday in Weekday.allCases {
            read.append(contentsOf: Kathisma.onTheDay(weekday: weekday, season: .ordinary))
        }
        #expect(read.sorted() == Array(1...20), "the week reads \(read.sorted())")
    }

    /// Through Great Lent the Psalter is read twice over, which is why the
    /// Hours carry one — with two exceptions that are features of the Typikon
    /// rather than slips in the transcription.
    ///
    /// The seventeenth is Psalm 118, the Amomos, read at Saturday Matins and so
    /// once in the week. The eighteenth is the Songs of Ascents, read at
    /// Vespers on every lenten weekday. An earlier version of this test
    /// asserted a tidy "twice each" and failed against the actual order, which
    /// is the right way round for a test to be wrong.
    @Test("a lenten week reads the Psalter twice, but for the Amomos and the Ascents")
    func aLentenWeekReadsThePsalterTwice() {
        var counts: [Int: Int] = [:]
        for weekday in Weekday.allCases {
            for kathisma in Kathisma.onTheDay(weekday: weekday, season: .greatLent) {
                counts[kathisma, default: 0] += 1
            }
        }
        #expect(Set(counts.keys) == Set(1...20), "a lenten week misses one")
        #expect(counts[17] == 1, "the Amomos is read \(counts[17] ?? 0) times")
        #expect(counts[18] == 5, "the Ascents are read \(counts[18] ?? 0) times")
        for kathisma in (1...20).filter({ $0 != 17 && $0 != 18 }) {
            #expect(counts[kathisma] == 2, "the \(kathisma)th is read \(counts[kathisma] ?? 0) times")
        }
    }

    /// The fifth week keeps the same shape, without the daily Ascents.
    @Test("the fifth week reads the Psalter twice as well")
    func theFifthWeekReadsItTwice() {
        var counts: [Int: Int] = [:]
        for weekday in Weekday.allCases {
            for kathisma in Kathisma.onTheDay(weekday: weekday, season: .fifthWeekOfLent) {
                counts[kathisma, default: 0] += 1
            }
        }
        #expect(Set(counts.keys) == Set(1...20))
        #expect(counts[17] == 1)
        for kathisma in (1...20).filter({ $0 != 17 }) {
            #expect(counts[kathisma] == 2, "the \(kathisma)th is read \(counts[kathisma] ?? 0) times")
        }
    }

    @Test("nothing is read in Bright Week")
    func brightWeekReadsNothing() {
        for weekday in Weekday.allCases {
            #expect(Kathisma.onTheDay(weekday: weekday, season: .brightWeek).isEmpty)
        }
    }

    @Test("Great Friday and Great Saturday morning read almost nothing")
    func holyWeekThins() {
        #expect(Kathisma.onTheDay(weekday: .thursday, season: .holyWeek).isEmpty)
        #expect(Kathisma.onTheDay(weekday: .friday, season: .holyWeek).isEmpty)
        #expect(Kathisma.onTheDay(weekday: .saturday, season: .holyWeek) == [17])
    }

    @Test("the seasons fall where they should around Pascha")
    func seasonsAroundPascha() {
        #expect(Kathisma.season(paschaDistance: 0) == .brightWeek)
        #expect(Kathisma.season(paschaDistance: 6) == .brightWeek)
        #expect(Kathisma.season(paschaDistance: 7) == .ordinary)
        #expect(Kathisma.season(paschaDistance: -1) == .holyWeek)   // Great Saturday
        #expect(Kathisma.season(paschaDistance: -6) == .holyWeek)   // Great Monday
        #expect(Kathisma.season(paschaDistance: -7) == .ordinary)   // Palm Sunday
        #expect(Kathisma.season(paschaDistance: -8) == .ordinary)   // Lazarus Saturday
        #expect(Kathisma.season(paschaDistance: -9) == .greatLent)
        #expect(Kathisma.season(paschaDistance: -14) == .fifthWeekOfLent)
        #expect(Kathisma.season(paschaDistance: -20) == .fifthWeekOfLent)
        #expect(Kathisma.season(paschaDistance: -21) == .greatLent)
        #expect(Kathisma.season(paschaDistance: -48) == .greatLent)  // Clean Monday
        #expect(Kathisma.season(paschaDistance: -49) == .ordinary)   // Forgiveness Sunday
    }
}
