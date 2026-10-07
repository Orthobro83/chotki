import Foundation

/// A JSON file shipped with the core bundle.
///
/// SPM's debug bundle lays a copied folder out flat, at the resource root.
/// An archived app nests that same folder one level deeper, under `Resources`.
/// `Bundle.url(forResource:)` does not search subdirectories, so a lookup that
/// knows only one layout either crashes the release app or comes back empty
/// in tests.
enum BundledFile {
    /// A file inside a named folder of the core bundle, found under either layout
    /// (`calendar/` at the root, or `Resources/calendar/` once archived).
    static func url(_ name: String, extension ext: String, subdirectory: String) -> URL? {
        if let flat = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return flat
        }
        return Bundle.module.url(
            forResource: name, withExtension: ext, subdirectory: "Resources/\(subdirectory)"
        )
    }

    static func url(_ name: String, extension ext: String) -> URL? {
        if let flat = Bundle.module.url(forResource: name, withExtension: ext) {
            return flat
        }
        return Bundle.module.url(
            forResource: name, withExtension: ext, subdirectory: "Resources"
        )
    }
}
