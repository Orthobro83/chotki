import Foundation

/// A short passage from the Fathers, shown alongside the day's scripture.
public struct PatristicReading: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let text: String
    public let author: String
    /// The work it comes from, so it can be looked up and checked.
    public let source: String

    public init(id: String, text: String, author: String, source: String) {
        self.id = id
        self.text = text
        self.author = author
        self.source = source
    }
}

/// The bundled passages, and which one belongs to a given day.
///
/// Bundled rather than fetched: there is no reliable free API for patristic
/// texts, scraping one would be brittle, and a passage that fails to load is a
/// worse experience than a small set that always works.
///
/// **Sources are public domain by construction.** Everything here comes from the
/// Ante-Nicene Fathers and Nicene and Post-Nicene Fathers series (Schaff et al.,
/// 1885–1900) or from early translations of the Sayings of the Desert Fathers.
/// Modern translations — the Philokalia in particular — remain in copyright and
/// must not be added.
///
/// This is a starting set, and is marked in the project as awaiting a priest's
/// review for accuracy of attribution before the app is used by anyone else.
public struct PatristicReadings: Sendable {

    public let readings: [PatristicReading]

    public init(readings: [PatristicReading] = PatristicReadings.bundled) {
        self.readings = readings
    }

    public static let shared = PatristicReadings()

    /// Chosen by the day of the year, so it is stable for a given day and does
    /// not change if the app is reopened.
    public func reading(for date: CalendarDate) -> PatristicReading? {
        guard !readings.isEmpty else { return nil }
        return readings[dayOfYear(date) % readings.count]
    }

    private func dayOfYear(_ date: CalendarDate) -> Int {
        var total = date.day
        for month in 1..<date.month {
            total += CalendarDate.daysInMonth(year: date.year, month: month)
        }
        return total
    }
}
