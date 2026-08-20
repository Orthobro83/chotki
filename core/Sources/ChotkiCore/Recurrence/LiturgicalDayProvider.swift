import Foundation

/// Supplies church-calendar facts to the recurrence engine.
///
/// Phase 3 implements this against orthocal and the cache. Declared now so the
/// engine's shape is settled and liturgical rules are testable against a stub.
public protocol LiturgicalDayProvider: Sendable {
    func isFastDay(_ date: CalendarDate) -> Bool
    func isGreatFeast(_ date: CalendarDate) -> Bool
    func season(_ date: CalendarDate) -> FastingSeason?
    /// Why a fast that would otherwise fall on this day is not kept, if it is
    /// not. The Church lifts the weekly fast in several stretches of the year.
    func fastFreeReason(_ date: CalendarDate) -> String?
}

public extension LiturgicalDayProvider {
    /// Providers that know nothing about dispensations simply have none.
    func fastFreeReason(_ date: CalendarDate) -> String? { nil }
}

/// Answers "no" to everything. Used where a rule has no liturgical component,
/// and in tests of the civil recurrence paths.
public struct NoLiturgicalData: LiturgicalDayProvider {
    public init() {}
    public func isFastDay(_ date: CalendarDate) -> Bool { false }
    public func isGreatFeast(_ date: CalendarDate) -> Bool { false }
    public func season(_ date: CalendarDate) -> FastingSeason? { nil }
    public func fastFreeReason(_ date: CalendarDate) -> String? { nil }
}
