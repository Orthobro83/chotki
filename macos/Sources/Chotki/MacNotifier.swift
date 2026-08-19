import Foundation
import UserNotifications
import ChotkiCore

/// macOS implementation of the core `Notifier` protocol.
///
/// Core decides when a reminder is due; this only shows it. Requires a real
/// bundle — `UNUserNotificationCenter` is unavailable to a bare executable,
/// which is why the build script assembles a signed .app.
final class MacNotifier: NSObject, Notifier, @unchecked Sendable {

    private let center = UNUserNotificationCenter.current()
    private let categoryID = "chotki.rule"
    private var continuation: AsyncStream<NotificationActionEvent>.Continuation?
    let actionEvents: AsyncStream<NotificationActionEvent>

    // macOS supports notification actions; several Linux daemons do not, which
    // is why this is a protocol requirement rather than an assumption.
    let supportsActions = true

    override init() {
        var cont: AsyncStream<NotificationActionEvent>.Continuation!
        actionEvents = AsyncStream { cont = $0 }
        continuation = cont
        super.init()
        center.delegate = self
        registerCategory()
    }

    private func registerCategory() {
        let actions = [NotificationAction.markComplete, .snooze].map {
            UNNotificationAction(identifier: $0.id, title: $0.title, options: [])
        }
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func show(_ request: NotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        if !request.actions.isEmpty { content.categoryIdentifier = categoryID }

        try await center.add(
            UNNotificationRequest(identifier: request.id, content: content, trigger: nil)
        )
    }

    func cancel(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

extension MacNotifier: UNUserNotificationCenterDelegate {

    // A menu bar app is not "foreground" in the usual sense; without this the
    // banner is swallowed while the app is active.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        continuation?.yield(
            NotificationActionEvent(
                requestID: response.notification.request.identifier,
                actionID: response.actionIdentifier
            )
        )
    }
}
