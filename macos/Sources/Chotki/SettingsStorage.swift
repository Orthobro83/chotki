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

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else { return .default }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            // A settings file we cannot read must not lose someone's rules.
            // Fall back to defaults and carry on.
            return .default
        }
    }

    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
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
