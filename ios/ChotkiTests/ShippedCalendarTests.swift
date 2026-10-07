import Testing
import Foundation
@testable import Chotki
import ChotkiCore

/// Counts every request and refuses it, so a test can prove the app never asked.
private final class RefusingFetcher: HTTPFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requests: Int { lock.lock(); defer { lock.unlock() }; return count }
    func data(from url: URL) async throws -> Data {
        lock.lock(); count += 1; lock.unlock()
        throw HTTPError.transport("offline")
    }
}

/// The calendar that ships with the app, as the phone uses it: fictional practice in a temporary
/// database, and a network that refuses everything.
@Suite("The shipped calendar on the phone")
@MainActor
struct ShippedCalendarTests {

    private func model(_ fetcher: RefusingFetcher) throws -> Model {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-test-\(UUID().uuidString).sqlite").path
        return Model(store: try SQLiteStore(path: path), calendarClient: OrthocalClient(http: fetcher))
    }

    @Test("with no network at all, today and the days around it are there, and nothing is asked for")
    func airplane() async throws {
        let fetcher = RefusingFetcher()
        let model = try model(fetcher)
        try await Task.sleep(nanoseconds: 400_000_000)
        // This test is about the five shipped years; it says so rather than failing mysteriously after them.
        try #require(model.today <= CalendarDate(year: 2031, month: 12, day: 1)!)
        for offset in -3...20 {
            // The screens' own entry point, not the service behind it: iOS once read the store
            // directly, and a test of the service alone could not have noticed.
            let day = model.liturgicalDay(model.today.adding(days: offset))
            #expect(day != nil, "offset \(offset)")
            #expect(day?.readings.isEmpty == false)
        }
        #expect(model.liturgical.isOffline == false)
        #expect(fetcher.requests == 0, "the app asked for something the shipped calendar already has")
    }

    @Test("a reading carries paragraphs from the Bible's own marks")
    func paragraphs() async throws {
        let model = try model(RefusingFetcher())
        // Holy Thursday 2027 on the Old Calendar's civil date: a long Gospel with several paragraphs.
        let day = try #require(model.liturgicalDay(CalendarDate(year: 2027, month: 4, day: 29)!))
        let longest = try #require(day.readings.map(\.text).max { $0.count < $1.count })
        #expect(longest.contains("\n\n"))
        #expect(!longest.contains("\u{00B6}"))
    }
}
