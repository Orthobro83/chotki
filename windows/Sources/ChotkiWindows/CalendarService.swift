import Foundation
import Dispatch
import ChotkiCore
import WindowsUI

/// Only synthetic review uses this fetcher. Normal launches use URLSessionFetcher.
/// Its verses carry keys, as Orthocal's do: the app shows no text from a reading whose verses have none.
struct ReviewCalendarFetcher: HTTPFetching {
    func data(from url: URL) async throws -> Data {
        let parts = url.pathComponents
        let y = Int(parts[parts.count-3])!, m = Int(parts[parts.count-2])!, d = Int(parts[parts.count-1])!
        let date = CalendarDate(year: y, month: m, day: d)!
        let old = parts.contains("julian") ? date.adding(days: -13) : date
        let fixtureURL = WindowsAssets.root.appendingPathComponent("Preview/calendar.json")
        let fixture = try JSONDecoder().decode(LiturgicalDay.self, from: Data(contentsOf: fixtureURL))
        let readings = fixture.readings.map { ["source": $0.source, "display": $0.display, "short_display": $0.shortDisplay,
                                               "passage": [["book": "MAT", "chapter": 1, "verse": 1, "content": $0.text, "paragraph_start": true]]] as [String: Any] }
        let payload: [String: Any] = ["year": old.year, "month": old.month, "day": old.day, "tone": fixture.tone ?? 1,
            "titles": [fixture.title ?? "Synthetic calendar day"], "summary_title": fixture.summaryTitle,
            "saints": fixture.saints, "feasts": fixture.feasts, "feast_level": fixture.feastLevel,
            "feast_level_description": fixture.feastLevelDescription, "fast_level": fixture.fastLevel,
            "fast_level_desc": fixture.fastLevelDescription, "fast_exception": fixture.fastException,
            "fast_exception_desc": fixture.fastExceptionDescription ?? "", "fast_abstentions": fixture.abstentions,
            "pascha_distance": Pascha.distance(on: date), "readings": readings]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}

extension WindowsApp {
    /// A normal launch ships the calendar. Synthetic review has none, so every verification controls what a
    /// day holds, unless CHOTKI_REVIEW_SHIPPED=1 asks a review window to use it, to test the real thing.
    static func calendarBundle(review: Bool) -> BundledCalendar? {
        if !review || ProcessInfo.processInfo.environment["CHOTKI_REVIEW_SHIPPED"] == "1" { return .standard }
        return nil
    }

    func resetCalendarService() throws {
        calendarTask?.cancel()
        calendarGeneration += 1
        // In-flight requests for an older reckoning retain their own snapshot.
        // They may populate that valid cache, but cannot repaint the new calendar.
        liturgical = LiturgicalService(store: store,
            client: review ? OrthocalClient(http: ReviewCalendarFetcher()) : OrthocalClient(),
            jurisdiction: settings.jurisdiction, bundle: WindowsApp.calendarBundle(review: review))
        try liturgical.loadSnapshot(around: selectedDate, window: 42)
        calendarRequest = ""
    }

    func requestCalendar() {
        let start: CalendarDate, count: Int
        if calendarExpanded {
            let first = CalendarDate(year: visibleMonth.year, month: visibleMonth.month, day: 1)!
            start = first.adding(days: 1-first.weekday.rawValue); count = 42
        } else { start = weekAnchor.adding(days: -3); count = 7 }
        let key = "\(settings.jurisdiction.reckoning.rawValue):\(start.iso):\(count):\(selectedDate.iso)"
        guard key != calendarRequest else { return }
        calendarRequest = key
        calendarTask?.cancel()
        calendarGeneration += 1
        let generation = calendarGeneration, service = liturgical, selected = selectedDate
        let dates = [selected] + (0..<count).map { start.adding(days: $0) }.filter { $0 != selected }
        calendarTask = Task.detached(priority: .utility) {
            for date in dates {
                if Task.isCancelled { return }
                _ = await service.refresh(from: date, days: 1)
                if Task.isCancelled { return }
                // The Win32 message loop owns UI callbacks. Never hop to a Dispatch
                // main queue that the native GetMessage loop does not service.
                ch_post(-3, generation)
            }
        }
    }
}

func verifyCalendarNetwork() throws {
    let store = try SQLiteStore.inMemory()
    let date = CalendarDate(Date(), in: .current)
    // This test is about the network path, so it runs without the calendar that ships with the app.
    let service = LiturgicalService(store: store, bundle: nil)
    let complete = DispatchSemaphore(value: 0)
    Task.detached {
        _ = await service.refresh(from: date, days: 1)
        complete.signal()
    }
    guard complete.wait(timeout: .now()+40) == .success,
          let day = service.cachedDay(for: date), !day.readings.isEmpty,
          try store.liturgicalDay(civilDate: date, reckoning: .revisedJulian) != nil else {
        throw BootstrapError.verification("Live calendar fetch failed or did not populate SQLite")
    }
    print("Calendar network passed: \(date.iso), \(day.readings.count) readings, SQLite cache populated.")
}

/// Counts and refuses every request, so the check below can prove the app asked for nothing.
private final class RefusingCalendarFetcher: HTTPFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requests: Int { lock.lock(); defer { lock.unlock() }; return count }
    /// Synchronous on purpose: a lock may not straddle a suspension point.
    private func note() { lock.lock(); count += 1; lock.unlock() }
    func data(from url: URL) async throws -> Data {
        note()
        throw HTTPError.transport("offline")
    }
}

/// The calendar that ships with the app, on Windows: its resources load beside the executable (the
/// build tree, the packaged payload and the installed copy all run this), it answers with no network,
/// and its readings carry the right text and paragraphs. Fictional store; nothing real is opened.
func verifyShippedCalendar() throws {
    guard let bundle = BundledCalendar.standard else {
        throw BootstrapError.verification("The shipped calendar did not load from the bundled resources")
    }
    func date(_ y: Int, _ m: Int, _ d: Int) -> CalendarDate { CalendarDate(year: y, month: m, day: d)! }
    guard bundle.first == date(2026, 1, 1), bundle.last == date(2031, 12, 31) else {
        throw BootstrapError.verification("The shipped calendar covers an unexpected window")
    }
    let fetcher = RefusingCalendarFetcher()
    for reckoning in Reckoning.allCases {
        let service = LiturgicalService(
            store: try SQLiteStore.inMemory(), client: OrthocalClient(http: fetcher),
            jurisdiction: Jurisdiction(name: "Synthetic", reckoning: reckoning, tradition: .russian), bundle: bundle)
        for day in [date(2026, 1, 1), date(2027, 4, 29), date(2028, 2, 29), date(2031, 12, 31)] {
            guard let found = service.cachedDay(for: day), !found.readings.isEmpty,
                  found.readings.allSatisfy({ !$0.text.isEmpty }) else {
                throw BootstrapError.verification("Shipped calendar day \(day.iso) \(reckoning) is missing or has empty readings")
            }
        }
        guard service.cachedDay(for: date(2032, 1, 1)) == nil else {
            throw BootstrapError.verification("A day past the shipped calendar must be absent")
        }
        let complete = DispatchSemaphore(value: 0)
        Task.detached { _ = await service.refresh(from: date(2027, 1, 1), days: 30); complete.signal() }
        guard complete.wait(timeout: .now() + 20) == .success else {
            throw BootstrapError.verification("Refresh over the shipped calendar did not finish")
        }
    }
    guard fetcher.requests == 0 else {
        throw BootstrapError.verification("The app asked the network for \(fetcher.requests) days the shipped calendar has")
    }
    // Holy Thursday 2027: a long Gospel that carries paragraph breaks from the Bible's own marks.
    let service = LiturgicalService(store: try SQLiteStore.inMemory(), jurisdiction: .default, bundle: bundle)
    guard let thursday = service.cachedDay(for: date(2027, 4, 29)),
          thursday.readings.contains(where: { $0.text.contains("\n\n") && !$0.text.contains("\u{00B6}") }) else {
        throw BootstrapError.verification("Shipped readings lost their paragraph breaks")
    }
    // Composite readings are never Orthocal's translation: they resolve to the cited scripture.
    guard let composite = ScriptureText.composite(display: "Composite 24 - Leviticus 26"),
          ScriptureText.text(for: composite)?.hasPrefix("Ye shall make you no idols") == true else {
        throw BootstrapError.verification("A Composite reading did not resolve from the bundled Bible")
    }
    print("Shipped calendar verified: \(bundle.first.iso) to \(bundle.last.iso), both reckonings, no network, paragraphs and Composite resolution.")
}
