import Foundation

/// Decides, on each tick, what should be shown and what should be taken back.
///
/// Separated from the timer that drives it and the notifier that obeys it, so
/// the parts that are easy to get wrong — not repeating a reminder, not firing
/// a burst of stale ones, crossing midnight, withdrawing something that is no
/// longer due — are plain arithmetic that any platform can reuse and any test
/// can drive with an injected clock.
public struct ReminderTicker: Sendable {

    public struct Decision: Sendable, Equatable {
        public var show: [PlannedNotification]
        public var withdraw: [String]

        public var isEmpty: Bool { show.isEmpty && withdraw.isEmpty }
    }

    /// How late a reminder may be and still be worth showing. Without this,
    /// launching in the afternoon — or a rule becoming due mid-day, which is
    /// what happens when an observance is turned on — fires every earlier
    /// reminder for that day at once.
    public var staleAfter: TimeInterval

    /// Already delivered, so a tick never repeats one.
    private var fired: Set<String> = []
    /// Occurrence keys held back, and until when.
    private var snoozedUntil: [String: Date] = [:]
    private var lastDay: CalendarDate?

    public init(staleAfter: TimeInterval = 15 * 60) {
        self.staleAfter = staleAfter
    }

    public mutating func snooze(ruleID: UUID, date: CalendarDate, until: Date) {
        snoozedUntil[PlannedNotification.occurrenceKey(ruleID: ruleID, date: date)] = until
    }

    public mutating func tick(
        planned: [PlannedNotification], now: Date, timeZone: TimeZone = .current
    ) -> Decision {
        let today = CalendarDate(now, in: timeZone)

        // A new day starts clean, and yesterday's silences lapse. This runs once
        // a day, which in practice means it never runs while anyone is watching.
        //
        // Note the `if let`: the very first tick must not count as a change of
        // day, or anything set before it — a snooze, say — is wiped before it
        // has any effect.
        if let lastDay, lastDay != today {
            fired.removeAll()
            snoozedUntil.removeAll()
        }
        lastDay = today

        var decision = Decision(show: [], withdraw: [])

        // Anything no longer planned — kept, paused, silenced or deleted — is
        // taken back rather than left standing.
        let live = Set(planned.map(\.id))
        let stale = fired.subtracting(live)
        if !stale.isEmpty {
            decision.withdraw = Array(stale).sorted()
            fired.subtract(stale)
        }

        for notification in planned {
            guard !fired.contains(notification.id) else { continue }
            guard notification.fireAt <= now else { continue }

            guard now.timeIntervalSince(notification.fireAt) <= staleAfter else {
                // Its moment has passed. Mark it handled and stay quiet.
                fired.insert(notification.id)
                continue
            }

            let key = PlannedNotification.occurrenceKey(
                ruleID: notification.ruleID, date: notification.date
            )
            if let until = snoozedUntil[key], until > now { continue }

            fired.insert(notification.id)
            decision.show.append(notification)
        }

        return decision
    }
}
