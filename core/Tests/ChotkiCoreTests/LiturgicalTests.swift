import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

/// Serves recorded orthocal responses and counts requests, so the suite proves
/// both the decoding and the cache-first behaviour without a network.
private final class FixtureFetcher: HTTPFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URL] = []
    let failEverything: Bool

    init(failEverything: Bool = false) { self.failEverything = failEverything }

    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return _requests.count }

    /// Synchronous on purpose: lock and unlock may not straddle a suspension
    /// point, so the critical section lives in its own non-async function.
    private func record(_ url: URL) {
        lock.lock(); defer { lock.unlock() }
        _requests.append(url)
    }

    func data(from url: URL) async throws -> Data {
        record(url)
        if failEverything { throw HTTPError.transport("offline") }

        // .../api/{reckoning}/{y}/{m}/{d}/
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard parts.count >= 5, let y = Int(parts[2]), let m = Int(parts[3]), let day = Int(parts[4]) else {
            throw HTTPError.status(404)
        }
        let name = String(format: "%@-%04d-%02d-%02d", parts[1], y, m, day)
        guard let file = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json") else {
            throw HTTPError.status(404)
        }
        return try Data(contentsOf: file)
    }
}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
    return try Data(contentsOf: url)
}

@Suite("Orthocal decoding")
struct OrthocalDecodingTests {

    @Test("decodes a fasting weekday")
    func decodesFast() throws {
        let day = try OrthocalClient.decode(
            try fixture("gregorian-2026-08-19"),
            civilDate: d(2026, 8, 19), reckoning: .revisedJulian, now: Date()
        )
        #expect(day.summaryTitle.contains("Andrew Stratelates"))
        #expect(day.isFast)
        #expect(day.tone == 2)
        #expect(day.abstentions.contains("meat"))
        #expect(day.readings.count >= 1)
        #expect(day.readings.first?.text.isEmpty == false, "passage text must come through")
    }

    // The API answers a civil request with the date in the requested reckoning.
    // Keying the cache on what it reports would misfile every Old Calendar day
    // by thirteen days.
    @Test("the civil date stays the key while the reported date is data")
    func civilDateIsTheKey() throws {
        let day = try OrthocalClient.decode(
            try fixture("julian-2027-01-13"),
            civilDate: d(2027, 1, 13), reckoning: .julian, now: Date()
        )
        #expect(day.civilDate == d(2027, 1, 13), "keyed by the day on the wall calendar")
        #expect(day.observedDate == d(2026, 12, 31), "reported as 31 December Old Style")
    }

    /// The case the plan names as proof of the whole liturgical layer.
    @Test("13 January 2027 is fast-free on the Old Calendar and a fast on the New")
    func theProofCase() throws {
        let old = try OrthocalClient.decode(
            try fixture("julian-2027-01-13"), civilDate: d(2027, 1, 13), reckoning: .julian, now: Date()
        )
        let new = try OrthocalClient.decode(
            try fixture("gregorian-2027-01-13"), civilDate: d(2027, 1, 13), reckoning: .revisedJulian, now: Date()
        )
        #expect(!old.isFast)
        #expect(old.isFastFree)
        #expect(old.summaryTitle.contains("Leavetaking of the Nativity"))
        #expect(new.isFast)
        #expect(new.abstentions.contains("meat"))
    }

    // Both reckonings compute Pascha the same way, so the movable cycle is
    // shared. If this ever fails, an assumption in design.md has broken.
    @Test("Pascha falls on the same civil day under both reckonings")
    func paschaIsShared() throws {
        for (name, reckoning) in [("julian-2026-04-12", Reckoning.julian), ("gregorian-2026-04-12", .revisedJulian)] {
            let day = try OrthocalClient.decode(
                try fixture(name), civilDate: d(2026, 4, 12), reckoning: reckoning, now: Date()
            )
            #expect(day.summaryTitle.contains("Pascha"), "\(name) should be Pascha")
            #expect(day.paschaDistance == 0)
        }
    }

    @Test("Great Feasts are ranked 7 and above, lesser ranks are not")
    func greatFeastRanking() throws {
        let dormition = try OrthocalClient.decode(
            try fixture("julian-2026-08-28"), civilDate: d(2026, 8, 28), reckoning: .julian, now: Date()
        )
        #expect(dormition.isGreatFeast)
        #expect(dormition.summaryTitle.contains("Dormition"))

        // The same civil day on the New Calendar is a ranked day, not a Great Feast.
        let ordinary = try OrthocalClient.decode(
            try fixture("gregorian-2026-08-28"), civilDate: d(2026, 8, 28), reckoning: .revisedJulian, now: Date()
        )
        #expect(!ordinary.isGreatFeast)
    }

    @Test("fasting seasons map from the numeric level", arguments: [
        ("julian-2026-12-25", FastingSeason.nativityFast),
        ("julian-2026-08-19", FastingSeason.dormitionFast),
        ("julian-2026-06-20", FastingSeason.apostlesFast)
    ])
    func seasonMapping(name: String, expected: FastingSeason) throws {
        let parts = name.split(separator: "-")
        let date = d(Int(parts[1])!, Int(parts[2])!, Int(parts[3])!)
        let day = try OrthocalClient.decode(try fixture(name), civilDate: date, reckoning: .julian, now: Date())
        #expect(day.season == expected)
    }

    // A feast falling on a fast day relaxes it rather than lifting it. The
    // description must convey both, and must read as description not instruction.
    @Test("a relaxed fast reports both the fast and its exception")
    func relaxedFast() throws {
        let day = try OrthocalClient.decode(
            try fixture("julian-2026-08-19"), civilDate: d(2026, 8, 19), reckoning: .julian, now: Date()
        )
        #expect(day.isFast, "still the Dormition Fast")
        #expect(day.fastDescription.contains("Dormition Fast"))
        #expect(day.fastDescription.contains("Fish, Wine and Oil"))
        #expect(!day.fastDescription.lowercased().contains("do not"), "describes, never instructs")
    }
}

@Suite("Liturgical service")
struct LiturgicalServiceTests {

    private func service(_ fetcher: FixtureFetcher, _ reckoning: Reckoning = .julian) -> (LiturgicalService, any Store) {
        let store = InMemoryStore()
        let service = LiturgicalService(
            store: store,
            client: OrthocalClient(http: fetcher, host: "https://orthocal.info"),
            jurisdiction: Jurisdiction(name: "Test", reckoning: reckoning, tradition: .russian)
        )
        return (service, store)
    }

    @Test("a refresh fetches the window and caches it")
    func refreshCaches() async throws {
        let fetcher = FixtureFetcher()
        let (service, store) = service(fetcher)
        let fetched = await service.refresh(from: d(2026, 8, 19), days: 1)
        #expect(fetched == 1)
        #expect(try store.liturgicalDay(civilDate: d(2026, 8, 19), reckoning: .julian) != nil)
        #expect(!service.isOffline)
    }

    // The network is only ever a refill. A day already held is never requested.
    @Test("a cached day is never requested again")
    func cacheFirst() async throws {
        let fetcher = FixtureFetcher()
        let (service, _) = service(fetcher)
        await service.refresh(from: d(2026, 8, 19), days: 1)
        let afterFirst = fetcher.requestCount
        await service.refresh(from: d(2026, 8, 19), days: 1)
        #expect(fetcher.requestCount == afterFirst, "the second refresh made no request")
    }

    // Opening the app with no network shows the day, not a spinner and not an
    // error. A failed refresh is a state to reflect, never a failure to raise.
    @Test("offline keeps working from cache and never throws")
    func offlineFallback() async throws {
        let fetcher = FixtureFetcher()
        let (service, _) = service(fetcher)
        await service.refresh(from: d(2026, 8, 19), days: 1)

        let offlineFetcher = FixtureFetcher(failEverything: true)
        let offlineService = LiturgicalService(
            store: InMemoryStore(),
            client: OrthocalClient(http: offlineFetcher),
            jurisdiction: Jurisdiction(name: "Test", reckoning: .julian, tradition: .russian)
        )
        let fetched = await offlineService.refresh(from: d(2026, 8, 19), days: 3)
        #expect(fetched == 0)
        #expect(offlineService.isOffline, "the interface marks content as cached")
        #expect(offlineService.cachedDay(for: d(2026, 8, 19)) == nil)
        // The original service still answers from what it holds.
        #expect(service.cachedDay(for: d(2026, 8, 19)) != nil)
        #expect(service.isFastDay(d(2026, 8, 19)))
    }

    @Test("the provider answers the recurrence engine synchronously from cache")
    func drivesRecurrence() async throws {
        let fetcher = FixtureFetcher()
        let (service, _) = service(fetcher)
        await service.refresh(from: d(2026, 8, 19), days: 1)

        let rule = Rule(title: "Keep the fast", recurrence: .liturgical(.fastDay))
        let activations = [Activation(ruleID: rule.id, from: d(2026, 1, 1))]
        let engine = RecurrenceEngine(
            liturgical: service, observances: ObservanceSettings(fasting: .observed)
        )
        let due = engine.dueDates(
            rule: rule, activations: activations, from: d(2026, 8, 19), through: d(2026, 8, 19)
        )
        #expect(due == [d(2026, 8, 19)], "the Dormition Fast is in force")
    }

    @Test("switching jurisdiction re-targets without discarding what is cached")
    func jurisdictionSwitch() async throws {
        let fetcher = FixtureFetcher()
        let store = InMemoryStore()
        let service = LiturgicalService(
            store: store,
            client: OrthocalClient(http: fetcher),
            jurisdiction: Jurisdiction(name: "Old", reckoning: .julian, tradition: .russian)
        )
        await service.refresh(from: d(2027, 1, 13), days: 1)
        #expect(!service.isFastDay(d(2027, 1, 13)), "fast-free on the Old Calendar")

        try service.setJurisdiction(
            Jurisdiction(name: "New", reckoning: .revisedJulian, tradition: .greek), around: d(2027, 1, 13)
        )
        await service.refresh(from: d(2027, 1, 13), days: 1)
        #expect(service.isFastDay(d(2027, 1, 13)), "a fast on the New Calendar")

        // Switching back costs no request: the Julian day was kept.
        let before = fetcher.requestCount
        try service.setJurisdiction(
            Jurisdiction(name: "Old", reckoning: .julian, tradition: .russian), around: d(2027, 1, 13)
        )
        #expect(!service.isFastDay(d(2027, 1, 13)))
        #expect(fetcher.requestCount == before, "no refetch needed to switch back")
    }
}

/// The month grid asks about forty-two days on every redraw, most of them
/// outside the cached window, so misses are remembered. That memory must not
/// outlive a change of reckoning.
@Suite("Remembering absences")
struct AbsenceCacheTests {

    private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: y, month: m, day: day)!
    }

    @Test("a day with no record reads as absent, repeatedly and consistently")
    func absentStaysAbsent() throws {
        let store = InMemoryStore()
        let service = LiturgicalService(store: store, jurisdiction: .default)
        let date = d(2026, 8, 19)

        #expect(service.cachedDay(for: date) == nil)
        #expect(service.cachedDay(for: date) == nil, "and again, from memory")
    }

    @Test("a day that arrives later is no longer treated as absent")
    func arrivalClearsTheMemory() throws {
        let store = InMemoryStore()
        let service = LiturgicalService(store: store, jurisdiction: .default)
        let date = d(2026, 8, 19)

        #expect(service.cachedDay(for: date) == nil)

        try store.saveLiturgicalDay(sampleDay(date, reckoning: .julian))
        try service.loadSnapshot(around: date)

        #expect(service.cachedDay(for: date) != nil, "the record must become visible")
    }

    // Both caches are keyed by civil date but answer for one reckoning.
    @Test("changing reckoning forgets what was absent")
    func switchingReckoningClearsIt() throws {
        let store = InMemoryStore()
        let service = LiturgicalService(store: store, jurisdiction: .default)
        let date = d(2026, 8, 19)

        #expect(service.cachedDay(for: date) == nil)

        // The New Calendar has a record for that civil day.
        try store.saveLiturgicalDay(sampleDay(date, reckoning: .revisedJulian))
        try service.setJurisdiction(
            Jurisdiction(name: "Greek", reckoning: .revisedJulian, tradition: .greek),
            around: date
        )

        #expect(service.cachedDay(for: date) != nil,
                "a stale absence would make the whole calendar look empty")
    }

    private func sampleDay(_ date: CalendarDate, reckoning: Reckoning) -> LiturgicalDay {
        LiturgicalDay(
            civilDate: date, reckoning: reckoning, observedDate: date,
            tone: 2, title: nil, summaryTitle: "A commemoration", saints: [], feasts: [],
            fastLevel: 1, fastLevelDescription: "Fast", fastException: 0,
            fastExceptionDescription: nil, abstentions: ["meat"],
            feastLevel: 0, feastLevelDescription: "Liturgy",
            readings: [], paschaDistance: 129, fetchedAt: Date()
        )
    }
}
