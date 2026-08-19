import Foundation
import ChotkiCore

/// Persists `AppSettings` as JSON in user defaults.
///
/// The settings type itself lives in core, so what someone has chosen travels
/// with their data rather than being tied to one platform's preferences system.
struct SettingsStorage {
    private let key = "chotki.settings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Nothing to migrate. Tests keep settings in their in-memory store, so no
    /// preferences file is created at all.
    static func none() -> SettingsStorage {
        SettingsStorage(defaults: UserDefaults(suiteName: "chotki.migration.none")!)
    }

    /// Reads anything left over from when settings lived here, once, so an
    /// existing install does not lose its choices. Settings now live in the
    /// store: preferences were not persisting reliably, and would not have
    /// travelled with a backup or to another platform even if they had.
    func migratedSettings() -> AppSettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        defer { defaults.removeObject(forKey: key) }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
}

enum StoreLocation {
    /// ~/Library/Application Support/Chotki/chotki.sqlite
    static func databasePath() throws -> String {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("Chotki", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("chotki.sqlite").path
    }
}
