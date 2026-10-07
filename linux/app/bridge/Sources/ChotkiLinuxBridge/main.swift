import ChotkiCore
import Foundation

// The Linux UI owns desktop behavior. This process owns the existing Swift
// decisions and record. The protocol is newline-framed JSON with an explicit
// version so a mismatched UI/helper pair fails visibly after an upgrade.
private let protocolVersion = 1

private enum LaunchMode {
    case review
    case normal

    init?(_ argument: String) {
        switch argument {
        case "--review": self = .review
        case "--normal": self = .normal
        default: return nil
        }
    }

    var isReview: Bool { self == .review }
}

private enum BridgeError: Error, CustomStringConvertible {
    case invalidRequest
    case incompatibleProtocol
    case unsupportedOperation(String)
    case reviewOnly

    var description: String {
        switch self {
        case .invalidRequest: "The request is incomplete or malformed."
        case .incompatibleProtocol: "The Linux interface and Swift helper use different protocol versions."
        case .unsupportedOperation(let name): "Unsupported operation: \(name)"
        case .reviewOnly: "This command is available only in the isolated review record."
        }
    }
}

private func dataDirectory(for mode: LaunchMode) -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    if mode.isReview {
        // A fixed review path prevents a test or screenshot from opening the
        // normal record even if XDG_DATA_HOME was set by the caller.
        return home.appendingPathComponent(".cache/chotki-linux-review", isDirectory: true)
    }
    let proposed = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] ?? ""
    let base = proposed.hasPrefix("/")
        ? URL(fileURLWithPath: proposed, isDirectory: true)
        : home.appendingPathComponent(".local/share", isDirectory: true)
    return base.appendingPathComponent("Chotki", isDirectory: true)
}

private func respond(_ value: [String: Any]) {
    guard let encoded = try? JSONSerialization.data(withJSONObject: value) else { return }
    FileHandle.standardOutput.write(encoded)
    FileHandle.standardOutput.write(Data([0x0A]))
}

private func reply(id: Int, fields: [String: Any]) {
    respond(["v": protocolVersion, "id": id, "ok": true].merging(fields) { _, new in new })
}

private func fail(id: Int, _ error: Error) {
    respond(["v": protocolVersion, "id": id, "ok": false, "error": String(describing: error)])
}

guard CommandLine.arguments.count == 2,
      let mode = LaunchMode(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("Usage: ChotkiLinuxBridge --review|--normal\n".utf8))
    exit(2)
}

do {
    let directory = dataDirectory(for: mode)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let store = try SQLiteStore(path: directory.appendingPathComponent("chotki.sqlite").path)

    if mode.isReview {
        if try store.loadSettings() == nil {
            var sample = AppSettings.default
            sample.displayName = "Anna"
            sample.hasCompletedFirstRun = true
            try store.saveSettings(sample)
        }
    }

    while let line = readLine() {
        let request = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
        let id = request?["id"] as? Int ?? 0
        do {
            guard let request,
                  request["v"] as? Int == protocolVersion,
                  let operation = request["op"] as? String else {
                throw request?["v"] as? Int == protocolVersion
                    ? BridgeError.invalidRequest : BridgeError.incompatibleProtocol
            }

            switch operation {
            case "hello":
                reply(id: id, fields: ["mode": mode.isReview ? "review" : "normal"])

            case "snapshot":
                let today = CalendarDate(Date(), in: .current)
                let settings = try store.loadSettings() ?? .default
                let psalm = Psalter.psalm(1)
                reply(id: id, fields: [
                    "today": today.iso,
                    "displayName": settings.displayName,
                    "hasCompletedFirstRun": settings.hasCompletedFirstRun,
                    "psalmOneVerses": psalm?.verses.count ?? 0
                ])

            case "setReviewName":
                guard mode.isReview else { throw BridgeError.reviewOnly }
                guard let name = request["name"] as? String, name.count <= 80 else {
                    throw BridgeError.invalidRequest
                }
                var settings = try store.loadSettings() ?? .default
                settings.displayName = name
                try store.saveSettings(settings)
                reply(id: id, fields: ["displayName": try store.loadSettings()?.displayName ?? ""])

            default:
                throw BridgeError.unsupportedOperation(operation)
            }
        } catch {
            fail(id: id, error)
        }
    }
} catch {
    fail(id: 0, error)
    exit(1)
}
