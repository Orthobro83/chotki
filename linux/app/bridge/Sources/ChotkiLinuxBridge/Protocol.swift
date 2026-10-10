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
