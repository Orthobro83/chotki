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
        )
    ]
)
