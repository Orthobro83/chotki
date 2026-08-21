import Foundation

/// The editor's view of a recurrence, and the way back.
///
/// Extracted from the view so the round trip can be tested. It had three silent
/// data-loss bugs: a one-off day became a daily rule, a Great Lent rule became
/// a general fast-day rule, and a monthly rule's short-month policy reset. Each
/// happened because the form could not express the shape it had loaded, so
/// saving replaced it with something else — without saying so.
public struct RecurrenceForm: Equatable, Sendable {

    public enum Kind: String, CaseIterable, Hashable, Sendable {
        case once = "Just one day"
        case daily = "Every day"
        case weekly = "Certain weekdays"
        case monthly = "Once a month"
        case fastDays = "Fast days"
        case season = "Through a fasting season"
        case greatFeasts = "Great feasts"
    }

    public var kind: Kind = .daily
    public var weekdays: Set<Weekday> = [.sunday]
    public var monthDay: Int = 1
    /// No control for this; carried through so an edit cannot change it.
    public var shortMonthPolicy: ShortMonthPolicy = .lastDay
    public var season: FastingSeason = .greatLent
    public var onceDate: CalendarDate?

    public init() {}

    public init(_ recurrence: Recurrence) {
        switch recurrence {
        case .once(let day):
            kind = .once; onceDate = day
        case .daily:
            kind = .daily
        case .weekly(let days):
            kind = .weekly; weekdays = days
        case .monthly(let day, let policy):
            kind = .monthly; monthDay = day; shortMonthPolicy = policy
        case .liturgical(let trigger):
            switch trigger {
            case .fastDay: kind = .fastDays
            case .greatFeast: kind = .greatFeasts
            case .season(let which): kind = .season; season = which
            }
        }
    }

    /// `fallback` is used only when a one-off rule somehow has no day, so that
    /// it stays a single day rather than quietly becoming a daily rule.
    public func recurrence(fallback: CalendarDate) -> Recurrence {
        switch kind {
        case .once: return .once(onceDate ?? fallback)
        case .daily: return .daily
        case .weekly: return .weekly(days: weekdays.isEmpty ? [.sunday] : weekdays)
        case .monthly: return .monthly(day: monthDay, whenShort: shortMonthPolicy)
        case .fastDays: return .liturgical(.fastDay)
        case .season: return .liturgical(.season(season))
        case .greatFeasts: return .liturgical(.greatFeast)
        }
    }
}
