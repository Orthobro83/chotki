import Foundation
import Dispatch
import ChotkiCore
import WindowsUI

/// Only synthetic review uses this fetcher. Normal launches use URLSessionFetcher.
struct ReviewCalendarFetcher: HTTPFetching {
    func data(from url: URL) async throws -> Data {
        let parts = url.pathComponents
        let y = Int(parts[parts.count-3])!, m = Int(parts[parts.count-2])!, d = Int(parts[parts.count-1])!
        let date = CalendarDate(year: y, month: m, day: d)!
        let old = parts.contains("julian") ? date.adding(days: -13) : date
        let fixtureURL = WindowsAssets.root.appendingPathComponent("Preview/calendar.json")
        let fixture = try JSONDecoder().decode(LiturgicalDay.self, from: Data(contentsOf: fixtureURL))
        let readings = fixture.readings.map { ["source": $0.source, "display": $0.display, "short_display": $0.shortDisplay,
                                               "passage": [["content": $0.text]]] as [String: Any] }
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
    func resetCalendarService() throws {
        calendarTask?.cancel()
        calendarGeneration += 1
        // In-flight requests for an older reckoning retain their own snapshot.
        // They may populate that valid cache, but cannot repaint the new calendar.
        liturgical = LiturgicalService(store: store,
            client: review ? OrthocalClient(http: ReviewCalendarFetcher()) : OrthocalClient(),
            jurisdiction: settings.jurisdiction)
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
    let service = LiturgicalService(store: store)
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
