import Foundation

/// How reminders for an untimed rule are distributed through the day.
public enum UntimedSpacing: String, Sendable, Hashable, Codable {
    /// One every `untimedInterval`, starting at the first waking hour. With the
    /// default cap this clusters them in the morning: 07:00, 08:00, 09:00,
    /// 10:00, then silence for the rest of the day.
    case hourly
    /// The same number of reminders, spread evenly across the waking hours —
    /// 07:00, 11:00, 16:00, 21:00 with the defaults. Fewer nudges in a row, and
    /// the rule is still in front of you in the evening.
    case spreadAcrossDay
}

/// When reminders fire, and how often.
///
/// Tunable rather than hard-coded, because the right cadence is personal and
/// because a policy that cannot be softened is a policy that nags.
public struct ReminderPolicy: Sendable, Hashable, Codable {
    /// How far ahead of a timed rule to give warning.
    public var leadTime: TimeInterval
    /// Gap between reminders for a rule with no clock time.
    public var untimedInterval: TimeInterval
    /// Most reminders in a day for one untimed rule. Zero means uncapped.
    public var untimedCap: Int
    public var spacing: UntimedSpacing
    public var quietHours: QuietHours

    public init(
        leadTime: TimeInterval = 10 * 60,
        untimedInterval: TimeInterval = 60 * 60,
        untimedCap: Int = 4,
        spacing: UntimedSpacing = .spreadAcrossDay,
        quietHours: QuietHours = .default
    ) {
        self.leadTime = leadTime
        self.untimedInterval = untimedInterval
        self.untimedCap = untimedCap
        self.spacing = spacing
        self.quietHours = quietHours
    }

    public static let `default` = ReminderPolicy()

    /// One reminder in the morning and nothing further.
    public static let gentle = ReminderPolicy(untimedCap: 1)

    /// The literal original shape: hourly from the first waking hour.
    public static let hourly = ReminderPolicy(spacing: .hourly)
}

/// A reminder the scheduler has decided should fire.
public struct PlannedNotification: Sendable, Hashable {
    /// Stable and derived, so every reminder for one occurrence can be
    /// cancelled together the moment it is marked complete.
    public let id: String
    public let ruleID: UUID
    public let date: CalendarDate
    public let fireAt: Date
    public let request: NotificationRequest

    public init(id: String, ruleID: UUID, date: CalendarDate, fireAt: Date, request: NotificationRequest) {
        self.id = id
        self.ruleID = ruleID
        self.date = date
        self.fireAt = fireAt
        self.request = request
    }

    /// Every reminder for a rule on a day shares this prefix.
    public static func occurrenceKey(ruleID: UUID, date: CalendarDate) -> String {
        "\(ruleID.uuidString):\(date.iso)"
    }
}

/// Injected so the whole scheduler is testable without sleeping or touching
/// real time. A month of ticks runs in milliseconds and needs no desktop.
public protocol Clock: Sendable {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

public final class FixedClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    public init(_ start: Date) { current = start }

    public var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }

    public func set(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        current = date
    }
}
