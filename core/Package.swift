// swift-tools-version:6.0
import PackageDescription

// Portability rule: this package imports Foundation and SQLite ONLY.
// No AppKit, no SwiftUI, no UserNotifications, no SMAppService, no Apple-only API.
// CI builds and tests it on Linux so that rule fails loudly rather than rotting.
//
// SQLite is reached through the system library rather than a Swift wrapper such
// as GRDB: sqlite3 is present on macOS, Linux and Windows alike, and adding a
// dependency whose own portability is weaker than ours would undermine the point.
let package = Package(
    name: "ChotkiCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ChotkiCore", targets: ["ChotkiCore"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
        .target(
            name: "ChotkiCore",
            dependencies: ["CSQLite"],
            // The Psalter is 150 psalms of Brenton, which is a resource rather
            // than something to author in a Swift literal. The same file is
            // shipped byte for byte to Android; see core/Tools/.
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "ChotkiCoreTests",
            dependencies: ["ChotkiCore"],
            // Recorded orthocal responses. The liturgical suite runs entirely
            // against these, so CI never makes a network request and the tests
            // stay deterministic.
            resources: [.copy("Fixtures")]
        )
    ]
)
