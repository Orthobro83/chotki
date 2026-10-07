import Testing
import Foundation
@testable import ChotkiCore

/// The bundled calendar and the Bible it resolves from are shipped to Android byte for byte.
///
/// Nothing is retyped or re-encoded: the Kotlin side reads the same files. CI fails if the
/// copies under `android/core/src/main/resources/calendar` differ from the ones in this package.
///
/// To refresh after regenerating the bundle: `CHOTKI_WRITE_CONTENT=1 swift test --package-path core --filter CalendarExport`
@Suite("Calendar export")
struct CalendarExportTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private static let source = root.appendingPathComponent("core/Sources/ChotkiCore/Resources/calendar")
    private static let copy = root.appendingPathComponent("android/core/src/main/resources/calendar")

    @Test("the Android copy of every calendar file is identical to this package's")
    func identical() throws {
        let fm = FileManager.default
        let names = try fm.contentsOfDirectory(atPath: Self.source.path).filter { $0.hasSuffix(".json") }.sorted()
        #expect(names.count == 16)
        if ProcessInfo.processInfo.environment["CHOTKI_WRITE_CONTENT"] == "1" {
            try fm.createDirectory(at: Self.copy, withIntermediateDirectories: true)
            for name in names {
                let target = Self.copy.appendingPathComponent(name)
                try? fm.removeItem(at: target)
                try fm.copyItem(at: Self.source.appendingPathComponent(name), to: target)
            }
        }
        for name in names {
            let ours = try Data(contentsOf: Self.source.appendingPathComponent(name))
            let theirs = try? Data(contentsOf: Self.copy.appendingPathComponent(name))
            #expect(ours == theirs, "\(name) has drifted from the Android copy")
        }
        let extra = try fm.contentsOfDirectory(atPath: Self.copy.path).filter { $0.hasSuffix(".json") && !names.contains($0) }
        #expect(extra.isEmpty, "Android has files the Swift core does not: \(extra)")
    }
}
