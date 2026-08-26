import Foundation
import UserNotifications
import ChotkiCore

/// Reminders on iOS, which are a different shape from Android's.
///
/// There, a reminder is an alarm that wakes the app so it can post a
/// notification, and the alarms had to be written down because AlarmManager
/// will not say what it is holding. All five reminder bugs lived in that gap.
///
/// Here the notification *is* the schedule. It is handed to the system with an
/// identifier and a time, the system delivers it whatever the app is doing, and
/// the same identifier takes it back. So the whole problem reduces to keeping
/// one set in step with another, which is what `sync` does — and it is exact by
/// construction rather than by bookkeeping.
struct Reminders: Sendable {

    /// Reached for rather than held. `UNUserNotificationCenter` is not Sendable
    /// and does not need to be carried: `.current()` is the same object from
    /// wherever it is asked for.
    private var centre: UNUserNotificationCenter { .current() }

    /// Asked once, plainly, and not insisted on. Nothing arrives without it and
    /// nothing errors, so the alternative to asking is reminders that silently
    /// never come.
    func requestAuthorization() async -> Bool {
        (try? await centre.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAuthorized() async -> Bool {
        await centre.notificationSettings().authorizationStatus == .authorized
    }

    /// Makes what is scheduled equal `planned`, and nothing else.
    ///
    /// The removal half is the half Android never had. `plan` correctly stops
    /// returning a rule once the day is settled, and on Android nothing acted
    /// on that — so a rule kept at 06:25 went on buzzing at 06:30. Here what is
    /// no longer wanted is taken back, pending and already-delivered alike.
    func sync(to planned: [PlannedNotification], now: Date = Date()) async {
        let pending = await centre.pendingNotificationRequests().map(\.identifier)
        let delivered = await centre.deliveredNotifications().map(\.request.identifier)

        let work = Self.reconcile(
            planned: planned, pending: pending, delivered: delivered, now: now
        )

        if !work.removePending.isEmpty {
            centre.removePendingNotificationRequests(withIdentifiers: work.removePending)
        }
        if !work.removeDelivered.isEmpty {
            centre.removeDeliveredNotifications(withIdentifiers: work.removeDelivered)
        }
        for notification in work.add {
            try? await centre.add(request(for: notification))
        }
    }

    /// What syncing would do, as arithmetic.
    ///
    /// Separated from the system on purpose. A test that drives the real
    /// notification centre needs authorisation and a dialogue, so the temptation
    /// is to test the app's own note of what it did instead — and the first
    /// Android version of exactly this passed with the fix removed, because it
    /// asserted against its own bookkeeping. This is the part with the mistakes
    /// in it, so this is the part that gets tested.
    struct Work: Equatable {
        var add: [PlannedNotification] = []
        var removePending: [String] = []
        var removeDelivered: [String] = []
    }

    static func reconcile(
        planned: [PlannedNotification],
        pending: [String],
        delivered: [String],
        now: Date
    ) -> Work {
        // Anything already past is not scheduled: handing the system a moment
        // that has gone delivers it at once, which is how a reboot at lunchtime
        // would deliver the whole morning.
        let wanted = Dictionary(
            planned.filter { $0.fireAt > now }.map { ($0.request.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let pendingSet = Set(pending)

        return Work(
            add: wanted.filter { !pendingSet.contains($0.key) }
                .values.sorted { $0.fireAt < $1.fireAt },
            removePending: pendingSet.subtracting(wanted.keys).sorted(),
            // A notification already on the lock screen for a rule since kept
            // has to come down too. Core has always described this; Android
            // never called it.
            removeDelivered: delivered.filter { wanted[$0] == nil && isOurs($0) }.sorted()
        )
    }

    /// Everything this app scheduled looks like `<uuid>:<date>:<lead>`, so a
    /// notification from anywhere else is left alone.
    static func isOurs(_ id: String) -> Bool {
        id.split(separator: ":").count >= 2 && UUID(uuidString: String(id.split(separator: ":")[0])) != nil
    }

    private func request(for planned: PlannedNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = planned.request.title
        content.body = planned.request.body
        content.sound = .default

        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: planned.fireAt
        )
        return UNNotificationRequest(
            identifier: planned.request.id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
    }

    /// What is actually scheduled, for the diagnostics and for tests. Asked of
    /// the system rather than of a note the app keeps about itself — a test
    /// against its own bookkeeping passes whether or not anything happened,
    /// which is how the first Android version of this passed with the fix
    /// removed.
    func scheduled() async -> [String] {
        await centre.pendingNotificationRequests().map(\.identifier).sorted()
    }
}
