import Foundation

/// How much a part of the church calendar participates in this person's rule.
///
/// Three states rather than a boolean, because "I cannot fast" and "I would
/// rather not see it" are different requests, and neither is the same as
/// keeping the fast.
///
/// People come to this with real constraints: a health condition that makes
/// fasting unsafe, or no parish within reach so a Liturgy on a great feast is
/// not something they can attend. Neither is a failure, and the app must not be
/// able to represent it as one.
public enum Observance: String, Sendable, Hashable, Codable, CaseIterable {
    /// Not shown anywhere. The calendar looks like an ordinary calendar.
    case hidden
    /// Shown on the calendar as information, and nothing more. It never creates
    /// a task, never triggers a reminder, and is never scored.
    case shown
    /// Part of the rule: liturgical recurrences fire, and are scored.
    case observed

    /// Only `observed` may drive a rule or reach the score.
    public var drivesRules: Bool { self == .observed }
    public var isVisible: Bool { self != .hidden }
}

/// Which parts of the church calendar this person takes part in.
///
/// Defaults to `.shown` rather than `.observed`: the app starts by telling you
/// what the day is, and taking something on is always a deliberate act. That is
/// the same principle as shipping with no rules enabled.
public struct ObservanceSettings: Sendable, Hashable, Codable {
    public var fasting: Observance
    public var feasts: Observance

    public init(fasting: Observance = .shown, feasts: Observance = .shown) {
        self.fasting = fasting
        self.feasts = feasts
    }

    public static let `default` = ObservanceSettings()

    /// A calendar with no church annotation at all.
    public static let plain = ObservanceSettings(fasting: .hidden, feasts: .hidden)

    public func setting(for trigger: LiturgicalTrigger) -> Observance {
        switch trigger {
        case .fastDay, .season: return fasting
        case .greatFeast: return feasts
        }
    }
}
