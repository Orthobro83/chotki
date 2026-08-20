import Foundation
import ChotkiCore

/// The editor's view of a recurrence, and the way back.
///
/// Extracted from the view so the round trip can be tested. It had three silent
/// data-loss bugs: a one-off day became a daily rule, a Great Lent rule became
/// a general fast-day rule, and a monthly rule's short-month policy reset. Each
/// happened because the form could not express the shape it had loaded, so
/// saving replaced it with something else — without saying so.
struct RecurrenceForm: Equatable {

    enum Kind: String, CaseIterable, Hashable {
        case once = "Just one day"
        case daily = "Every day"
        case weekly = "Certain weekdays"
        case monthly = "Once a month"
        case fastDays = "Fast days"
        case season = "Through a fasting season"
        case greatFeasts = "Great feasts"
    }

    var kind: Kind = .daily
    var weekdays: Set<Weekday> = [.sunday]
    var monthDay: Int = 1
    /// No control for this; carried through so an edit cannot change it.
    var shortMonthPolicy: ShortMonthPolicy = .lastDay
    var season: FastingSeason = .greatLent
    var onceDate: CalendarDate?

    init() {}

    init(_ recurrence: Recurrence) {
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
    func recurrence(fallback: CalendarDate) -> Recurrence {
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
