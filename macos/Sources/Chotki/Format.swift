import Foundation
import ChotkiCore

/// Dates as they are written in the interface. One place, so the day list, the
/// month header and the progress report cannot drift apart.
enum Format {
    private static let weekdays = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    private static let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    /// "Wednesday 19 August"
    static func longDate(_ date: CalendarDate) -> String {
        "\(weekdays[date.weekday.rawValue - 1]) \(date.day) \(months[date.month - 1])"
    }

    /// "August 2026"
    static func monthAndYear(_ date: CalendarDate) -> String {
        "\(months[date.month - 1]) \(date.year)"
    }

    static func shortMonth(_ month: Int) -> String {
        String(months[month - 1].prefix(3))
    }

    static func time(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}
