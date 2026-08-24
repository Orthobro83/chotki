import Foundation

/// How a time of day is written.
///
/// Not a formatting preference so much as a safety one. A rule set for the
/// evening and shown as "10:30" reads as the morning to anyone used to a
/// twelve-hour clock, and the mistake is invisible: the list stays in
/// chronological order, so nothing looks wrong. Evening prayers sat at half past
/// ten in the morning on the author's own rule for days.
public enum ClockStyle: String, Sendable, Hashable, Codable, CaseIterable {
    /// 06:30, 21:00.
    case twentyFourHour
    /// 6:30 AM, 9:00 PM.
    case twelveHour

    public var displayName: String {
        switch self {
        case .twentyFourHour: return "24-hour (06:30)"
        case .twelveHour: return "12-hour (6:30 AM)"
        }
    }
}
