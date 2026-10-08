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
    case unknownRule

    var description: String {
        switch self {
        case .invalidRequest: "The request is incomplete or malformed."
        case .incompatibleProtocol: "The Linux interface and Swift helper use different protocol versions."
        case .unsupportedOperation(let name): "Unsupported operation: \(name)"
        case .reviewOnly: "This command is available only in the isolated review record."
        case .unknownRule: "That rule is not on the selected day."
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

private func homeSnapshot(store: SQLiteStore, on selectedDate: CalendarDate,
                          weekCenter: CalendarDate) throws -> [String: Any] {
    let settings = try store.loadSettings() ?? .default
    let rules = try store.rules(includeArchived: false)
    let activations = try store.activations(ruleID: nil)
    let occurrences = try store.occurrences(ruleID: nil, from: selectedDate, through: selectedDate)
    let liturgical = LiturgicalService(store: store, jurisdiction: settings.jurisdiction,
                                      networkPolicy: .never)
    let practice = Practice(rules: rules, activations: activations,
                            occurrences: occurrences, settings: settings, liturgical: liturgical)
    let entries: [[String: Any]] = practice.entries(on: selectedDate).map { entry in
        let summary = RuleLibrary.shared.templates.first { $0.title == entry.rule.title }?.summary
            ?? entry.rule.note ?? "A rule of your own."
        let time = entry.rule.timeOfDay.map { String(format: "%02d:%02d", $0.hour, $0.minute) }
        return [
            "id": entry.rule.id.uuidString,
            "title": entry.rule.title,
            "category": RuleCategory(rawValue: entry.rule.category ?? "")?.displayName ?? "Rule",
            "summary": summary,
            "time": time ?? "All Day",
            "kept": entry.isKept,
            "dispensed": entry.isDispensed,
            "dispensation": entry.dispensation ?? ""
        ]
    }
    let weekStart = weekCenter.adding(days: -3)
    let weekEnd = weekCenter.adding(days: 3)
    let weekOccurrences = try store.occurrences(ruleID: nil, from: weekStart, through: weekEnd)
    let weekPractice = Practice(rules: rules, activations: activations,
                                occurrences: weekOccurrences, settings: settings,
                                liturgical: liturgical)
    let week: [[String: Any]] = (-3...3).map { offset in
        let date = weekCenter.adding(days: offset)
        let day = liturgical.cachedDay(for: date)
        return ["date": date.iso, "day": date.day, "weekday": date.weekday.rawValue,
                "selected": date == selectedDate, "fast": day?.isFast ?? false,
                "feast": day?.isGreatFeast ?? false,
                "settled": weekPractice.isSettled(on: date)]
    }
    let saying = PatristicReadings.shared.reading(for: selectedDate)
    let liturgicalDay = liturgical.cachedDay(for: selectedDate)
    return [
        "selectedDate": selectedDate.iso,
        "displayName": settings.displayName,
        "hasCompletedFirstRun": settings.hasCompletedFirstRun,
        "psalmOneVerses": Psalter.psalm(1)?.verses.count ?? 0,
        "entries": entries,
        "week": week,
        "dayTitle": liturgicalDay?.title ?? "",
        "observedDate": liturgicalDay?.observedDate.iso ?? "",
        "showOldStyleDates": settings.showOldStyleDates,
        "sayingText": saying?.text ?? "",
        "sayingAuthor": saying?.author ?? "",
        "sayingSource": saying?.source ?? ""
    ]
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
        if try store.rules(includeArchived: false).isEmpty {
            let today = CalendarDate(Date(), in: .current)
            for title in ["Morning prayers", "The day's Gospel", "Evening prayers",
                          "The Jesus Prayer", "The life of the day's saint"] {
                guard let template = RuleLibrary.shared.templates.first(where: { $0.title == title }) else {
                    continue
                }
                let rule = template.makeRule(source: "the library")
                try store.save(rule)
                try store.save(Activation(ruleID: rule.id, from: today.adding(days: -40)))
                if title == "Morning prayers" {
                    try store.save(Occurrence(ruleID: rule.id, date: today, status: .completed))
                }
            }
        }
    }

    var selectedDate = CalendarDate(Date(), in: .current)
    var weekCenter = selectedDate

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
                var fields = try homeSnapshot(store: store, on: selectedDate,
                                              weekCenter: weekCenter)
                fields["today"] = CalendarDate(Date(), in: .current).iso
                reply(id: id, fields: fields)

            case "selectDate":
                guard let raw = request["date"] as? String,
                      let date = CalendarDate(iso: raw) else { throw BridgeError.invalidRequest }
                selectedDate = date
                weekCenter = date
                reply(id: id, fields: try homeSnapshot(store: store, on: selectedDate,
                                                       weekCenter: weekCenter))

            case "shiftWeek":
                guard let direction = request["direction"] as? Int,
                      direction == -1 || direction == 1 else { throw BridgeError.invalidRequest }
                weekCenter = weekCenter.adding(days: direction * 7)
                reply(id: id, fields: try homeSnapshot(store: store, on: selectedDate,
                                                       weekCenter: weekCenter))

            case "toggleKept":
                guard let raw = request["ruleID"] as? String,
                      let ruleID = UUID(uuidString: raw) else { throw BridgeError.invalidRequest }
                let rules = try store.rules(includeArchived: false)
                let activations = try store.activations(ruleID: nil)
                let occurrences = try store.occurrences(ruleID: nil, from: selectedDate, through: selectedDate)
                let settings = try store.loadSettings() ?? .default
                let liturgical = LiturgicalService(store: store, jurisdiction: settings.jurisdiction,
                                                  networkPolicy: .never)
                let practice = Practice(rules: rules, activations: activations,
                                        occurrences: occurrences, settings: settings,
                                        liturgical: liturgical)
                guard let entry = practice.entries(on: selectedDate).first(where: { $0.rule.id == ruleID }),
                      !entry.isDispensed else { throw BridgeError.unknownRule }
                if entry.isKept {
                    try store.removeOccurrence(ruleID: ruleID, date: selectedDate)
                } else {
                    try store.save(Occurrence(ruleID: ruleID, date: selectedDate, status: .completed))
                }
                reply(id: id, fields: try homeSnapshot(store: store, on: selectedDate,
                                                       weekCenter: weekCenter))

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
