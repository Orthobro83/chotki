// swift-tools-version:6.0
import PackageDescription

// The only Apple-specific code in the project. Everything portable lives in ../core.
let package = Package(
    name: "Chotki",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(name: "ChotkiCore", path: "../core")
    ],
    targets: [
        .executableTarget(
            name: "Chotki",
            dependencies: [.product(name: "ChotkiCore", package: "ChotkiCore")]
        ),
        // The interface layer holds real behaviour — what is due today, what
        // taking a rule on does — and that behaviour needs testing as much as
        // core does. Two of the first bugs found by hand were here, not in core.
        .testTarget(name: "ChotkiTests", dependencies: ["Chotki"])
    ]
)
