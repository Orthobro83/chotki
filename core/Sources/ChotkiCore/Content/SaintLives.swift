import Foundation

/// English readings translated from the public-domain Russian edition of
/// St. Dimitry of Rostov's Lives. Month and day are the observed church date,
/// never the device's civil date, so Old Calendar users see the right life.
public struct SaintLife: Sendable, Codable, Hashable {
    public let month: Int
    public let day: Int
    public let title: String
    public let paragraphs: [String]
    public let source: String
    public let sourceURL: String
}

public enum SaintLives {
    private static let readings: [SaintLife] = {
        guard let url = Bundle.module.url(forResource: "saint-lives", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let lives = try? JSONDecoder().decode([SaintLife].self, from: data)
        else { return [] }
        return lives
    }()

    public static func reading(on observedDate: CalendarDate) -> SaintLife? {
        readings.first { $0.month == observedDate.month && $0.day == observedDate.day }
    }

    public static var availableDayCount: Int { readings.count }
}
