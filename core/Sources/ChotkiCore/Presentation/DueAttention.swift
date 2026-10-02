import Foundation

/// The reading destination for an occurrence, independent of desktop navigation.
public enum DueDestination: String, Sendable, Hashable {
    case home, prayers, reading

    public init(rule: Rule) {
        switch rule.reference {
        case .rope, .prayers, .psalter: self = .prayers
        case .reading: self = .reading
        default: self = .home
        }
    }
}

public enum DueAttention {
    public static let duration: TimeInterval = 5

    /// Early warnings notify without pulsing a section before its task is due.
    public static func destination(for notification: PlannedNotification, rule: Rule,
                                   timeZone: TimeZone = .current) -> DueDestination? {
        if let time = rule.timeOfDay {
            guard let due = notification.date.dueInstant(at: time, in: timeZone),
                  notification.fireAt == due else { return nil }
        }
        return DueDestination(rule: rule)
    }
}
