import Foundation

/// Dates as they are written in the interface. One place, so the day list, the
/// month header and the progress report cannot drift apart.
public enum Format {
    private static let weekdays = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    private static let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    /// "Wednesday 19 August"
    public static func longDate(_ date: CalendarDate) -> String {
        "\(weekdays[date.weekday.rawValue - 1]) \(date.day) \(months[date.month - 1])"
    }

    /// "Sunday"
    public static func weekdayName(_ weekday: Weekday) -> String {
        weekdays[weekday.rawValue - 1]
    }

    /// "September"
    public static func monthName(_ month: Int) -> String {
        months[month - 1]
    }

    /// "30 August 2026"
    ///
    /// The year is not optional here. `longDate` names the weekday and omits
    /// the year, which is right for a day list looking at this week — and wrong
    /// for a journal, where two entries can share a date across years and the
    /// whole point is comparing them.
    public static func dateWithYear(_ date: CalendarDate) -> String {
        "\(date.day) \(months[date.month - 1]) \(date.year)"
    }

    /// "August 2026"
    public static func monthAndYear(_ date: CalendarDate) -> String {
        "\(months[date.month - 1]) \(date.year)"
    }

    public static func shortMonth(_ month: Int) -> String {
        String(months[month - 1].prefix(3))
    }

    /// One hour, for a picker that has to be unambiguous on its own.
    ///
    /// A list of bare numbers from 00 to 23 is what let an evening rule be set
    /// to half past ten in the morning: 10 looks like the right answer to
    /// someone thinking in twelve hours, and nothing afterwards says otherwise.
    public static func hourLabel(_ hour: Int, _ style: ClockStyle = .twentyFourHour) -> String {
        switch style {
        case .twentyFourHour:
            return String(format: "%02d", hour)
        case .twelveHour:
            let display = hour % 12 == 0 ? 12 : hour % 12
            return "\(display) \(hour < 12 ? "AM" : "PM")"
        }
    }

    public static func time(_ time: TimeOfDay, _ style: ClockStyle = .twentyFourHour) -> String {
        switch style {
        case .twentyFourHour:
            return String(format: "%02d:%02d", time.hour, time.minute)
        case .twelveHour:
            let hour = time.hour % 12 == 0 ? 12 : time.hour % 12
            let meridiem = time.hour < 12 ? "AM" : "PM"
            return String(format: "%d:%02d %@", hour, time.minute, meridiem)
        }
    }
}
