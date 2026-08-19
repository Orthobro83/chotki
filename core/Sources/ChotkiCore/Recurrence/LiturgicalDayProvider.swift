import Foundation

/// Supplies church-calendar facts to the recurrence engine.
///
/// Phase 3 implements this against orthocal and the cache. Declared now so the
/// engine's shape is settled and liturgical rules are testable against a stub.
public protocol LiturgicalDayProvider: Sendable {
    func isFastDay(_ date: CalendarDate) -> Bool
    func isGreatFeast(_ date: CalendarDate) -> Bool
    func season(_ date: CalendarDate) -> FastingSeason?
}

/// Answers "no" to everything. Used where a rule has no liturgical component,
/// and in tests of the civil recurrence paths.
public struct NoLiturgicalData: LiturgicalDayProvider {
    public init() {}
    public func isFastDay(_ date: CalendarDate) -> Bool { false }
    public func isGreatFeast(_ date: CalendarDate) -> Bool { false }
    public func season(_ date: CalendarDate) -> FastingSeason? { nil }
}
