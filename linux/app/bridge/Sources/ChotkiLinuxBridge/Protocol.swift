import Foundation

// Newline-framed JSON, version 1. Optional keys are omitted, so an older
// reader that looks up keys still sees the same shape. Version stays 1 until
// a key changes meaning.
let bridgeProtocolVersion = 1

struct BridgeRequest: Decodable {
    var v: Int
    var id: Int
    var op: String
    var date: String?
    var ruleID: String?
    var direction: Int?
    var name: String?
    /// A prayer id. Empty or null on `choosePrayer` is the rope alone.
    var selection: String?
    /// One of `PrayerScreen.targets` for `aimPrayer`.
    var target: Int?
    /// The reader's own decision for `showRope`.
    var shown: Bool?
    /// Square the rope layout is computed in, in points.
    var diameter: Double?
    /// Unix seconds for `advancePrayer`. Omitted, the helper uses the clock.
    var now: Double?
}

struct PrayerKnotPayload: Encodable {
    var x: Double
    var y: Double
    /// "counted", "next", or "waiting". The helper classifies; the window only paints.
    var mark: String
}

struct PrayerBeadPayload: Encodable {
    var x: Double
    var y: Double
    var passed: Bool
}

struct PrayerChoicePayload: Encodable {
    var id: String
    var title: String
    var group: String
}

struct PrayerBlockPayload: Encodable {
    var title: String
    var rubric: String?
    var paragraphs: [String]
    var source: String
    var sourceURL: String?
    var centred: Bool
}

struct PrayerPayload: Encodable {
    var selection: String
    var ropeAlone: Bool
    var count: Int
    var target: Int
    var targets: [Int]
    var complete: Bool
    var showsRope: Bool
    var cue: String
    var advanced: Bool
    var event: Int
    var sound: String?
    var diameter: Double
    var dot: Double
    var bead: Double
    var knots: [PrayerKnotPayload]
    var beads: [PrayerBeadPayload]
    var choices: [PrayerChoicePayload]
    var words: [PrayerBlockPayload]
}

struct OpeningPointPayload: Encodable {
    var x: Double
    var y: Double
}

struct OpeningBoxPayload: Encodable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct OpeningFootrestPayload: Encodable {
    var leadingX: Double
    var trailingX: Double
    var leadingY: Double
    var trailingY: Double
    var thickness: Double
}

/// The opening mark. Positions are fractions from core. The clock matches the Mac opening.
struct OpeningPayload: Encodable {
    var knots: [OpeningPointPayload]
    var knotRadius: Double
    var knotSlots: Int
    var box: OpeningBoxPayload
    var bars: [OpeningBoxPayload]
    var footrest: OpeningFootrestPayload
    var build: Double
    var hold: Double
    var fade: Double
    var knotFade: Double
    var staggerLead: Double
}

struct TonePayload: Encodable {
    var tick: String
    var tock: String
    var bell: String
}

struct EntryPayload: Encodable {
    var id: String
    var title: String
    var category: String
    var summary: String
    var time: String
    var kept: Bool
    var dispensed: Bool
    var dispensation: String
}

struct WeekDayPayload: Encodable {
    var date: String
    var day: Int
    var weekday: Int
    var selected: Bool
    var fast: Bool
    var feast: Bool
    var settled: Bool
}

/// One successful reply. Nil fields are left out of the JSON.
struct BridgeSuccess: Encodable {
    var v: Int
    var id: Int
    var ok: Bool = true
    var mode: String?
    var displayName: String?
    var today: String?
    var selectedDate: String?
    var hasCompletedFirstRun: Bool?
    var psalmOneVerses: Int?
    var entries: [EntryPayload]?
    var week: [WeekDayPayload]?
    var dayTitle: String?
    var observedDate: String?
    var showOldStyleDates: Bool?
    var sayingText: String?
    var sayingAuthor: String?
    var sayingSource: String?
    var prayer: PrayerPayload? = nil
    var opening: OpeningPayload? = nil
    var tones: TonePayload? = nil
}

struct BridgeFailure: Encodable {
    var v: Int
    var id: Int
    var ok: Bool = false
    var error: String
}

struct HomeSnapshot {
    var selectedDate: String
    var displayName: String
    var hasCompletedFirstRun: Bool
    var psalmOneVerses: Int
    var entries: [EntryPayload]
    var week: [WeekDayPayload]
    var dayTitle: String
    var observedDate: String
    var showOldStyleDates: Bool
    var sayingText: String
    var sayingAuthor: String
    var sayingSource: String

    func success(id: Int, today: String) -> BridgeSuccess {
        BridgeSuccess(
            v: bridgeProtocolVersion, id: id, displayName: displayName, today: today,
            selectedDate: selectedDate, hasCompletedFirstRun: hasCompletedFirstRun,
            psalmOneVerses: psalmOneVerses, entries: entries, week: week,
            dayTitle: dayTitle, observedDate: observedDate,
            showOldStyleDates: showOldStyleDates, sayingText: sayingText,
            sayingAuthor: sayingAuthor, sayingSource: sayingSource
        )
    }
}
