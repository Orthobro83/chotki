// swift-tools-version:6.0
import PackageDescription

// Portability rule: this package imports Foundation and SQLite ONLY.
// No AppKit, no SwiftUI, no UserNotifications, no SMAppService, no Apple-only API.
// CI builds and tests it on Linux so that rule fails loudly rather than rotting.
let package = Package(
    name: "ChotkiCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ChotkiCore", targets: ["ChotkiCore"])
    ],
    targets: [
        .target(name: "ChotkiCore"),
        .testTarget(name: "ChotkiCoreTests", dependencies: ["ChotkiCore"])
    ]
)
