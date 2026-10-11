import ChotkiCore
import Foundation

/// The prayers screen for this helper process.
///
/// A second between knots, because the Count control answers the space bar and
/// a held key would otherwise run the rope on. A tap that arrives too soon is
/// left alone and makes no sound.
struct PrayerSession {
    var screen = PrayerScreen(selection: "jesus-prayer", minimumInterval: 1)
    var event = 0
    var diameter = 240.0
    var tones: TonePayload?
}

func performPrayer(_ request: BridgeRequest, store: SQLiteStore, session: inout PrayerSession) throws {
    if let diameter = request.diameter {
        guard diameter.isFinite, diameter > 0, diameter <= 4096 else { throw BridgeError.invalidRequest }
        session.diameter = diameter
    }
    let settings = try store.loadSettings() ?? .default
    var advanced = false
    var sound: String?
    switch request.op {
    case "prayer":
        break
    case "advancePrayer":
        let moment = request.now.map { Date(timeIntervalSince1970: $0) } ?? Date()
        let before = session.screen.count
        let completed = session.screen.advance(at: moment)
        advanced = session.screen.count != before
        if advanced { session.event += 1 }
        sound = prayerSound(advanced: advanced, completed: completed, cue: session.screen.cue, settings: settings)
    case "choosePrayer":
        let selection = request.selection?.isEmpty == false ? request.selection : nil
        if let selection,
           PrayerBook.shared.sequence(id: selection) == nil,
           PrayerBook.shared.prayer(id: selection) == nil {
            throw BridgeError.unknownPrayer
        }
        session.screen.choose(selection)
    case "aimPrayer":
        guard let target = request.target, PrayerScreen.targets.contains(target) else {
            throw BridgeError.invalidRequest
        }
        session.screen.aim(at: target)
    case "showRope":
        guard let shown = request.shown else { throw BridgeError.invalidRequest }
        session.screen.showRope(shown)
    case "startAgain":
        session.screen.startAgain()
    default:
        throw BridgeError.unsupportedOperation(request.op)
    }
    respond(BridgeSuccess(
        v: bridgeProtocolVersion, id: request.id,
        prayer: prayerPayload(session: session, tradition: settings.jurisdiction.tradition,
                              advanced: advanced, sound: sound)
    ))
}

/// The chime marks a finished knot. A tick or a tock only confirms a press.
/// The two are never played together.
func prayerSound(advanced: Bool, completed: Bool, cue: RopeCue, settings: AppSettings) -> String? {
    guard advanced else { return nil }
    if completed { return settings.chimeOnCompletion ? "bell" : nil }
    guard settings.tickEachKnot else { return nil }
    switch cue {
    case .tock: return "tock"
    case .tick: return "tick"
    case .bell: return "bell"
    }
}

func prayerPayload(session: PrayerSession, tradition: Tradition, advanced: Bool, sound: String?) -> PrayerPayload {
    let screen = session.screen
    let layout = RopeCircleLayout.layout(count: screen.target, diameter: session.diameter)
    let knots = layout.knots.enumerated().map { index, point in
        PrayerKnotPayload(
            x: point.x, y: point.y,
            mark: index < screen.count ? "counted" : index == screen.count ? "next" : "waiting"
        )
    }
    let beads = layout.beads.enumerated().map { index, point in
        PrayerBeadPayload(x: point.x, y: point.y, passed: layout.beadHasBeenPassed(index, count: screen.count))
    }
    let book = PrayerBook.shared.scoped(to: tradition)
    var choices = [PrayerChoicePayload(id: "", title: "The rope alone", group: "")]
    for sequence in PrayerBook.shared.sequences {
        choices.append(PrayerChoicePayload(id: sequence.id, title: sequence.title, group: "Rules"))
    }
    for prayer in book.forRope() {
        choices.append(PrayerChoicePayload(id: prayer.id, title: prayer.title, group: "On the rope"))
    }
    for prayer in book.notForRope() {
        choices.append(PrayerChoicePayload(id: prayer.id, title: prayer.title, group: "Read"))
    }
    return PrayerPayload(
        selection: screen.selection ?? "", ropeAlone: screen.selection == nil,
        count: screen.count, target: screen.target, targets: PrayerScreen.targets,
        complete: screen.isComplete, showsRope: screen.showsRope(),
        cue: cueName(screen.cue), advanced: advanced, event: session.event, sound: sound,
        diameter: session.diameter, dot: layout.dot, bead: layout.bead,
        knots: knots, beads: beads, choices: choices,
        words: prayerWords(screen.selection, tradition: tradition)
    )
}

func prayerWords(_ selection: String?, tradition: Tradition) -> [PrayerBlockPayload] {
    guard let selection, !selection.isEmpty else { return [] }
    let glossary = Glossary.shared(for: tradition)
    if let sequence = PrayerBook.shared.sequence(id: selection) {
        let prayers = PrayerBook.shared.prayers(of: sequence)
        let matches = glossary.scanOnce(across: prayers.map(\.paragraphs))
        return zip(prayers, matches).map { prayer, found in
            prayerBlock(prayer, centred: false, matches: found)
        }
    }
    guard let prayer = PrayerBook.shared.prayer(id: selection) else { return [] }
    return [prayerBlock(prayer, centred: true, matches: glossary.scanOnce(prayer.paragraphs))]
}

func prayerBlock(_ prayer: Prayer, centred: Bool, matches: [[TermMatch]]) -> PrayerBlockPayload {
    let html = prayer.paragraphs.enumerated().map { index, paragraph in
        linkedMarkup(paragraph, matches: index < matches.count ? matches[index] : [])
    }
    return PrayerBlockPayload(
        title: prayer.title, rubric: prayer.rubric, paragraphs: prayer.paragraphs, html: html,
        source: prayer.source, sourceURL: prayer.sourceURL, centred: centred
    )
}

func cueName(_ cue: RopeCue) -> String {
    switch cue {
    case .tick: "tick"
    case .tock: "tock"
    case .bell: "bell"
    }
}

/// Knots, the cross, and the clock. The numbers are `OpeningTiming` on the Mac:
/// 1.8s to draw, 1.5s held, 0.4s to leave. Reduced motion is the window's decision.
func openingSuccess(id: Int) -> BridgeSuccess {
    let box = RopeMarkGeometry.crossBox
    let foot = CrossGeometry.footrest
    let opening = OpeningPayload(
        knots: RopeMarkGeometry.knotCentres.map { OpeningPointPayload(x: $0.x, y: $0.y) },
        knotRadius: RopeMarkGeometry.knotRadius,
        knotSlots: RopeMarkGeometry.knots,
        box: OpeningBoxPayload(x: box.x, y: box.y, width: box.width, height: box.height),
        bars: CrossGeometry.bars.map { OpeningBoxPayload(x: $0.x, y: $0.y, width: $0.width, height: $0.height) },
        footrest: OpeningFootrestPayload(
            leadingX: foot.leadingX, trailingX: foot.trailingX,
            leadingY: foot.leadingY, trailingY: foot.trailingY, thickness: foot.thickness
        ),
        build: 1.8, hold: 1.5, fade: 0.4, knotFade: 0.16, staggerLead: 0.2
    )
    return BridgeSuccess(v: bridgeProtocolVersion, id: id, opening: opening)
}

func tonesSuccess(id: Int, session: inout PrayerSession) throws -> BridgeSuccess {
    if session.tones == nil {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-tones-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func write(_ spec: ToneSpec, _ name: String) throws -> String {
            let url = directory.appendingPathComponent(name)
            try WAV.encode(ToneRenderer.render(spec)).write(to: url)
            return url.path
        }
        session.tones = TonePayload(
            tick: try write(.tick, "tick.wav"),
            tock: try write(.tock, "tock.wav"),
            bell: try write(.bell, "bell.wav")
        )
    }
    return BridgeSuccess(v: bridgeProtocolVersion, id: id, tones: session.tones)
}
