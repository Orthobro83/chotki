import Foundation

/// A JSON file shipped with the core bundle.
///
/// SPM's debug bundle lays a copied folder out flat, at the resource root.
/// An archived app nests that same folder one level deeper, under `Resources`.
/// `Bundle.url(forResource:)` does not search subdirectories, so a lookup that
/// knows only one layout either crashes the release app or comes back empty
/// in tests.
enum BundledFile {
    static func url(_ name: String, extension ext: String) -> URL? {
        if let flat = Bundle.module.url(forResource: name, withExtension: ext) {
            return flat
        }
        return Bundle.module.url(
            forResource: name, withExtension: ext, subdirectory: "Resources"
        )
    }
}
