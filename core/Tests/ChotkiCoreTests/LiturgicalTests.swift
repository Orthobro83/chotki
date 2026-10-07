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
            jurisdiction: Jurisdiction(name: "Test", reckoning: reckoning, tradition: .russian),
            bundle: nil
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
            jurisdiction: Jurisdiction(name: "Test", reckoning: .julian, tradition: .russian),
            bundle: nil
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
            jurisdiction: Jurisdiction(name: "Old", reckoning: .julian, tradition: .russian),
            bundle: nil
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
        let service = LiturgicalService(store: store, jurisdiction: .default, bundle: nil)
        let date = d(2026, 8, 19)

        #expect(service.cachedDay(for: date) == nil)
        #expect(service.cachedDay(for: date) == nil, "and again, from memory")
    }

    @Test("a day that arrives later is no longer treated as absent")
    func arrivalClearsTheMemory() throws {
        let store = InMemoryStore()
        let service = LiturgicalService(store: store, jurisdiction: .default, bundle: nil)
        let date = d(2026, 8, 19)

        #expect(service.cachedDay(for: date) == nil)

        // The unnamed default is the OCA, on the revised Julian reckoning.
        // A day stored under another reckoning is not this service's day.
        try store.saveLiturgicalDay(sampleDay(date, reckoning: service.jurisdiction.reckoning))
        try service.loadSnapshot(around: date)

        #expect(service.cachedDay(for: date) != nil, "the record must become visible")
    }

    // Both caches are keyed by civil date but answer for one reckoning.
    @Test("changing reckoning forgets what was absent")
    func switchingReckoningClearsIt() throws {
        let store = InMemoryStore()
        let service = LiturgicalService(store: store, jurisdiction: .default, bundle: nil)
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

@Suite("Identifying the app to orthocal")
struct UserAgentTests {
    @Test("requests name the app and where to find it")
    func userAgent() {
        #expect(URLSessionFetcher.userAgent.hasPrefix("Chotki"))
        #expect(URLSessionFetcher.userAgent.contains("https://github.com/rjmac83/chotki"))
    }
}

/// The calendar that ships with the app answers before the cache or the network, and the
/// network is only a refill beyond it.
@Suite("The bundled calendar in the service")
struct BundledServiceTests {

    private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: y, month: m, day: day)!
    }

    private func service(
        _ fetcher: FixtureFetcher, store: any Store = InMemoryStore(), reckoning: Reckoning = .julian
    ) -> LiturgicalService {
        LiturgicalService(
            store: store, client: OrthocalClient(http: fetcher),
            jurisdiction: Jurisdiction(name: "Test", reckoning: reckoning, tradition: .russian)
        )
    }

    @Test("a covered day is answered with an empty store, no network, and no sign of being offline")
    func coveredNeedsNothing() async throws {
        let fetcher = FixtureFetcher(failEverything: true)
        let service = service(fetcher)
        #expect(service.cachedDay(for: d(2027, 4, 16)) != nil)
        let fetched = await service.refresh(from: d(2026, 10, 1), days: 60)
        #expect(fetched == 0)
        #expect(fetcher.requestCount == 0, "nothing inside the window may be asked for")
        #expect(service.isOffline == false)
    }

    @Test("the calendar facts the recurrence engine asks for come from the bundle")
    func providerAnswers() throws {
        let service = service(FixtureFetcher(failEverything: true), reckoning: .revisedJulian)
        // Great Lent 2027 began on Monday 15 March, new and old calendar alike.
        #expect(service.isFastDay(d(2027, 3, 15)))
        #expect(service.season(d(2027, 3, 15)) == .greatLent)
        // Pascha, 2 May 2027, is a Great Feast.
        #expect(service.isGreatFeast(d(2027, 5, 2)))
        // Bright Week names itself as the reason the Wednesday fast is lifted.
        #expect(service.fastFreeReason(d(2027, 5, 5)) == "Bright Week")
    }

    @Test("a date past the bundle is asked for once, and a failure is quiet")
    func beyondTheBundle() async throws {
        let fetcher = FixtureFetcher(failEverything: true)
        let service = service(fetcher)
        let fetched = await service.refresh(from: d(2032, 1, 15), days: 1)
        #expect(fetched == 0)
        #expect(fetcher.requestCount == 1)
        #expect(service.isOffline == true)
        #expect(service.cachedDay(for: d(2032, 1, 15)) == nil)
    }

    @Test("a stored row for a covered date is never shown: the bundle wins")
    func bundleBeatsTheCache() throws {
        let store = InMemoryStore()
        let date = d(2026, 8, 19)
        try store.saveLiturgicalDay(LiturgicalDay(
            civilDate: date, reckoning: .julian, observedDate: date,
            tone: 1, title: "A stale title", summaryTitle: "stale", saints: [], feasts: [],
            fastLevel: 0, fastLevelDescription: "No Fast", fastException: 0,
            fastExceptionDescription: nil, abstentions: [], feastLevel: 0,
            feastLevelDescription: "Liturgy", readings: [], paschaDistance: 0, fetchedAt: Date()
        ))
        let service = service(FixtureFetcher(failEverything: true), store: store)
        try service.loadSnapshot(around: date)
        let shown = try #require(service.cachedDay(for: date))
        #expect(shown.title != "A stale title")
        #expect(!shown.readings.isEmpty)
    }

    @Test("Composite text cached by an older build is replaced on the way out, and the row is untouched")
    func oldCompositeIsSanitised() throws {
        let store = InMemoryStore()
        let date = d(2032, 2, 1)                      // past the bundle, so the cache answers
        let display = "Composite 24 - Leviticus 26"
        try store.saveLiturgicalDay(LiturgicalDay(
            civilDate: date, reckoning: .julian, observedDate: date,
            tone: 1, title: "t", summaryTitle: "s", saints: [], feasts: [],
            fastLevel: 0, fastLevelDescription: "No Fast", fastException: 0,
            fastExceptionDescription: nil, abstentions: [], feastLevel: 0, feastLevelDescription: "Liturgy",
            readings: [Reading(source: "Vespers", display: display, shortDisplay: "Lev", text: "A TRANSLATION THAT IS NOT OURS")],
            paschaDistance: 0, fetchedAt: Date()
        ))
        let service = service(FixtureFetcher(failEverything: true), store: store)
        let shown = try #require(service.cachedDay(for: date)?.readings.first)
        #expect(!shown.text.contains("NOT OURS"))
        #expect(shown.text.hasPrefix("Ye shall make you no idols"))
        let stored = try #require(try store.liturgicalDay(civilDate: date, reckoning: .julian))
        #expect(stored.readings.first?.text == "A TRANSLATION THAT IS NOT OURS", "the record itself is never rewritten")
    }

    @Test("with the network switched off nothing is ever requested, and nothing looks offline")
    func neverAsks() async throws {
        let fetcher = FixtureFetcher(failEverything: true)
        let service = LiturgicalService(
            store: InMemoryStore(), client: OrthocalClient(http: fetcher),
            jurisdiction: Jurisdiction(name: "Test", reckoning: .julian, tradition: .russian),
            networkPolicy: .never
        )
        #expect(await service.refresh(from: d(2032, 1, 15), days: 10) == 0)
        #expect(await service.refresh(from: d(2027, 1, 1), days: 10) == 0)
        #expect(fetcher.requestCount == 0)
        #expect(service.isOffline == false)
        #expect(service.cachedDay(for: d(2027, 1, 5)) != nil, "the bundle still answers")
        #expect(service.cachedDay(for: d(2032, 1, 15)) == nil, "and a date past it is simply absent")
    }

    @Test("a refresh that straddles the end of the bundle never makes bundled days look cached")
    func offlineIsPerDay() async throws {
        let fetcher = FixtureFetcher(failEverything: true)
        let service = service(fetcher)
        _ = await service.refresh(from: d(2031, 12, 28), days: 10)       // 28 Dec 2031 ... 6 Jan 2032
        #expect(fetcher.requestCount == 6, "only the six uncovered days are asked for")
        #expect(service.isOffline == true)
        #expect(service.isOffline(on: d(2031, 12, 30)) == false)
        #expect(service.isOffline(on: d(2032, 1, 2)) == true)
        #expect(service.isBundled(d(2031, 12, 31)) && !service.isBundled(d(2032, 1, 1)))
    }

    @Test("a service with no bundle behaves as the app did before there was one")
    func noBundle() async throws {
        let fetcher = FixtureFetcher(failEverything: true)
        let bare = LiturgicalService(
            store: InMemoryStore(), client: OrthocalClient(http: fetcher),
            jurisdiction: Jurisdiction(name: "Test", reckoning: .julian, tradition: .russian), bundle: nil
        )
        _ = await bare.refresh(from: d(2027, 1, 1), days: 3)
        #expect(fetcher.requestCount == 3)
        #expect(bare.isOffline(on: d(2027, 1, 1)) == true)
        #expect(bare.cachedDay(for: d(2027, 1, 1)) == nil)
    }

    @Test("switching reckoning re-targets the bundle without a request")
    func switchingReckoning() async throws {
        let fetcher = FixtureFetcher(failEverything: true)
        let service = service(fetcher)
        let date = d(2027, 1, 13)
        let old = try #require(service.cachedDay(for: date))
        #expect(old.observedDate == d(2026, 12, 31))
        try service.setJurisdiction(
            Jurisdiction(name: "New", reckoning: .revisedJulian, tradition: .russian), around: date
        )
        let new = try #require(service.cachedDay(for: date))
        #expect(new.observedDate == date)
        #expect(fetcher.requestCount == 0)
    }
}

@Suite("What the network may and may not put on screen")
struct NetworkTextTests {

    private func decode(_ json: String) throws -> LiturgicalDay {
        try OrthocalClient.decode(
            Data(json.utf8), civilDate: CalendarDate(year: 2032, month: 3, day: 1)!, reckoning: .julian, now: Date()
        )
    }

    private func day(readings: String) -> String {
        """
        {"year":2032,"month":3,"day":1,"tone":1,"titles":["T"],"summary_title":"S","saints":[],"feasts":[],
         "feast_level":0,"feast_level_description":"Liturgy","fast_level":0,"fast_level_desc":"No Fast",
         "fast_exception":0,"fast_exception_desc":"","fast_abstentions":[],"pascha_distance":10,
         "readings":[\(readings)]}
        """
    }

    @Test("keyed verses are joined into paragraphs by the same rule as the bundle")
    func keyedVerses() throws {
        let day = try decode(day(readings: """
        {"source":"Gospel","display":"John 3.1-3","short_display":"John 3.1-3","passage":[
         {"book":"JHN","chapter":3,"verse":1,"content":"One.","paragraph_start":true},
         {"book":"JHN","chapter":3,"verse":2,"content":"Two.","paragraph_start":false},
         {"book":"JHN","chapter":3,"verse":3,"content":"Three.","paragraph_start":true}]}
        """))
        #expect(day.readings.first?.text == "One. Two.\n\nThree.")
    }

    @Test("a known Composite reading is resolved from its citation, never from the network text")
    func knownComposite() throws {
        let day = try decode(day(readings: """
        {"source":"Vespers","display":"Composite 24 - Leviticus 26","short_display":"Composite 24","passage":[
         {"book":"","chapter":"1","verse":"1","content":"A TRANSLATION THAT IS NOT OURS","paragraph_start":true}]}
        """))
        let text = try #require(day.readings.first?.text)
        #expect(!text.contains("NOT OURS"))
        #expect(text.hasPrefix("Ye shall make you no idols"))
    }

    @Test("a Composite the app has not met has no text rather than text nobody has audited")
    func unknownComposite() throws {
        let day = try decode(day(readings: """
        {"source":"Vespers","display":"Composite 99 - Somewhere 1","short_display":"c","passage":[
         {"book":"","chapter":"1","verse":"1","content":"UNAUDITED","paragraph_start":true}]}
        """))
        #expect(day.readings.first?.text == "")
        #expect(day.readings.count == 1, "the reading is still listed, by its reference")
    }

    @Test("a reading whose verses carry no keys is not shown as text either")
    func unkeyed() throws {
        let day = try decode(day(readings: """
        {"source":"Epistle","display":"Acts 1.1","short_display":"Acts","passage":[{"content":"No key at all"}]}
        """))
        #expect(day.readings.first?.text == "")
    }
}
