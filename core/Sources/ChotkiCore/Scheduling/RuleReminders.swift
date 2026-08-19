import Foundation

/// How far ahead of a rule's time to give warning.
public enum ReminderLead: Int, Sendable, Hashable, Codable, CaseIterable, Comparable {
    case atTheTime = 0
    case tenMinutes = 10
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case theEveningBefore = -1

    public var interval: TimeInterval {
        switch self {
        case .theEveningBefore: return 0   // handled separately; not a simple offset
        default: return TimeInterval(rawValue * 60)
        }
    }

    public var label: String {
        switch self {
        case .atTheTime: return "At the time"
        case .tenMinutes: return "10 minutes before"
        case .thirtyMinutes: return "30 minutes before"
        case .oneHour: return "1 hour before"
        case .twoHours: return "2 hours before"
        case .theEveningBefore: return "The evening before"
        }
    }

    /// Offered in the interface, in the order shown.
    public static let choices: [ReminderLead] = [
        .atTheTime, .tenMinutes, .thirtyMinutes, .oneHour, .twoHours, .theEveningBefore
    ]

    public static func < (a: ReminderLead, b: ReminderLead) -> Bool { a.rawValue < b.rawValue }
}

/// Per-rule reminder settings.
///
/// Separate from whether the rule is *kept*: turning reminders off silences a
/// rule without changing whether it is due or how it is scored. Someone who
/// knows their own morning routine should be able to stop the buzzing without
/// the app quietly deciding they have stood the rule down.
public struct RuleReminders: Sendable, Hashable, Codable {
    public var enabled: Bool
    /// More than one is allowed — an hour before to get ready, ten minutes
    /// before to actually leave. Empty falls back to the policy default.
    public var leads: [ReminderLead]

    public init(enabled: Bool = true, leads: [ReminderLead] = [.tenMinutes]) {
        self.enabled = enabled
        self.leads = leads
    }

    public static let `default` = RuleReminders()
    public static let silent = RuleReminders(enabled: false)

    /// Useful for something you travel to.
    public static let forService = RuleReminders(leads: [.oneHour, .tenMinutes])
}
