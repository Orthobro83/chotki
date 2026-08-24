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
    /// Show a Dock icon and a full window as well as the menu bar item.
    /// The menu bar item is always present; this only adds the rest.
    public var showInDock: Bool
    /// The chime when a knot of the prayer rope is complete.
    public var chimeOnCompletion: Bool
    /// A soft click as each knot passes, so a press is confirmed with your eyes
    /// closed.
    public var tickEachKnot: Bool
    /// Cleared once the first rules have been taken on.
    public var hasCompletedFirstRun: Bool
    /// Whether times read as 06:30 or as 6:30 AM.
    public var clockStyle: ClockStyle

    public init(
        jurisdiction: Jurisdiction = .default,
        observances: ObservanceSettings = .default,
        reminders: ReminderPolicy = .default,
        showOldStyleDates: Bool = false,
        showConsistencyNumber: Bool = true,
        launchAtLogin: Bool = false,
        showInDock: Bool = true,
        chimeOnCompletion: Bool = true,
        tickEachKnot: Bool = true,
        hasCompletedFirstRun: Bool = false,
        clockStyle: ClockStyle = .twentyFourHour
    ) {
        self.jurisdiction = jurisdiction
        self.observances = observances
        self.reminders = reminders
        self.showOldStyleDates = showOldStyleDates
        self.showConsistencyNumber = showConsistencyNumber
        self.launchAtLogin = launchAtLogin
        self.showInDock = showInDock
        self.chimeOnCompletion = chimeOnCompletion
        self.tickEachKnot = tickEachKnot
        self.hasCompletedFirstRun = hasCompletedFirstRun
        self.clockStyle = clockStyle
    }

    /// Every key optional, every absence a default.
    ///
    /// Synthesised decoding throws when a key is missing, so adding a setting
    /// would make every record written before it unreadable — and this app has
    /// already lost a person's settings once, which is how fasting rules
    /// silently stopped appearing. A record that predates a setting is not
    /// corrupt; it simply has not got one yet.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        func value<T: Decodable>(_ key: CodingKeys, _ default: T) throws -> T {
            try container.decodeIfPresent(T.self, forKey: key) ?? `default`
        }
        jurisdiction = try value(.jurisdiction, fallback.jurisdiction)
        observances = try value(.observances, fallback.observances)
        reminders = try value(.reminders, fallback.reminders)
        showOldStyleDates = try value(.showOldStyleDates, fallback.showOldStyleDates)
        showConsistencyNumber = try value(.showConsistencyNumber, fallback.showConsistencyNumber)
        launchAtLogin = try value(.launchAtLogin, fallback.launchAtLogin)
        showInDock = try value(.showInDock, fallback.showInDock)
        chimeOnCompletion = try value(.chimeOnCompletion, fallback.chimeOnCompletion)
        tickEachKnot = try value(.tickEachKnot, fallback.tickEachKnot)
        hasCompletedFirstRun = try value(.hasCompletedFirstRun, fallback.hasCompletedFirstRun)
        clockStyle = try value(.clockStyle, fallback.clockStyle)
    }

    public static let `default` = AppSettings()
}
