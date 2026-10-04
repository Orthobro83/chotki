// swift-tools-version:6.0
import PackageDescription

// shared-core is a generated copy of ../core, prepared on the Mac before sync.
// All guest package manifests and sources then live on C:\workspace-build.
let package = Package(
    name: "ChotkiWindows",
    dependencies: [.package(name: "ChotkiCore", path: "shared-core")],
    targets: [
        .target(name: "WindowsUI", publicHeadersPath: "include",
                linkerSettings: [.linkedLibrary("user32"), .linkedLibrary("gdi32"), .linkedLibrary("comdlg32"), .linkedLibrary("gdiplus"), .linkedLibrary("dwmapi")]),
        .executableTarget(
            name: "ChotkiWindows",
            dependencies: [.product(name: "ChotkiCore", package: "ChotkiCore"), "WindowsUI"],
            resources: [.copy("Assets")]
        )
    ],
    cxxLanguageStandard: .cxx17
)
