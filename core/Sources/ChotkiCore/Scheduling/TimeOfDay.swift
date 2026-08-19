import Foundation

/// A wall-clock time with no date and no time zone.
///
/// Deliberately not a `Date`. A rule set for 06:30 means 06:30 on whatever day it
/// falls, in whatever zone the user is in — storing that as an instant is how
/// tasks silently shift by an hour across a DST boundary.
public struct TimeOfDay: Sendable, Hashable, Comparable, Codable {
    public let hour: Int
    public let minute: Int

    /// Returns nil rather than trapping: values often arrive from stored data.
    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (a: TimeOfDay, b: TimeOfDay) -> Bool {
        a.minutesSinceMidnight < b.minutesSinceMidnight
    }
}
