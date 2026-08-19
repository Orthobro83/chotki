import Testing
import Foundation
@testable import ChotkiCore

private func t(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m)! }

@Suite("TimeOfDay")
struct TimeOfDayTests {

    @Test("rejects out-of-range values rather than trapping")
    func rejectsOutOfRange() {
        #expect(TimeOfDay(hour: 24, minute: 0) == nil)
        #expect(TimeOfDay(hour: -1, minute: 0) == nil)
        #expect(TimeOfDay(hour: 0, minute: 60) == nil)
        #expect(TimeOfDay(hour: 23, minute: 59) != nil)
        #expect(TimeOfDay(hour: 0, minute: 0) != nil)
    }

    @Test("orders by minutes since midnight")
    func ordering() {
        #expect(t(6, 29) < t(6, 30))
        #expect(t(6, 30) < t(21, 30))
        #expect(t(21, 30).minutesSinceMidnight == 21 * 60 + 30)
    }
}

@Suite("QuietHours")
struct QuietHoursTests {

    // The default window wraps midnight, which is the case a naive range check
    // gets wrong.
    @Test("wrapping window covers late evening")
    func wrappingCoversEvening() {
        let q = QuietHours.default
        #expect(q.wrapsMidnight)
        #expect(q.contains(t(21, 30)))
        #expect(q.contains(t(23, 59)))
    }

    @Test("wrapping window covers the small hours")
    func wrappingCoversSmallHours() {
        let q = QuietHours.default
        #expect(q.contains(t(0, 0)))
        #expect(q.contains(t(3, 0)))   // the 3am case this type exists to prevent
        #expect(q.contains(t(6, 29)))
    }

    @Test("wrapping window excludes the day, with an exclusive end")
    func wrappingExcludesDaytime() {
        let q = QuietHours.default
        #expect(!q.contains(t(6, 30)))   // end exclusive: a 06:30 rule still fires
        #expect(!q.contains(t(12, 0)))
        #expect(!q.contains(t(21, 29)))
    }

    @Test("non-wrapping window behaves as a plain range")
    func nonWrapping() {
        let q = QuietHours(start: t(9, 0), end: t(17, 0))
        #expect(!q.wrapsMidnight)
        #expect(q.contains(t(9, 0)))
        #expect(q.contains(t(16, 59)))
        #expect(!q.contains(t(17, 0)))
        #expect(!q.contains(t(8, 59)))
        #expect(!q.contains(t(23, 0)))
    }

    // Equal bounds mean "no quiet hours", not "silent all day".
    // Backwards, this would silence the app permanently.
    @Test("equal bounds disable the window entirely", arguments: 0..<24)
    func equalBoundsDisable(hour: Int) {
        let q = QuietHours(start: t(9, 0), end: t(9, 0))
        #expect(q.isDisabled)
        #expect(!q.contains(t(hour, 0)))
    }

    @Test("survives a Codable round trip")
    func codableRoundTrip() throws {
        let q = QuietHours.default
        let data = try JSONEncoder().encode(q)
        #expect(try JSONDecoder().decode(QuietHours.self, from: data) == q)
    }
}

@Suite("Notifier contract")
struct NotifierContractTests {

    // Guards the Tone constraint in design.md: no guilt language reaches a banner.
    @Test("built-in action copy carries no guilt language")
    func actionCopyIsNeutral() {
        let forbidden = ["overdue", "missed", "failed", "behind", "!"]
        for action in [NotificationAction.markComplete, .snooze] {
            let title = action.title.lowercased()
            for word in forbidden {
                #expect(!title.contains(word), "\(action.title) contains \(word)")
            }
        }
    }

    @Test("request identity is stable so every reminder can be cancelled together")
    func stableIdentity() {
        let r = NotificationRequest(
            id: "rule-7:2026-08-19",
            title: "Evening prayers",
            body: "Due at 21:30",
            actions: [.markComplete, .snooze]
        )
        #expect(r.id == "rule-7:2026-08-19")
        #expect(r.actions.count == 2)
    }
}
