import Foundation

/// Whether the network may be asked for calendar days at all.
public enum NetworkPolicy: Sendable, Equatable {
    /// The default. Ask orthocal.info only for dates that neither the bundled calendar nor the
    /// cache can answer. If it is gone, the app carries on exactly as it does offline.
    case beyondBundle
    /// Never ask. The bundled calendar and whatever is already cached are all there is.
    case never
}

/// Cache-first access to the church calendar.
///
/// **Order of answers:** the in-memory snapshot, then the calendar bundled with the app
/// (`BundledCalendar`), then the SQLite cache of days fetched from the network. The bundle
/// wins wherever it has the day, so a cached row for a covered date is left alone and never
/// shown. The network is asked only for dates none of those can answer.
///
/// Two rules govern this type. The network is only ever a refill — every read
/// is answered from cache, so opening the app on a plane shows the day rather
/// than a spinner. And `LiturgicalDayProvider` conformance is **synchronous**:
/// the recurrence engine asks whether a day is a fast and gets an answer
/// immediately, from an in-memory snapshot, never an await.
public final class LiturgicalService: LiturgicalDayProvider, @unchecked Sendable {

    private let store: any Store
    private let client: OrthocalClient
    private let bundle: BundledCalendar?
    private let networkPolicy: NetworkPolicy
    private let lock = NSLock()

    private var _jurisdiction: Jurisdiction
    /// Snapshot of the cache for the current reckoning, so the synchronous
    /// provider methods never touch SQLite on a hot path.
    private var knownAbsent: Set<CalendarDate> = []
    private var snapshot: [CalendarDate: LiturgicalDay] = [:]
    private var _lastRefreshFailed = false
    private var _lastSuccessfulRefresh: Date?

    /// `bundle` is the calendar that ships with the app; tests of the network and cache
    /// layers pass nil to exercise those alone.
    public init(
        store: any Store, client: OrthocalClient = OrthocalClient(), jurisdiction: Jurisdiction = .default,
        bundle: BundledCalendar? = .standard, networkPolicy: NetworkPolicy = .beyondBundle
    ) {
        self.store = store
        self.client = client
        self.bundle = bundle
        self.networkPolicy = networkPolicy
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

    /// Whether the day on screen is one the app is showing from its cache because the
    /// network could not be reached. A day inside the bundled calendar never is, however
    /// the last refresh went: the bundle does not depend on the network.
    public func isOffline(on date: CalendarDate) -> Bool {
        isOffline && bundle?.covers(date) != true
    }

    /// True when `date` is answered by the calendar that ships with the app.
    public func isBundled(_ date: CalendarDate) -> Bool {
        bundle?.covers(date) == true
    }

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
            for day in days where bundle?.covers(day.civilDate) != true {
                snapshot[day.civilDate] = ScriptureText.sanitised(day)
                knownAbsent.remove(day.civilDate)
            }
        }
    }

    public func cachedDay(for date: CalendarDate) -> LiturgicalDay? {
        if let hit = locked({ snapshot[date] }) { return hit }
        if let shipped = bundle?.day(civil: date, reckoning: jurisdiction.reckoning) {
            locked { snapshot[date] = shipped; knownAbsent.remove(date) }
            return shipped
        }
        // A month grid asks about forty-two days on every redraw, and most of
        // them fall outside the cached window. Without remembering the misses,
        // each redraw ran forty-two queries that were always going to find
        // nothing. Cleared whenever new days arrive or the reckoning changes.
        if locked({ knownAbsent.contains(date) }) { return nil }

        let found = (try? store.liturgicalDay(civilDate: date, reckoning: jurisdiction.reckoning))
            .map(ScriptureText.sanitised)
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
        if networkPolicy == .never { return 0 }
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

    public func fastFreeReason(_ date: CalendarDate) -> String? {
        cachedDay(for: date)?.fastFreeReason
    }

    public func akathistWeek(_ date: CalendarDate) -> Int? {
        // Not the cached day. A Friday a year ahead has not been fetched, and
        // the hymn is appointed from Pascha whether or not orthocal has answered.
        Akathist.week(paschaDistance: Pascha.distance(on: date), tradition: jurisdiction.tradition)
    }
}
