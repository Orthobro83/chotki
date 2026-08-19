import Foundation

/// Everything the user can change, in one Codable value.
///
/// Lives in core so the settings a person has chosen move with their data
/// rather than being tied to one platform's preferences system.
public struct AppSettings: Sendable, Hashable, Codable {
    public var jurisdiction: Jurisdiction
    public var observances: ObservanceSettings
    public var reminders: ReminderPolicy
    /// Show the Julian date alongside the civil one — useful on the Old
    /// Calendar, where a parish bulletin and a wall calendar disagree.
    public var showOldStyleDates: Bool
    /// The consistency figure can be hidden entirely, leaving only the prose.
    public var showConsistencyNumber: Bool
    public var launchAtLogin: Bool
    /// Cleared once the first rules have been taken on.
    public var hasCompletedFirstRun: Bool

    public init(
        jurisdiction: Jurisdiction = .default,
        observances: ObservanceSettings = .default,
        reminders: ReminderPolicy = .default,
        showOldStyleDates: Bool = false,
        showConsistencyNumber: Bool = true,
        launchAtLogin: Bool = false,
        hasCompletedFirstRun: Bool = false
    ) {
        self.jurisdiction = jurisdiction
        self.observances = observances
        self.reminders = reminders
        self.showOldStyleDates = showOldStyleDates
        self.showConsistencyNumber = showConsistencyNumber
        self.launchAtLogin = launchAtLogin
        self.hasCompletedFirstRun = hasCompletedFirstRun
    }

    public static let `default` = AppSettings()
}
