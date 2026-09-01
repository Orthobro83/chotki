import Foundation

/// A slice of the record by year and month.
///
/// The overlay's date list grows without limit — seven a week, and the point of
/// the feature is years — so it is scoped rather than paged. nil means "all",
/// which is why both fields are optional rather than defaulted to the current
/// year.
public struct ReflectionPeriod: Sendable, Hashable, Codable {
    /// nil means every year.
    public var year: Int?
    /// nil means every month. 1–12.
    public var month: Int?

    public static let all = ReflectionPeriod()

    public init(year: Int? = nil, month: Int? = nil) {
        self.year = year
        self.month = month
    }

    public func contains(_ date: CalendarDate) -> Bool {
        if let year, date.year != year { return false }
        if let month, date.month != month { return false }
        return true
    }

    public var isAll: Bool { year == nil && month == nil }
}

/// One weekday's answers, newest first, already scoped to a period.
///
/// This exists so the overlay's stepping is a decision in `core` with tests
/// rather than arithmetic in a view. The direction is the part that is easy to
/// get backwards — entries are newest first, so *older* means a **higher**
/// index — and it was in fact got backwards once in the mockup before this type
/// existed.
public struct ReflectionSeries: Sendable, Hashable {
    public let weekday: Weekday
    /// Newest first.
    public let entries: [ReflectionEntry]
    public let period: ReflectionPeriod

    public init(weekday: Weekday, entries: [ReflectionEntry], period: ReflectionPeriod = .all) {
        self.weekday = weekday
        self.entries = entries
        self.period = period
    }

    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }

    public func entry(at index: Int) -> ReflectionEntry? {
        entries.indices.contains(index) ? entries[index] : nil
    }

    public func index(of date: CalendarDate) -> Int? {
        entries.firstIndex { $0.date == date }
    }

    /// One step back in time, or nil at the far end.
    ///
    /// Returning nil rather than wrapping is deliberate: the arrows disable at
    /// the ends. Wrapping from the oldest entry to the newest would make a
    /// journal feel like a carousel.
    public func older(than index: Int) -> Int? {
        let next = index + 1
        return entries.indices.contains(next) ? next : nil
    }

    /// One step forward in time, or nil at the near end.
    public func newer(than index: Int) -> Int? {
        let next = index - 1
        return entries.indices.contains(next) ? next : nil
    }

    /// "2 of 3", one-based, for display beside the arrows. nil when empty.
    public func position(of index: Int) -> (ordinal: Int, total: Int)? {
        guard entries.indices.contains(index) else { return nil }
        return (index + 1, entries.count)
    }
}

/// What the record says. Every question the section asks of the data is
/// answered here rather than in a view.
public enum ReflectionJournal {

    /// One weekday's entries, newest first, scoped to a period.
    public static func series(
        _ all: [ReflectionEntry], on weekday: Weekday, in period: ReflectionPeriod = .all
    ) -> ReflectionSeries {
        let mine = all
            .filter { $0.weekday == weekday && period.contains($0.date) }
            .sorted { $0.date > $1.date }
        return ReflectionSeries(weekday: weekday, entries: mine, period: period)
    }

    /// The most recent answer to a weekday, whenever it was written.
    ///
    /// Deliberately unscoped by period: this answers "when did I last write
    /// this one", which a filter should not be able to change.
    public static func mostRecent(_ all: [ReflectionEntry], on weekday: Weekday) -> ReflectionEntry? {
        series(all, on: weekday).entries.first
    }

    /// Whether a date already carries an answer. An answer locks on save, so
    /// this is what stops a second one being offered for the same day.
    public static func hasEntry(_ all: [ReflectionEntry], on date: CalendarDate) -> Bool {
        all.contains { $0.date == date && $0.weekday == date.weekday }
    }

    /// Every year with an answer, newest first. Feeds the period pop-up, so
    /// years with nothing in them are never offered.
    public static func years(_ all: [ReflectionEntry], on weekday: Weekday? = nil) -> [Int] {
        let mine = weekday.map { w in all.filter { $0.weekday == w } } ?? all
        return Array(Set(mine.map(\.date.year))).sorted(by: >)
    }

    /// Every month with an answer in a given year, in calendar order.
    public static func months(_ all: [ReflectionEntry], on weekday: Weekday? = nil, year: Int) -> [Int] {
        let mine = weekday.map { w in all.filter { $0.weekday == w } } ?? all
        return Array(Set(mine.filter { $0.date.year == year }.map(\.date.month))).sorted()
    }

    /// Merge on import. **Never discards.**
    ///
    /// Keyed by weekday and date, which is the same key the store makes unique.
    /// What is already here wins on a collision: an import is additive, and a
    /// file from a stale export must never be able to overwrite an answer
    /// written since. This is the rule the artifact learned first and it has
    /// not changed.
    public static func merge(
        existing: [ReflectionEntry], incoming: [ReflectionEntry]
    ) -> [ReflectionEntry] {
        var byKey: [String: ReflectionEntry] = [:]
        for entry in existing { byKey[key(entry)] = entry }
        var added: [ReflectionEntry] = []
        for entry in incoming where byKey[key(entry)] == nil {
            byKey[key(entry)] = entry
            added.append(entry)
        }
        return added.sorted { $0.date < $1.date }
    }

    private static func key(_ entry: ReflectionEntry) -> String {
        "\(entry.weekday.rawValue):\(entry.date.iso)"
    }
}
