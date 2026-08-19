import Foundation

/// What to do when a monthly rule names a day the month does not have.
public enum ShortMonthPolicy: String, Sendable, Hashable, Codable {
    /// 31st becomes the 30th, or the 28th/29th in February.
    ///
    /// The default, because skipping is almost never what someone means. A
    /// monthly confession set for the 31st should not silently vanish in
    /// February, April, June, September and November — nearly half the year.
    case lastDay
    /// The occurrence simply does not exist that month. Available for a rule
    /// genuinely tied to a date rather than to a monthly rhythm.
    case skip
}

public enum Recurrence: Sendable, Hashable, Codable {
    /// A single named day. Produced when one occurrence of a repeating rule is
    /// edited in isolation, and available directly for a one-off intention.
    case once(CalendarDate)
    case daily
    case weekly(days: Set<Weekday>)
    case monthly(day: Int, whenShort: ShortMonthPolicy = .lastDay)
    case liturgical(LiturgicalTrigger)

    /// Convenience for the Wednesday and Friday fast, which is the most common
    /// weekly shape in an Orthodox rule.
    public static let wednesdayAndFriday = Recurrence.weekly(days: [.wednesday, .friday])
}

/// Recurrence driven by the church calendar rather than the civil one.
/// Resolved in Phase 3 against the liturgical layer; declared here so the
/// engine's shape is settled.
public enum LiturgicalTrigger: Sendable, Hashable, Codable {
    /// Any day the calendar marks as a fast, whichever reckoning is set.
    case fastDay
    /// Great feasts.
    case greatFeast
    /// Every day within a named fasting season.
    case season(FastingSeason)
}

public enum FastingSeason: String, Sendable, Hashable, Codable {
    case greatLent, nativityFast, apostlesFast, dormitionFast
}
