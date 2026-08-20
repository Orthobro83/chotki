import Foundation

/// Cache-first access to the church calendar.
///
/// Two rules govern this type. The network is only ever a refill — every read
/// is answered from cache, so opening the app on a plane shows the day rather
/// than a spinner. And `LiturgicalDayProvider` conformance is **synchronous**:
/// the recurrence engine asks whether a day is a fast and gets an answer
/// immediately, from an in-memory snapshot, never an await.
public final class LiturgicalService: LiturgicalDayProvider, @unchecked Sendable {

    private let store: any Store
    private let client: OrthocalClient
    private let lock = NSLock()

    private var _jurisdiction: Jurisdiction
    /// Snapshot of the cache for the current reckoning, so the synchronous
    /// provider methods never touch SQLite on a hot path.
    private var knownAbsent: Set<CalendarDate> = []
    private var snapshot: [CalendarDate: LiturgicalDay] = [:]
    private var _lastRefreshFailed = false
    private var _lastSuccessfulRefresh: Date?

    public init(store: any Store, client: OrthocalClient = OrthocalClient(), jurisdiction: Jurisdiction = .default) {
        self.store = store
        self.client = client
        self._jurisdiction = jurisdiction
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    public var jurisdiction: Jurisdiction { locked { _jurisdiction } }

    /// True when the last attempt to reach orthocal failed. The interface uses
    /// this to mark content as cached — never to show an error where text
    /// should be.
    public var isOffline: Bool { locked { _lastRefreshFailed } }
    public var lastSuccessfulRefresh: Date? { locked { _lastSuccessfulRefresh } }

    // MARK: jurisdiction

    /// Cached days for the previous reckoning are kept rather than deleted:
    /// a Julian day remains a correct Julian day, so switching back is instant
    /// and costs no requests. Only the snapshot re-targets.
    public func setJurisdiction(_ jurisdiction: Jurisdiction, around date: CalendarDate, window: Int = 14) throws {
        locked {
            _jurisdiction = jurisdiction
            snapshot = [:]
            // Both caches are keyed by civil date but hold answers for one
            // reckoning. Keeping the misses would make every day look absent
            // after a switch from Old to New calendar.
            knownAbsent = []
        }
        try loadSnapshot(around: date, window: window)
    }

    // MARK: cache

    /// Pull the cached window into memory. Call on launch and after a refresh.
    public func loadSnapshot(around date: CalendarDate, window: Int = 14) throws {
        let reckoning = jurisdiction.reckoning
        let days = try store.liturgicalDays(
            reckoning: reckoning,
            from: date.adding(days: -window),
            through: date.adding(days: window)
        )
        locked {
            for day in days {
                snapshot[day.civilDate] = day
                knownAbsent.remove(day.civilDate)
            }
        }
    }

    public func cachedDay(for date: CalendarDate) -> LiturgicalDay? {
        if let hit = locked({ snapshot[date] }) { return hit }
        // A month grid asks about forty-two days on every redraw, and most of
        // them fall outside the cached window. Without remembering the misses,
        // each redraw ran forty-two queries that were always going to find
        // nothing. Cleared whenever new days arrive or the reckoning changes.
        if locked({ knownAbsent.contains(date) }) { return nil }

        let found = try? store.liturgicalDay(civilDate: date, reckoning: jurisdiction.reckoning)
        locked {
            if let found { snapshot[date] = found } else { knownAbsent.insert(date) }
        }
        return found
    }

    /// Fetch the window ahead, skipping anything already cached.
    ///
    /// Never throws. A failed refresh is a state the interface reflects, not an
    /// error the user is shown — the app carries on with what it has.
    @discardableResult
    public func refresh(from start: CalendarDate, days: Int = 14, now: Date = Date()) async -> Int {
        let reckoning = jurisdiction.reckoning
        var fetched = 0
        var anyFailure = false

        for offset in 0..<days {
            let date = start.adding(days: offset)
            if cachedDay(for: date) != nil { continue }
            do {
                let day = try await client.day(for: date, reckoning: reckoning, now: now)
                try store.saveLiturgicalDay(day)
                locked {
                    snapshot[date] = day
                    knownAbsent.remove(date)
                }
                fetched += 1
            } catch {
                anyFailure = true
            }
        }

        locked {
            _lastRefreshFailed = anyFailure
            if !anyFailure { _lastSuccessfulRefresh = now }
        }
        return fetched
    }

    // MARK: LiturgicalDayProvider

    public func isFastDay(_ date: CalendarDate) -> Bool {
        cachedDay(for: date)?.isFast ?? false
    }

    public func isGreatFeast(_ date: CalendarDate) -> Bool {
        cachedDay(for: date)?.isGreatFeast ?? false
    }

    public func season(_ date: CalendarDate) -> FastingSeason? {
        cachedDay(for: date)?.season
    }
}
