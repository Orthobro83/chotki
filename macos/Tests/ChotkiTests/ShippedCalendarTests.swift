import Testing
import Foundation
import ChotkiCore
@testable import Chotki

/// Counts every request and fails it, so a test can prove the app never asked.
private final class RefusingFetcher: HTTPFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requests: Int { lock.lock(); defer { lock.unlock() }; return count }
    private func note() { lock.lock(); count += 1; lock.unlock() }
    func data(from url: URL) async throws -> Data {
        note()
        throw HTTPError.transport("offline")
    }
}

/// The calendar that ships with the app, as the Mac app uses it. Fictional practice, an in-memory
/// store, and a network that refuses everything: nothing here reads or writes the real record.
@MainActor
@Suite("The shipped calendar on the Mac")
struct ShippedCalendarMacTests {

    private func model(_ fetcher: RefusingFetcher, loadsCalendar: Bool = true) -> AppModel {
        AppModel(
            store: InMemoryStore(), notifier: NullNotifier(), launchAtLogin: NullLaunchAtLogin(),
            storage: .none(), startsReminders: false, writesBackups: false,
            loadsCalendar: loadsCalendar, calendarClient: OrthocalClient(http: fetcher)
        )
    }

    private func settle() async { try? await Task.sleep(nanoseconds: 400_000_000) }

    @Test("with no network at all, today and the days around it are there, and nothing is asked for")
    func airplane() async throws {
        let fetcher = RefusingFetcher()
        let app = model(fetcher)
        await settle()
        // This test is about the five shipped years; it says so rather than failing mysteriously after them.
        try #require(app.today <= CalendarDate(year: 2031, month: 12, day: 1)!)
        for offset in -3...20 {
            let day = app.liturgical.cachedDay(for: app.today.adding(days: offset))
            #expect(day != nil, "offset \(offset)")
            #expect(day?.readings.isEmpty == false)
        }
        #expect(app.liturgical.isOffline == false)
        #expect(app.liturgical.isOffline(on: app.selectedDate) == false)
        #expect(fetcher.requests == 0, "the app asked for something the shipped calendar already has")
    }

    @Test("browsing a month in the window, on either reckoning, asks for nothing")
    func browsing() async throws {
        let fetcher = RefusingFetcher()
        let app = model(fetcher)
        for reckoning in Reckoning.allCases {
            var jurisdiction = app.settings.jurisdiction
            jurisdiction.reckoning = reckoning
            app.update { $0.jurisdiction = jurisdiction }
            for month in 1...12 {
                app.visibleMonth = CalendarDate(year: 2028, month: month, day: 1)!
                await app.loadCalendarMonth()
                #expect(app.liturgical.cachedDay(for: app.visibleMonth) != nil, "\(reckoning) \(month)")
            }
        }
        await settle()
        #expect(fetcher.requests == 0)
    }

    @Test("a day past the shipped calendar is simply absent, and quietly")
    func pastTheEnd() async throws {
        let fetcher = RefusingFetcher()
        let app = model(fetcher, loadsCalendar: false)
        let beyond = CalendarDate(year: 2032, month: 2, day: 10)!
        #expect(app.liturgical.cachedDay(for: beyond) == nil)
        _ = await app.liturgical.refresh(from: beyond, days: 2)
        #expect(fetcher.requests == 2)
        #expect(app.liturgical.isOffline(on: beyond))
        #expect(app.liturgical.cachedDay(for: beyond) == nil)
    }
}
