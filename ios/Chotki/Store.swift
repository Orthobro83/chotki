import Foundation
import ChotkiCore

/// Where the record lives on iOS.
///
/// Deliberately not in `core`, for the same reason the macOS one is not: a path
/// is platform glue rather than a decision, and `CLAUDE.md` says so. The code
/// reads the same because Foundation hides the difference — on iOS this is
/// inside the app's own sandbox, which no other app can reach.
enum StoreLocation {

    /// Application Support/Chotki/chotki.sqlite, inside the sandbox.
    static func databaseURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("Chotki", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("chotki.sqlite")
    }

    /// Rolling automatic backups, beside the database.
    static func backupsDirectory() throws -> URL {
        let base = try databaseURL().deletingLastPathComponent()
            .appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}

/// Opening the store, and saying so plainly when it will not open.
///
/// A store that fails to open is not a condition to recover from — there is no
/// app without it — but it is one to report honestly rather than crash on, so
/// that a person sees a sentence instead of a disappearing icon.
enum StoreOpening {
    case opened(SQLiteStore)
    case failed(String)

    static func attempt() -> StoreOpening {
        do {
            let url = try StoreLocation.databaseURL()
            // The schema ladder runs here, on the way in. Every step is
            // forward-only and stamps its version; a database already at the
            // latest is untouched.
            return .opened(try SQLiteStore(path: url.path))
        } catch {
            return .failed("Chotki could not open its record. \(error.localizedDescription)")
        }
    }
}
