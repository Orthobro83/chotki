import Foundation

/// The window in which the app will not send notifications.
///
/// Exists so that an untimed rule repeating hourly cannot wake the user at 3am.
/// The window normally wraps midnight (21:30 → 06:30), so containment is not a
/// simple range check.
public struct QuietHours: Sendable, Hashable, Codable {
    public let start: TimeOfDay
    public let end: TimeOfDay

    public init(start: TimeOfDay, end: TimeOfDay) {
        self.start = start
        self.end = end
    }

    /// 21:30 → 06:30.
    public static let `default` = QuietHours(
        start: TimeOfDay(hour: 21, minute: 30)!,
        end: TimeOfDay(hour: 6, minute: 30)!
    )

    /// `start == end` means no quiet window at all, not a 24-hour one.
    /// A user who sets both to the same time wants notifications, not silence.
    public var isDisabled: Bool { start == end }

    /// True when the window runs through midnight.
    public var wrapsMidnight: Bool { end < start }

    /// Start is inclusive, end is exclusive — so a rule due exactly at the end of
    /// quiet hours fires rather than being held for another hour.
    public func contains(_ time: TimeOfDay) -> Bool {
        guard !isDisabled else { return false }
        let t = time.minutesSinceMidnight
        let s = start.minutesSinceMidnight
        let e = end.minutesSinceMidnight
        return wrapsMidnight ? (t >= s || t < e) : (t >= s && t < e)
    }
}
