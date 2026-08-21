import Foundation

/// One rule on one day, with whatever has become of it.
public struct DayEntry: Sendable, Identifiable, Hashable {
    public let rule: Rule
    public let date: CalendarDate
    public let occurrence: Occurrence?
    /// Why the Church has lifted this rule today, if it has.
    public let dispensation: String?

    public init(
        rule: Rule, date: CalendarDate, occurrence: Occurrence?, dispensation: String?
    ) {
        self.rule = rule
        self.date = date
        self.occurrence = occurrence
        self.dispensation = dispensation
    }

    public var id: String { "\(rule.id):\(date.iso)" }
    public var status: OccurrenceStatus? { occurrence?.status }
    public var isKept: Bool { status == .completed || status == .completedLate }
    public var isStoodDown: Bool { status == .skipped || status == .cancelled }
    public var isDispensed: Bool { dispensation != nil }

    /// Shown with a tick either way — but a dispensed day was never asked of
    /// anyone, so it is not something they did.
    public var showsAsSatisfied: Bool { isKept || isDispensed }
}
