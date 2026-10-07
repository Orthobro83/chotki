// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ChotkiLinuxBridge",
    dependencies: [.package(name: "ChotkiCore", path: "../../../core")],
    targets: [
        .executableTarget(
            name: "ChotkiLinuxBridge",
            dependencies: [.product(name: "ChotkiCore", package: "ChotkiCore")]
        )
    ]
)
