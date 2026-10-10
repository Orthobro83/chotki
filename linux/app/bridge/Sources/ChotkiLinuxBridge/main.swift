import ChotkiCore
import Foundation

// The Linux UI owns desktop behavior. This process owns the existing Swift
// decisions and record. Requests and replies are the types in Protocol.swift.

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

enum BridgeError: Error, CustomStringConvertible {
    case invalidRequest
    case incompatibleProtocol
    case unsupportedOperation(String)
    case reviewOnly
    case unknownRule
    case notAsked
    case invalidReviewDirectory
    case unknownPrayer

    var description: String {
        switch self {
        case .invalidRequest: "The request is incomplete or malformed."
        case .incompatibleProtocol: "The Linux interface and Swift helper use different protocol versions."
        case .unsupportedOperation(let name): "Unsupported operation: \(name)"
        case .reviewOnly: "This command is available only in the isolated review record."
        case .unknownRule: "That rule is not on the selected day."
        case .notAsked: "Nothing was asked on this day."
        case .invalidReviewDirectory: "The review record directory must be an absolute path."
        case .unknownPrayer: "That prayer is not in the book."
        }
    }
}

private func dataDirectory(for mode: LaunchMode) throws -> URL {
    let home = FileManager.default.homeDirectoryForCurrentUser
    if mode.isReview {
        // Tests set this so they do not write the human review record at the
        // fixed cache path. An unset variable keeps that path.
        let override = ProcessInfo.processInfo.environment["CHOTKI_LINUX_REVIEW_DIR"] ?? ""
        if !override.isEmpty {
            guard override.hasPrefix("/") else { throw BridgeError.invalidReviewDirectory }
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return home.appendingPathComponent(".cache/chotki-linux-review", isDirectory: true)
    }
    let proposed = ProcessInfo.processInfo.environment["XDG_DATA_HOME"] ?? ""
    let base = proposed.hasPrefix("/")
        ? URL(fileURLWithPath: proposed, isDirectory: true)
        : home.appendingPathComponent(".local/share", isDirectory: true)
    return base.appendingPathComponent("Chotki", isDirectory: true)
}

func respond<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let encoded = try? encoder.encode(value) else { return }
    var line = encoded
    line.append(0x0A)
    FileHandle.standardOutput.write(line)
}

private func fail(id: Int, _ error: Error) {
    respond(BridgeFailure(v: bridgeProtocolVersion, id: id, error: String(describing: error)))
}

func homeSnapshot(store: SQLiteStore, on selectedDate: CalendarDate,
                          weekCenter: CalendarDate) throws -> HomeSnapshot {
    let settings = try store.loadSettings() ?? .default
    let rules = try store.rules(includeArchived: false)
    let activations = try store.activations(ruleID: nil)
    let occurrences = try store.occurrences(ruleID: nil, from: selectedDate, through: selectedDate)
    let liturgical = LiturgicalService(store: store, jurisdiction: settings.jurisdiction,
                                      networkPolicy: .never)
    let practice = Practice(rules: rules, activations: activations,
                            occurrences: occurrences, settings: settings, liturgical: liturgical)
    let entries: [EntryPayload] = practice.entries(on: selectedDate).map { entry in
        let summary = RuleLibrary.shared.templates.first { $0.title == entry.rule.title }?.summary
            ?? entry.rule.note ?? "A rule of your own."
        let time = entry.rule.timeOfDay.map { String(format: "%02d:%02d", $0.hour, $0.minute) }
        return EntryPayload(
            id: entry.rule.id.uuidString, title: entry.rule.title,
            category: RuleCategory(rawValue: entry.rule.category ?? "")?.displayName ?? "Rule",
            summary: summary, time: time ?? "All Day", kept: entry.isKept,
            dispensed: entry.isDispensed, dispensation: entry.dispensation ?? ""
        )
    }
    let weekStart = weekCenter.adding(days: -3)
    let weekEnd = weekCenter.adding(days: 3)
    let weekOccurrences = try store.occurrences(ruleID: nil, from: weekStart, through: weekEnd)
    let weekPractice = Practice(rules: rules, activations: activations,
                                occurrences: weekOccurrences, settings: settings,
                                liturgical: liturgical)
    let week: [WeekDayPayload] = (-3...3).map { offset in
        let date = weekCenter.adding(days: offset)
        let day = liturgical.cachedDay(for: date)
        return WeekDayPayload(
            date: date.iso, day: date.day, weekday: date.weekday.rawValue,
            selected: date == selectedDate, fast: day?.isFast ?? false,
            feast: day?.isGreatFeast ?? false, settled: weekPractice.isSettled(on: date)
        )
    }
    let saying = PatristicReadings.shared.reading(for: selectedDate)
    let liturgicalDay = liturgical.cachedDay(for: selectedDate)
    return HomeSnapshot(
        selectedDate: selectedDate.iso, displayName: settings.displayName,
        hasCompletedFirstRun: settings.hasCompletedFirstRun,
        psalmOneVerses: Psalter.psalm(1)?.verses.count ?? 0, entries: entries, week: week,
        dayTitle: liturgicalDay?.title ?? "", observedDate: liturgicalDay?.observedDate.iso ?? "",
        showOldStyleDates: settings.showOldStyleDates, sayingText: saying?.text ?? "",
        sayingAuthor: saying?.author ?? "", sayingSource: saying?.source ?? ""
    )
}

private func reply(id: Int, snapshot: HomeSnapshot) throws {
    let today = CalendarDate(Date(), in: .current).iso
    respond(snapshot.success(id: id, today: today))
}

guard CommandLine.arguments.count == 2,
      let mode = LaunchMode(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("Usage: ChotkiLinuxBridge --review|--normal\n".utf8))
    exit(2)
}

do {
    let directory = try dataDirectory(for: mode)
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
            for title in ["Morning prayers", "The day's Gospel", "The day's Epistle",
                          "Evening prayers", "The Jesus Prayer", "The life of the day's saint",
                          "A kathisma of the Psalter", "The Wednesday and Friday fast"] {
                guard let template = RuleLibrary.shared.templates.first(where: { $0.title == title }) else {
                    continue
                }
                let rule = template.makeRule(source: "the library")
                try store.save(rule)
                try store.save(Activation(ruleID: rule.id, from: today.adding(days: -40)))
                if title == "Morning prayers" {
                    try store.save(Occurrence(
                        ruleID: rule.id, date: today, status: .completed, completedAt: Date()
                    ))
                }
            }
        }
    }

    var selectedDate = CalendarDate(Date(), in: .current)
    var weekCenter = selectedDate
    // The rope count lives for this process, as it does on the Mac. Leaving the
    // page and coming back reads it again. A new process starts at the beginning.
    var prayers = PrayerSession()
    var reading = ReadingSession()
    var psalter = PsalterSession()

    while let line = readLine() {
        let decoded = try? JSONDecoder().decode(BridgeRequest.self, from: Data(line.utf8))
        let id = decoded?.id ?? 0
        do {
            guard let request = decoded else { throw BridgeError.invalidRequest }
            guard request.v == bridgeProtocolVersion else { throw BridgeError.incompatibleProtocol }

            switch request.op {
            case "hello":
                respond(BridgeSuccess(v: bridgeProtocolVersion, id: id,
                                      mode: mode.isReview ? "review" : "normal"))

            case "snapshot":
                try reply(id: id, snapshot: homeSnapshot(store: store, on: selectedDate,
                                                         weekCenter: weekCenter))

            case "selectDate":
                guard let raw = request.date, let date = CalendarDate(iso: raw) else {
                    throw BridgeError.invalidRequest
                }
                selectedDate = date
                weekCenter = date
                reading.applyFocus()
                psalter.clear()
                try reply(id: id, snapshot: homeSnapshot(store: store, on: selectedDate,
                                                         weekCenter: weekCenter))

            case "shiftWeek":
                guard let direction = request.direction, direction == -1 || direction == 1 else {
                    throw BridgeError.invalidRequest
                }
                weekCenter = weekCenter.adding(days: direction * 7)
                try reply(id: id, snapshot: homeSnapshot(store: store, on: selectedDate,
                                                         weekCenter: weekCenter))

            case "toggleKept":
                guard let raw = request.ruleID, let ruleID = UUID(uuidString: raw) else {
                    throw BridgeError.invalidRequest
                }
                let rules = try store.rules(includeArchived: false)
                let activations = try store.activations(ruleID: nil)
                let occurrences = try store.occurrences(ruleID: nil, from: selectedDate, through: selectedDate)
                let settings = try store.loadSettings() ?? .default
                let liturgical = LiturgicalService(store: store, jurisdiction: settings.jurisdiction,
                                                  networkPolicy: .never)
                let practice = Practice(rules: rules, activations: activations,
                                        occurrences: occurrences, settings: settings,
                                        liturgical: liturgical)
                guard let entry = practice.entries(on: selectedDate).first(where: { $0.rule.id == ruleID }) else {
                    throw BridgeError.unknownRule
                }
                if entry.isDispensed { throw BridgeError.notAsked }
                if entry.isKept {
                    try store.removeOccurrence(ruleID: ruleID, date: selectedDate)
                } else {
                    try store.save(Occurrence(
                        ruleID: ruleID, date: selectedDate, status: .completed, completedAt: Date()
                    ))
                }
                try reply(id: id, snapshot: homeSnapshot(store: store, on: selectedDate,
                                                         weekCenter: weekCenter))

            case "setReviewName":
                guard mode.isReview else { throw BridgeError.reviewOnly }
                guard let name = request.name, name.count <= 80 else { throw BridgeError.invalidRequest }
                var settings = try store.loadSettings() ?? .default
                settings.displayName = name
                try store.saveSettings(settings)
                respond(BridgeSuccess(
                    v: bridgeProtocolVersion, id: id,
                    displayName: try store.loadSettings()?.displayName ?? ""
                ))

            case "prayer", "advancePrayer", "choosePrayer", "aimPrayer", "showRope", "startAgain":
                try performPrayer(request, store: store, session: &prayers)

            case "reading", "openReading", "toggleReading", "finishReading":
                try performReading(request, store: store, on: selectedDate,
                                   weekCenter: weekCenter, session: &reading)

            case "psalter", "openKathisma", "finishPsalter":
                try performPsalter(request, store: store, on: selectedDate,
                                   weekCenter: weekCenter, session: &psalter)

            case "opening":
                respond(openingSuccess(id: id))

            case "tones":
                respond(try tonesSuccess(id: id, session: &prayers))

            default:
                throw BridgeError.unsupportedOperation(request.op)
            }
        } catch {
            fail(id: id, error)
        }
    }
} catch {
    fail(id: 0, error)
    exit(1)
}
