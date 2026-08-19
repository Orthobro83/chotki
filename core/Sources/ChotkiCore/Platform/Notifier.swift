import Foundation

/// One button on a notification.
public struct NotificationAction: Sendable, Hashable, Codable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    /// Copy is deliberately neutral. See the Tone section in design.md:
    /// a reminder says what is due, never how overdue it is.
    public static let markComplete = NotificationAction(id: "complete", title: "Mark complete")
    public static let snooze = NotificationAction(id: "snooze", title: "Snooze an hour")
}

public struct NotificationRequest: Sendable, Hashable, Codable {
    /// Stable, so the scheduler can cancel every pending reminder for one occurrence.
    public let id: String
    public let title: String
    public let body: String
    public let actions: [NotificationAction]

    public init(id: String, title: String, body: String, actions: [NotificationAction] = []) {
        self.id = id
        self.title = title
        self.body = body
        self.actions = actions
    }
}

public struct NotificationActionEvent: Sendable, Hashable {
    public let requestID: String
    public let actionID: String

    public init(requestID: String, actionID: String) {
        self.requestID = requestID
        self.actionID = actionID
    }
}

/// Implemented per platform. Core decides *when*; this only *shows*.
///
/// `supportsActions` is not decoration — several Linux notification daemons
/// ignore action buttons entirely, and the reminder must degrade to a plain
/// notification rather than being lost.
public protocol Notifier: Sendable {
    var supportsActions: Bool { get }
    func requestAuthorization() async throws -> Bool
    func show(_ request: NotificationRequest) async throws
    func cancel(ids: [String]) async
    var actionEvents: AsyncStream<NotificationActionEvent> { get }
}
