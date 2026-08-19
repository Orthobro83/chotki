import Foundation
import ChotkiCore

/// Turns the core scheduler's plan into notifications that actually arrive.
///
/// The app is tray-resident, so scheduling happens in process rather than being
/// handed to the OS: core decides *when*, this fires at that moment, and the
/// notifier only *shows*. That is what makes the same logic portable — Windows
/// and Linux will reuse the scheduler untouched and replace only the notifier.
@MainActor
final class ReminderDriver {

    private let notifier: any Notifier
    private let plan: () -> [PlannedNotification]
    private var timer: Timer?

    /// Reminders already delivered, so a tick never repeats one.
    private var fired: Set<String> = []
    /// Occurrence keys held back, and until when.
    private var snoozedUntil: [String: Date] = [:]
    private var lastDay: CalendarDate?

    init(notifier: any Notifier, plan: @escaping () -> [PlannedNotification]) {
        self.notifier = notifier
        self.plan = plan
    }

    func start() {
        timer?.invalidate()
        // Half a minute is fine: reminders are minute-grained, and a resident
        // menu bar app should not be waking the CPU more often than it needs.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called when rules change, so a newly completed rule stops reminding at once.
    func refresh() {
        tick()
    }

    func snooze(ruleID: UUID, date: CalendarDate, by interval: TimeInterval) {
        let key = PlannedNotification.occurrenceKey(ruleID: ruleID, date: date)
        snoozedUntil[key] = Date().addingTimeInterval(interval)
    }

    private func tick() {
        let now = Date()
        let today = CalendarDate(now, in: .current)

        // A new day starts with a clean slate, and yesterday's silences lapse.
        if lastDay != today {
            fired.removeAll()
            snoozedUntil.removeAll()
            lastDay = today
        }

        let planned = plan()
        let live = Set(planned.map(\.id))

        // Anything no longer in the plan — the rule was kept, paused, silenced
        // or deleted — must be withdrawn rather than left pending.
        let stale = fired.subtracting(live)
        if !stale.isEmpty {
            let ids = Array(stale)
            Task { await notifier.cancel(ids: ids) }
            fired.subtract(stale)
        }

        for notification in planned {
            guard !fired.contains(notification.id) else { continue }
            guard notification.fireAt <= now else { continue }

            let key = PlannedNotification.occurrenceKey(
                ruleID: notification.ruleID, date: notification.date
            )
            if let until = snoozedUntil[key], until > now { continue }

            fired.insert(notification.id)
            let request = notification.request
            Task { try? await notifier.show(request) }
        }
    }
}
