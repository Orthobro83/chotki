import ChotkiCore
import Foundation

// The reading page and the Psalter. Core decides the sections, the scripture,
// the life, and which rule a finished section keeps. The window only draws
// and reports that a person scrolled to the end.

struct ReadingSession {
    var focus: Int?
    var expanded: Set<Int> = []

    mutating func showSidebar() {
        focus = nil
        expanded = []
    }

    mutating func focus(on band: Int) {
        focus = band
        expanded = [band]
    }

    mutating func toggle(_ band: Int) {
        if expanded.contains(band) {
            expanded.remove(band)
        } else {
            expanded.insert(band)
        }
    }

    /// A new day opens the section a rule asked for, or nothing.
    mutating func applyFocus() {
        expanded = focus.map { [$0] } ?? []
    }
}

struct PsalterSession {
    var appointedOpen: Int?
    var manualOpen: Int?

    mutating func toggleAppointed(_ number: Int) {
        appointedOpen = appointedOpen == number ? nil : number
    }

    mutating func toggleManual(_ number: Int) {
        manualOpen = manualOpen == number ? nil : number
    }

    mutating func clear() {
        appointedOpen = nil
        manualOpen = nil
    }
}

private struct DayRecord {
    var settings: AppSettings
    var entries: [DayEntry]
    var day: LiturgicalDay?
    var liturgical: LiturgicalService
}

private func dayRecord(store: SQLiteStore, on date: CalendarDate) throws -> DayRecord {
    let settings = try store.loadSettings() ?? .default
    let rules = try store.rules(includeArchived: false)
    let activations = try store.activations(ruleID: nil)
    let occurrences = try store.occurrences(ruleID: nil, from: date, through: date)
    let liturgical = LiturgicalService(store: store, jurisdiction: settings.jurisdiction,
                                      networkPolicy: .never)
    let practice = Practice(rules: rules, activations: activations,
                            occurrences: occurrences, settings: settings, liturgical: liturgical)
    return DayRecord(settings: settings, entries: practice.entries(on: date),
                     day: liturgical.cachedDay(for: date), liturgical: liturgical)
}

private func requireBand(_ band: Int?) throws -> Int {
    guard let band, (0...ReadingOrder.akathistBand).contains(band) else {
        throw BridgeError.invalidRequest
    }
    return band
}

private func requireKathisma(_ number: Int?) throws -> Int {
    guard let number, (1...20).contains(number) else { throw BridgeError.invalidRequest }
    return number
}

/// Same decision as the Mac: a kept, dispensed, or stood-down day is left alone.
private func markKept(_ entries: [DayEntry], store: SQLiteStore, on date: CalendarDate,
                      where matches: (DayEntry) -> Bool) throws -> [String] {
    var written: [String] = []
    for entry in entries where matches(entry) {
        guard !entry.isKept, !entry.isDispensed, !entry.isStoodDown else { continue }
        try store.save(Occurrence(
            ruleID: entry.rule.id, date: date, status: .completed, completedAt: Date()
        ))
        written.append(entry.rule.id.uuidString)
    }
    return written
}

private func sectionState(_ entries: [DayEntry], band: Int) -> (kept: Bool, dispensed: Bool, stoodDown: Bool, asked: Bool) {
    let related = entries.filter { ReadingOrder.band(ofTitle: $0.rule.title) == band }
    return (
        related.contains { $0.isKept },
        related.contains { $0.isDispensed },
        related.contains { $0.isStoodDown },
        related.contains { !$0.isDispensed }
    )
}

private func lifePayload(_ day: LiturgicalDay) -> LifePayload {
    guard let life = SaintLives.reading(on: day.observedDate) else {
        return LifePayload(
            available: false, dates: "", preface: "", sections: [],
            saints: day.saints.joined(separator: " · "),
            unavailable: "No life is stored for this day.",
            source: "", sourceURL: "", license: "", licenseURL: "", licenseNote: ""
        )
    }
    return LifePayload(
        available: true, dates: life.dates, preface: life.preface ?? "",
        sections: life.sections.map { section in
            LifeSectionPayload(heading: section.heading, blocks: section.blocks.map { block in
                LifeBlockPayload(
                    kind: block.kind, text: block.text ?? "",
                    spans: (block.spans ?? []).map { LifeSpanPayload(text: $0.text, italic: $0.italic, bold: $0.bold) },
                    rows: (block.rows ?? []).map { row in
                        row.map { LifeSpanPayload(text: $0.text, italic: $0.italic, bold: $0.bold) }
                    }
                )
            })
        },
        saints: "", unavailable: "",
        source: life.source, sourceURL: life.sourceURL,
        license: life.license, licenseURL: life.licenseURL, licenseNote: life.licenseNote
    )
}

private func readingPayload(record: DayRecord, session: ReadingSession, marked: [String]) -> ReadingPayload {
    guard let day = record.day else {
        return ReadingPayload(
            title: "", summary: "", fastNote: "", abstentionNote: "",
            fathersText: "", fathersBy: "", footer: "",
            waiting: "No reading stored for this day yet.",
            waitingDetail: "Connect to the internet to fetch the church calendar. Previously fetched readings remain available offline.",
            sections: [], marked: marked
        )
    }
    let held = Set(record.entries.compactMap { ReadingOrder.band(ofTitle: $0.rule.title) })
    var bands = ReadingOrder.orderedBands(held: held).filter { band in
        day.readings.contains { ReadingOrder.band(source: $0.source) == band }
    }
    bands.append(ReadingOrder.saintLifeBand)
    if record.settings.jurisdiction.tradition.isSlavic || held.contains(ReadingOrder.departedBand) {
        bands.append(ReadingOrder.departedBand)
    }
    if record.liturgical.akathistWeek(day.civilDate) != nil {
        bands.append(ReadingOrder.akathistBand)
    }

    let sections: [ReadingSectionPayload] = bands.map { band in
        let state = sectionState(record.entries, band: band)
        let open = session.expanded.contains(band)
        let sources = day.readings.filter { ReadingOrder.band(source: $0.source) == band }.map(\.source)
        var passages: [ReadingPassagePayload] = []
        var life: LifePayload?
        var appointed: AppointedPayload?
        if open {
            if band == ReadingOrder.saintLifeBand {
                life = lifePayload(day)
            } else if band == ReadingOrder.departedBand {
                appointed = AppointedPayload(
                    heading: DepartedCommemoration.rubric, note: "",
                    paragraphs: DepartedCommemoration.paragraphs,
                    source: DepartedCommemoration.source, sourceURL: DepartedCommemoration.sourceURL
                )
            } else if band == ReadingOrder.akathistBand, let week = record.liturgical.akathistWeek(day.civilDate) {
                appointed = AppointedPayload(
                    heading: Akathist.heading(week: week),
                    note: Akathist.fallbackNote(for: record.settings.jurisdiction.tradition) ?? "",
                    paragraphs: Akathist.paragraphs(week: week),
                    source: Akathist.source, sourceURL: Akathist.sourceURL
                )
            } else {
                passages = day.readings.filter { ReadingOrder.band(source: $0.source) == band }.map {
                    ReadingPassagePayload(citation: "\($0.source) · \($0.display)", text: $0.text)
                }
            }
        }
        return ReadingSectionPayload(
            band: band, title: ReadingOrder.sectionTitle(band: band, sources: sources),
            open: open, kept: state.kept, dispensed: state.dispensed,
            stoodDown: state.stoodDown, asked: state.asked,
            passages: passages, life: life, appointed: appointed
        )
    }

    let patristic = PatristicReadings.shared.reading(for: day.civilDate)
    var footer = "\(day.paschaDistance) days since Pascha"
    if let tone = day.tone { footer += " · tone \(tone)" }
    let calendar = record.liturgical.isOffline(on: day.civilDate)
        ? "cached"
        : record.settings.jurisdiction.reckoning == .julian ? "old calendar" : "new calendar"
    footer += " · \(calendar)"
    let fastNote = record.settings.observances.fasting.isVisible && day.isFast
        ? "The calendar marks this as \(day.fastDescription)." : ""
    let abstention = day.abstentions.isEmpty
        ? "" : "Customarily set aside: \(day.abstentions.joined(separator: ", "))."
    let glossary = Glossary.shared(for: record.settings.jurisdiction.tradition)
    return ReadingPayload(
        title: day.title ?? "", summary: day.summaryTitle,
        fastNote: fastNote, abstentionNote: abstention,
        fathersText: patristic?.text ?? "",
        fathersBy: patristic.map { "\($0.author) · \($0.source)" } ?? "",
        footer: footer, waiting: "", waitingDetail: "",
        sections: sections, marked: marked,
        summaryHtml: linkedMarkup(day.summaryTitle, matches: glossary.scan(day.summaryTitle)),
        fastNoteHtml: linkedMarkup(fastNote, matches: glossary.scan(fastNote))
    )
}

func performReading(_ request: BridgeRequest, store: SQLiteStore, on date: CalendarDate,
                    weekCenter: CalendarDate, session: inout ReadingSession) throws {
    var marked: [String] = []
    switch request.op {
    case "reading":
        break
    case "openReading":
        if let band = request.band {
            session.focus(on: try requireBand(band))
        } else {
            session.showSidebar()
        }
    case "toggleReading":
        session.toggle(try requireBand(request.band))
    case "finishReading":
        let band = try requireBand(request.band)
        let record = try dayRecord(store: store, on: date)
        marked = try markKept(record.entries, store: store, on: date) {
            ReadingOrder.band(ofTitle: $0.rule.title) == band
        }
    default:
        throw BridgeError.unsupportedOperation(request.op)
    }
    let record = try dayRecord(store: store, on: date)
    let payload = readingPayload(record: record, session: session, marked: marked)
    if request.op == "finishReading" {
        let today = CalendarDate(Date(), in: .current).iso
        var success = try homeSnapshot(store: store, on: date, weekCenter: weekCenter)
            .success(id: request.id, today: today)
        success.reading = payload
        respond(success)
    } else {
        respond(BridgeSuccess(v: bridgeProtocolVersion, id: request.id, reading: payload))
    }
}

private func kathismaRange(_ number: Int) -> String {
    guard let range = Kathisma.psalms(in: number) else { return "" }
    if range.lowerBound == range.upperBound { return "Psalm \(range.lowerBound)" }
    return "Psalms \(range.lowerBound)–\(range.upperBound)"
}

private func kathismaPayload(_ number: Int, open: Bool) -> KathismaPayload {
    let psalms: [PsalmPayload] = open ? Psalter.kathisma(number).map { psalm in
        PsalmPayload(
            number: psalm.number, superscription: psalm.superscription,
            verses: psalm.verses.map { PsalmVersePayload(number: $0.number, text: $0.text) }
        )
    } : []
    return KathismaPayload(
        number: number, label: "Kathisma \(number)", range: kathismaRange(number),
        open: open, psalms: psalms
    )
}

private func seasonName(_ season: Kathisma.Season) -> String {
    switch season {
    case .ordinary: return "ordinary"
    case .greatLent: return "greatLent"
    case .fifthWeekOfLent: return "fifthWeekOfLent"
    case .holyWeek: return "holyWeek"
    case .brightWeek: return "brightWeek"
    }
}

private func psalterPayload(record: DayRecord, on date: CalendarDate, session: PsalterSession,
                             marked: [String]) -> PsalterPayload {
    let distance = record.day?.paschaDistance ?? 0
    let season = Kathisma.season(paschaDistance: distance)
    let weekday = date.weekday
    let appointed = Kathisma.appointed(weekday: weekday, season: season)
    let groups = appointed.map { entry in
        PsalterGroupPayload(
            service: entry.service.displayName,
            kathismata: entry.kathismata.map {
                kathismaPayload($0, open: session.appointedOpen == $0)
            }
        )
    }
    let note: String
    let empty: String
    if appointed.isEmpty {
        empty = "No kathisma is appointed today."
        note = season == .brightWeek
            ? "The Psalter is not read through Bright Week."
            : "Nothing is appointed for this day."
    } else {
        empty = ""
        note = ""
    }
    let manual = session.manualOpen
    return PsalterPayload(
        season: seasonName(season), note: note, empty: empty, appointed: groups,
        manual: manual, manualKathisma: manual.map { kathismaPayload($0, open: true) },
        source: Psalter.source, marked: marked
    )
}

func performPsalter(_ request: BridgeRequest, store: SQLiteStore, on date: CalendarDate,
                    weekCenter: CalendarDate, session: inout PsalterSession) throws {
    var marked: [String] = []
    switch request.op {
    case "psalter":
        break
    case "openKathisma":
        let number = try requireKathisma(request.kathisma)
        guard let manual = request.manual else { throw BridgeError.invalidRequest }
        if manual {
            session.toggleManual(number)
        } else {
            session.toggleAppointed(number)
        }
    case "finishPsalter":
        let record = try dayRecord(store: store, on: date)
        marked = try markKept(record.entries, store: store, on: date) {
            $0.rule.reference == .psalter
        }
    default:
        throw BridgeError.unsupportedOperation(request.op)
    }
    let record = try dayRecord(store: store, on: date)
    let payload = psalterPayload(record: record, on: date, session: session, marked: marked)
    if request.op == "finishPsalter" {
        let today = CalendarDate(Date(), in: .current).iso
        var success = try homeSnapshot(store: store, on: date, weekCenter: weekCenter)
            .success(id: request.id, today: today)
        success.psalter = payload
        respond(success)
    } else {
        respond(BridgeSuccess(v: bridgeProtocolVersion, id: request.id, psalter: payload))
    }
}
