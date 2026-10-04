import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw BootstrapError.verification(message) }
    }
    func press(_ id: Int32) throws {
        try require(ch_click(id) == 1, "Missing or disabled control \(id)")
        try require(actionError == nil, actionError ?? "Control failed")
    }
    func enter(_ id: Int32, _ value: String) { value.withCString { ch_update(id, $0) }; ch_pump() }
    func choose(_ id: Int32, _ index: Int) throws {
        ch_choose(id, Int32(index))
        try require(actionError == nil, actionError ?? "Choice failed")
    }
    func selectCustom(_ id: UUID) throws {
        try press(101)
        let index = try customEntries.firstIndex { $0.id == id }
        guard let index else { throw BootstrapError.verification("Custom entry \(id) is missing") }
        customLibrary=true; selectedRow=index
    }
    func pressCustom(_ base:Int32) throws { try press(base+Int32(selectedRow)) }
    func writeCustom() throws {
        try press(414)
        if libraryCaution { try press(16601) }
    }
    func fixture(_ title: String, recurrence: Recurrence = .daily) throws -> Rule {
        let rule = Rule(title: title, note: "Keep this note", source: "Fr. Earlier",
                        recurrence: recurrence, timeOfDay: TimeOfDay(hour: 6, minute: 30),
                        category: "prayer", reminders: .forService, prayerIDs: ["jesus-prayer"],
                        createdAt: Date(timeIntervalSince1970: 1_780_000_000), givenByPriest: true)
        var plan = EditPlan()
        plan.newRules = [rule]
        plan.newActivations = [Activation(ruleID: rule.id, from: selectedDate.adding(days: -10))]
        try store.apply(plan)
        return rule
    }
    func captureReview(_ suffix: String) throws {
        guard let base = ProcessInfo.processInfo.environment["CHOTKI_REVIEW_CAPTURE"] else { return }
        let url = URL(fileURLWithPath: base).deletingPathExtension()
        let path = url.path + "-\(suffix).bmp"
        try require(path.withCString { ch_capture($0) } == 1, "Capture \(suffix)")
    }

    func verifyRuleControls() throws {
        let navigationCount=try store.rules(includeArchived:true).count
        for destination in Page.allCases {
            try press(101); try writeCustom()
            enter(501,"Discard this unfinished rule")
            try press(Int32(destination.rawValue))
            try require(editor==nil && page==destination,"Sidebar must discard the draft and navigate")
            try require(try store.rules(includeArchived:true).count==navigationCount,"Sidebar cancellation saved a draft")
        }
        // Configure attribution through the real Settings controls.
        try press(105); enter(313, "Fr. Windows"); try press(430)
        try press(101); try writeCustom()
        let before = try store.rules(includeArchived: true).count
        _ = ch_click(550)
        try require(editor != nil && actionError != nil, "Blank title must keep the editor open")
        try require(try store.rules(includeArchived: true).count == before, "Blank title wrote a rule")
        enter(501, "Windows weekly fixture"); enter(521, "A small beginning"); enter(523, "my parish")
        try press(530); try choose(531, 18); try choose(532, 45)
        try press(534); try press(537)
        try choose(511, 2) // Weekdays; previously typed fields must survive.
        try press(512); try press(515); try press(517) // Sunday off, Wednesday/Friday on.
        try press(524)
        ch_test_resize(640,540)
        try require(text(501)=="Windows weekly fixture" && text(521)=="A small beginning","Narrow editor retained typed fields")
        ch_test_panel_scroll(0); try require(ch_test_control_visible(501)==1,"Narrow editor title is reachable")
        try captureReview("editor-narrow-top")
        ch_test_panel_scroll(1); try require(ch_test_control_visible(550)==1 && ch_test_control_visible(551)==1,"Narrow editor actions are reachable")
        try captureReview("editor-narrow-actions")
        ch_test_resize(1100,860); ch_test_panel_scroll(0)
        try captureReview("editor")
        try press(550)
        guard let created = try store.rules(includeArchived: true).first(where: { $0.title == "Windows weekly fixture" }) else {
            throw BootstrapError.verification("Custom editor did not create its rule")
        }
        try require(created.recurrence == .wednesdayAndFriday, "Weekday controls")
        try require(created.timeOfDay == TimeOfDay(hour: 18, minute: 45), "Hour/minute controls")
        try require(created.note == "A small beginning" && created.source == "Fr. Windows" && created.givenByPriest == true, "Text/attribution survived recurrence changes")
        try require(Set(created.effectiveReminders.leads) == [.atTheTime, .tenMinutes, .oneHour], "Multiple reminder lead controls")
        try selectCustom(created.id); try pressCustom(15000)
        try require(try practice.isPaused(created), "Pause did not close activation")
        try pressCustom(15000)
        try require(try !practice.isPaused(created), "Resume did not reopen activation")
        try require(try store.activations(ruleID: created.id).count == 2, "Resume created a different rule")
        try pressCustom(14000); try choose(541, 2); try press(552)
        try require(try store.rule(id: created.id)?.isArchived == true, "Whole-rule removal did not archive")
        let pastActivations = try store.activations(ruleID: created.id).count
        try selectCustom(created.id); try pressCustom(12000)
        try require(try store.rule(id: created.id)?.isArchived == false, "Re-take did not restore the same rule")
        try require(try store.activations(ruleID: created.id).count == pastActivations + 1, "Re-take did not retain prior stretches and open a new one")
        try captureReview("library")
        try pressCustom(13000)
        try require(try !customEntries.contains { $0.id == created.id }, "Set-aside still offered in Custom")
        try require(try store.rule(id: created.id)?.hiddenFromLibrary == true && !practice.isPaused(created), "Set-aside changed active practice")

        // Exercise the actual Home menu command routes, including reset versus dispensation.
        try press(100)
        let home = try practice.entries(on: selectedDate)
        guard let jesus = home.firstIndex(where: { $0.rule.title == "Jesus Prayer" }) else { throw BootstrapError.verification("Home fixture missing") }
        try choose(300, jesus)
        let ruleID = home[jesus].rule.id
        ch_command(451); ch_pump()
        try require(try store.occurrences(ruleID: ruleID, from: selectedDate, through: selectedDate).first?.status == .completedLate, "Explicit kept-late action")
        ch_command(452); ch_pump()
        try require(try store.occurrences(ruleID: ruleID, from: selectedDate, through: selectedDate).isEmpty, "Reset silently excused the day")
        ch_command(453); ch_pump()
        try require(try store.occurrences(ruleID: ruleID, from: selectedDate, through: selectedDate).first?.status == .skipped, "Stand-down action")
        ch_command(450); ch_pump()
        try require(try store.occurrences(ruleID: ruleID, from: selectedDate, through: selectedDate).first?.status == .completed, "Mark-kept action")
        ch_command(454); ch_pump()
        try require(editor?.original?.id == ruleID, "Home edit route")
        try press(551)

        // UI round trips must preserve shapes and metadata that the editor did not alter.
        let recurrences: [Recurrence] = [
            .once(selectedDate.adding(days: 5)), .weekly(days: [.wednesday, .friday]),
            .monthly(day: 31, whenShort: .skip), .liturgical(.fastDay),
            .liturgical(.greatFeast), .liturgical(.akathist)
        ] + Self.fastingSeasons.map { .liturgical(.season($0)) }
        for (i, recurrence) in recurrences.enumerated() {
            let original = try fixture("Editor round trip \(i)", recurrence: recurrence)
            try selectCustom(original.id); try pressCustom(14000)
            enter(501, original.title + " revised"); try press(550)
            guard let loaded = try store.rule(id: original.id) else { throw BootstrapError.verification("Edited rule missing") }
            try require(loaded.recurrence == recurrence, "UI changed recurrence \(recurrence)")
            try require(loaded.prayerIDs == original.prayerIDs && loaded.category == original.category && loaded.source == original.source && loaded.givenByPriest == original.givenByPriest, "Editor lost prayer/category/attribution metadata")
            try require(loaded.timeOfDay == original.timeOfDay && Set(loaded.effectiveReminders.leads) == Set(original.effectiveReminders.leads), "Editor lost time/reminders")
        }
        var longNoteRule = try fixture("Unicode and long-note fixture")
        longNoteRule.note = String(repeating: "Помилуй нас.\n", count: 600)
        try store.save(longNoteRule)
        try selectCustom(longNoteRule.id); try pressCustom(14000); try press(550)
        try require(try store.rule(id: longNoteRule.id)?.note == longNoteRule.note, "Editor truncated Unicode or a long note")

        // Invalid one-off dates cannot quietly become daily rules or write any data.
        try writeCustom(); enter(501, "One-off validation"); try choose(511, 0)
        enter(512, "2026-02-30")
        let count = try store.rules(includeArchived: true).count
        _ = ch_click(550)
        try require(editor != nil && actionError != nil, "Invalid date was accepted")
        try require(try store.rules(includeArchived: true).count == count, "Invalid date wrote data")
        try press(551)

        // Each edit scope uses the core planner, and keeps yesterday's recorded history.
        for scope in Self.editScopes {
            let original = try fixture("Scope fixture \(scope.rawValue)")
            let yesterday = selectedDate.adding(days: -1)
            try store.save(Occurrence(ruleID: original.id, date: yesterday, status: .completed))
            try selectCustom(original.id); try pressCustom(14000)
            enter(501, original.title + " changed")
            try choose(541, Self.editScopes.firstIndex(of: scope)!)
            try press(550)
            try require(try store.occurrences(ruleID: original.id, from: yesterday, through: yesterday).first?.status == .completed, "Scoped edit lost past occurrence")
            if scope == .wholeSeries {
                try require(try store.rule(id: original.id)?.title.hasSuffix("changed") == true, "Whole-series edit identity")
            } else {
                let successors = try store.rules(includeArchived: true).filter { $0.title == original.title + " changed" }
                try require(successors.count == 1 && successors[0].id != original.id && successors[0].prayerIDs == original.prayerIDs, "Scoped successor lost identity/metadata")
                if scope == .thisDay {
                    try require(successors[0].recurrence == .once(selectedDate), "One-day edit changed the series")
                    try require(try store.occurrences(ruleID: original.id, from: selectedDate, through: selectedDate).first?.status == .cancelled, "One-day edit did not replace occurrence")
                } else {
                    try require(try store.activations(ruleID: original.id).allSatisfy { $0.to == yesterday }, "Future edit rewrote history")
                }
            }
        }
        for scope in Self.editScopes {
            let rule = try fixture("Remove fixture \(scope.rawValue)")
            let yesterday = selectedDate.adding(days: -1)
            try store.save(Occurrence(ruleID: rule.id, date: yesterday, status: .completed))
            try selectCustom(rule.id); try pressCustom(14000)
            try choose(541, Self.editScopes.firstIndex(of: scope)!); try press(552)
            try require(try store.occurrences(ruleID: rule.id, from: yesterday, through: yesterday).first?.status == .completed, "Scoped removal lost history")
            if scope == .thisDay {
                try require(try store.occurrences(ruleID: rule.id, from: selectedDate, through: selectedDate).first?.status == .cancelled, "One-day removal")
                try require(try !practice.isPaused(rule), "One-day removal ended series")
            } else {
                try require(try practice.isPaused(rule), "Removal left future activation open")
                try require(try store.rule(id: rule.id)?.isArchived == (scope == .wholeSeries), "Wrong removal scope archived rule")
            }
        }
        print("Rule UI passed: validation, custom create/edit, recurrence round trips, reminder leads, attribution, pause/resume, archive/re-take, set-aside, all edit/remove scopes and kept-history preservation.")
    }
}
