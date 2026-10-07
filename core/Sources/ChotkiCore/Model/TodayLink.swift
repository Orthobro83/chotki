import Foundation

/// The link back to today that the calendar shows once it has been moved away from it.
///
/// Away in the future, the link points back, on the left: "← Today". Away in the past, it points
/// forward, on the right: "Today →". On today it is not there at all. The decision is here so that
/// every platform shows the same link on the same side.
public enum TodayLink: Sendable, Equatable {
    /// Today is earlier than where the calendar is: shown on the left, as "← Today".
    case onTheLeft
    /// Today is later than where the calendar is: shown on the right, as "Today →".
    case onTheRight

    public var text: String {
        switch self {
        case .onTheLeft: return "\u{2190} Today"
        case .onTheRight: return "Today \u{2192}"
        }
    }

    /// - Parameters:
    ///   - selected: the day the calendar has selected.
    ///   - visibleMonth: the month showing; only looked at while the whole month is open.
    ///   - monthOpen: whether the whole month, rather than the week, is showing.
    public static func needed(selected: CalendarDate, today: CalendarDate,
                              visibleMonth: CalendarDate, monthOpen: Bool) -> TodayLink? {
        var reference = selected
        if selected == today, monthOpen,
           visibleMonth.year != today.year || visibleMonth.month != today.month {
            reference = CalendarDate(year: visibleMonth.year, month: visibleMonth.month, day: 1) ?? visibleMonth
        }
        if reference == today { return nil }
        return reference > today ? .onTheLeft : .onTheRight
    }
}
