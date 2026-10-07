// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ChotkiLinuxSpikeBridge",
    dependencies: [.package(name: "ChotkiCore", path: "../../../core")],
    targets: [
        .executableTarget(
            name: "ChotkiLinuxSpikeBridge",
            dependencies: [.product(name: "ChotkiCore", package: "ChotkiCore")]
        )
    ]
)
