import Foundation

/// A day in the civil calendar. No time, no time zone, no instant.
///
/// This is the single most important type in the model. A rule due "on 19 August"
/// is due on 19 August wherever the user is and whatever the clocks did overnight.
/// Storing that as a `Date` is how tasks silently shift by a day across a DST
/// boundary or a flight — a bug that surfaces months later and is miserable to
/// trace. Keeping the day and the wall-clock time as separate, zone-free values
/// makes the whole class of error unrepresentable rather than merely tested for.
///
/// The one place a real instant is needed is scheduling a notification, and that
/// conversion is explicit: see `dueInstant(at:in:)`.
public struct CalendarDate: Sendable, Hashable, Comparable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Arithmetic happens in a fixed UTC Gregorian calendar so it can never be
    /// perturbed by the host's locale or zone.
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    /// Returns nil for dates that do not exist, such as 31 April or 29 February
    /// in a common year. Values often arrive from stored data, so this validates
    /// rather than trapping.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1 else { return nil }
        guard day <= CalendarDate.daysInMonth(year: year, month: month) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, in timeZone: TimeZone) {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        let parts = c.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year!
        self.month = parts.month!
        self.day = parts.day!
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public var lastDayOfMonth: Int {
        CalendarDate.daysInMonth(year: year, month: month)
    }

    public var weekday: Weekday {
        let comps = DateComponents(year: year, month: month, day: day)
        let date = CalendarDate.calendar.date(from: comps)!
        // Foundation numbers Sunday as 1, matching Weekday's raw values.
        return Weekday(rawValue: CalendarDate.calendar.component(.weekday, from: date))!
    }

    public func adding(days: Int) -> CalendarDate {
        let comps = DateComponents(year: year, month: month, day: day)
        let base = CalendarDate.calendar.date(from: comps)!
        let moved = CalendarDate.calendar.date(byAdding: .day, value: days, to: base)!
        let parts = CalendarDate.calendar.dateComponents([.year, .month, .day], from: moved)
        return CalendarDate(year: parts.year!, month: parts.month!, day: parts.day!)!
    }

    /// The one deliberate crossing into real time. Converting a day plus a
    /// wall-clock time into an instant is exactly where DST lives, so it is a
    /// single named function that takes the zone explicitly.
    ///
    /// Returns nil for a time that does not exist on that day — 01:30 on a
    /// spring-forward morning, for instance. Callers must decide what to do
    /// rather than being handed a silently shifted instant.
    public func dueInstant(at time: TimeOfDay, in timeZone: TimeZone) -> Date? {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = time.hour
        comps.minute = time.minute
        guard let candidate = c.date(from: comps) else { return nil }
        // Foundation happily shifts a nonexistent time forward; reject that
        // rather than pass it on.
        let check = c.dateComponents([.hour, .minute], from: candidate)
        guard check.hour == time.hour, check.minute == time.minute else { return nil }
        return candidate
    }

    /// Parses "YYYY-MM-DD". Storage writes this form because it sorts
    /// lexicographically, so SQLite can order and range-scan dates without
    /// any date handling of its own.
    public init?(iso: String) {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let day = Int(parts[2]),
              let value = CalendarDate(year: y, month: m, day: day)
        else { return nil }
        self = value
    }

    public var iso: String { description }

    public static func < (a: CalendarDate, b: CalendarDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

public enum Weekday: Int, Sendable, Hashable, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}
