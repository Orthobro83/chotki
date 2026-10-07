import ChotkiCore
import Foundation

// Disposable Phase 0 protocol: one JSON request and response per line. The
// database path is fixed under this VM user's cache, away from any live record.
let directory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".cache/chotki-phase0", isDirectory: true)

func send(_ object: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
}

do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = try SQLiteStore(path: directory.appendingPathComponent("record.sqlite").path)

    while let line = readLine() {
        let request = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
        let id = request?["id"] as? Int ?? 0
        do {
            guard let operation = request?["op"] as? String else {
                throw SpikeError.invalidRequest
            }
            switch operation {
            case "snapshot":
                guard let today = CalendarDate(iso: "2026-10-07"),
                      let psalm = Psalter.psalm(1) else { throw SpikeError.missingCoreData }
                let saved = try store.loadSettings()?.displayName ?? "(nothing saved)"
                send([
                    "id": id, "ok": true,
                    "nextDay": today.adding(days: 1).iso,
                    "resource": "Psalm 1: \(psalm.verses.count) bundled verses",
                    "saved": saved
                ])
            case "save":
                guard let value = request?["value"] as? String, value.count <= 80 else {
                    throw SpikeError.invalidRequest
                }
                var settings = try store.loadSettings() ?? .default
                settings.displayName = value
                try store.saveSettings(settings)
                send(["id": id, "ok": true, "saved": try store.loadSettings()?.displayName ?? ""])
            default:
                throw SpikeError.unknownOperation(operation)
            }
        } catch {
            send(["id": id, "ok": false, "error": String(describing: error)])
        }
    }
} catch {
    send(["id": 0, "ok": false, "error": "Startup: \(error)"])
    exit(1)
}

enum SpikeError: Error {
    case invalidRequest
    case missingCoreData
    case unknownOperation(String)
}
