import Foundation

/// The Psalter's twenty divisions, and which are appointed on a given day.
///
/// The divisions are fixed and are stated in Septuagint numbering, which is
/// what the Orthodox Psalter uses and what Brenton's translation gives. Psalm
/// 151 belongs to no kathisma.
///
/// **Divisions:** Metropolitan Cantor Institute, *The Kathismata of the
/// Psalter*, <https://mci.archpitt.org/liturgy/Kathismata.html>
///
/// **The daily order:** Fr John Whiteford, *Order of Reading the Kathismata of
/// the Psalter*, St Jonah Orthodox Church,
/// <https://www.saintjonah.org/rub/kathismata.htm> — Russian usage. Other
/// jurisdictions abbreviate differently, particularly in summer.
///
/// `[manual]` The table is transcribed faithfully; **which** table applies on a
/// given date is computed here from the distance to Pascha, and those
/// boundaries await a priest's review like everything else liturgical in this
/// app.
public enum Kathisma {

    /// The first and last psalm of each kathisma, in Septuagint numbering.
    public static let divisions: [(kathisma: Int, first: Int, last: Int)] = [
        (1, 1, 8), (2, 9, 16), (3, 17, 23), (4, 24, 31), (5, 32, 36),
        (6, 37, 45), (7, 46, 54), (8, 55, 63), (9, 64, 69), (10, 70, 76),
        (11, 77, 84), (12, 85, 90), (13, 91, 100), (14, 101, 104),
        (15, 105, 108), (16, 109, 117), (17, 118, 118), (18, 119, 133),
        (19, 134, 142), (20, 143, 150)
    ]

    public static func psalms(in kathisma: Int) -> ClosedRange<Int>? {
        guard let found = divisions.first(where: { $0.kathisma == kathisma }) else { return nil }
        return found.first...found.last
    }

    /// Where in the day a kathisma is appointed.
    public enum Service: String, Sendable, Hashable, CaseIterable {
        case matins, firstHour, thirdHour, sixthHour, ninthHour, vespers

        public var displayName: String {
            switch self {
            case .matins: return "Matins"
            case .firstHour: return "First Hour"
            case .thirdHour: return "Third Hour"
            case .sixthHour: return "Sixth Hour"
            case .ninthHour: return "Ninth Hour"
            case .vespers: return "Vespers"
            }
        }
    }

    /// Which table applies. The Psalter is read once a week ordinarily and
    /// twice a week through Great Lent, which is why the lenten tables reach
    /// the Hours as well.
    public enum Season: Sendable, Hashable {
        case ordinary
        /// Weeks 1, 2, 3, 4 and 6.
        case greatLent
        /// Week 5 keeps its own order, around the Great Canon.
        case fifthWeekOfLent
        case holyWeek
        /// Pascha and the week after it. Nothing is read.
        case brightWeek
    }

    public struct Appointed: Sendable, Hashable {
        public let service: Service
        public let kathismata: [Int]
    }

    // MARK: the tables

    /// Sunday is index 0, matching `Weekday.number - 1`.
    private static let ordinary: [[Service: [Int]]] = [
        [.matins: [2, 3]],
        [.matins: [4, 5], .vespers: [6]],
        [.matins: [7, 8], .vespers: [9]],
        [.matins: [10, 11], .vespers: [12]],
        [.matins: [13, 14], .vespers: [15]],
        [.matins: [19, 20], .vespers: [18]],
        [.matins: [16, 17], .vespers: [1]]
    ]

    private static let lent: [[Service: [Int]]] = [
        [.matins: [2, 3]],
        [.matins: [4, 5, 6], .firstHour: [7], .thirdHour: [8], .sixthHour: [9], .vespers: [18]],
        [.matins: [10, 11, 12], .firstHour: [13], .thirdHour: [14], .sixthHour: [15],
         .ninthHour: [16], .vespers: [18]],
        [.matins: [19, 20, 1], .firstHour: [2], .thirdHour: [3], .sixthHour: [4],
         .ninthHour: [5], .vespers: [18]],
        [.matins: [6, 7, 8], .firstHour: [9], .thirdHour: [10], .sixthHour: [11],
         .ninthHour: [12], .vespers: [18]],
        [.matins: [13, 14, 15], .thirdHour: [19], .sixthHour: [20], .vespers: [18]],
        [.matins: [16, 17], .vespers: [1]]
    ]

    private static let fifthWeek: [[Service: [Int]]] = [
        [.matins: [2, 3]],
        [.matins: [4, 5, 6], .firstHour: [7], .thirdHour: [8], .sixthHour: [9], .ninthHour: [10]],
        [.matins: [11, 12, 13], .firstHour: [14], .thirdHour: [15], .sixthHour: [16],
         .ninthHour: [18], .vespers: [19]],
        [.matins: [20, 1, 2], .firstHour: [3], .thirdHour: [4], .sixthHour: [5],
         .ninthHour: [6], .vespers: [7]],
        [.matins: [8], .thirdHour: [9], .sixthHour: [10], .ninthHour: [11], .vespers: [12]],
        [.matins: [13, 14, 15], .thirdHour: [19], .sixthHour: [20], .vespers: [18]],
        [.matins: [16, 17], .vespers: [1]]
    ]

    private static let holyWeek: [[Service: [Int]]] = [
        [.matins: [2, 3]],
        [.matins: [4, 5, 6], .thirdHour: [7], .sixthHour: [8], .vespers: [18]],
        [.matins: [9, 10, 11], .thirdHour: [12], .sixthHour: [13], .vespers: [18]],
        [.matins: [14, 15, 16], .thirdHour: [19], .sixthHour: [20], .vespers: [18]],
        [:],
        [:],
        [.matins: [17]]
    ]

    // MARK: the day

    /// Which season a day falls in, from its distance to Pascha.
    ///
    /// Clean Monday is 48 days before Pascha and Great Lent runs to the Friday
    /// before Lazarus Saturday. Lazarus Saturday and Palm Sunday sit between
    /// Lent and Holy Week and keep the ordinary order here.
    public static func season(paschaDistance: Int) -> Season {
        switch paschaDistance {
        case 0...6: return .brightWeek
        case -6...(-1): return .holyWeek
        case -20...(-14): return .fifthWeekOfLent
        case -48...(-9): return .greatLent
        default: return .ordinary
        }
    }

    /// What is appointed on a day, in the order it is read through the day.
    public static func appointed(weekday: Weekday, season: Season) -> [Appointed] {
        let table: [[Service: [Int]]]
        switch season {
        case .brightWeek: return []
        case .ordinary: table = ordinary
        case .greatLent: table = lent
        case .fifthWeekOfLent: table = fifthWeek
        case .holyWeek: table = holyWeek
        }

        let row = table[weekday.rawValue - 1]
        return Service.allCases.compactMap { service in
            guard let kathismata = row[service], !kathismata.isEmpty else { return nil }
            return Appointed(service: service, kathismata: kathismata)
        }
    }

    /// Every kathisma appointed on a day, in order and without repeats.
    public static func onTheDay(weekday: Weekday, season: Season) -> [Int] {
        var seen: Set<Int> = []
        return appointed(weekday: weekday, season: season)
            .flatMap(\.kathismata)
            .filter { seen.insert($0).inserted }
    }
}
