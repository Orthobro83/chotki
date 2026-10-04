import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func toggleHomeKept(_ entry: DayEntry) throws {
        guard !entry.isDispensed else { return }
        if entry.isKept { try store.removeOccurrence(ruleID: entry.rule.id, date: entry.date) }
        else { try store.save(Occurrence(ruleID: entry.rule.id,date: entry.date,status:.completed,completedAt:Date())) }
        expandedRuleID=nil
        if try practice.isSettled(on: entry.date) { notice="Glory to God for all things" }
    }
    func openHomeEntry(_ entry: DayEntry) throws {
        if expandedRuleID == entry.rule.id { expandedRuleID=nil; return }
        if entry.rule.isFastingRule { flippedRuleID=flippedRuleID == entry.rule.id ? nil : entry.rule.id; return }
        rulePrayerID=nil
        if let id=entry.rule.ropePrayerID ?? entry.rule.sequenceID {
            rope.choose(id); page = .prayers
            selectedRow=prayers.firstIndex { $0.id == id } ?? 0
            return
        }
        switch entry.rule.reference {
        case .reading: page = .reading; readingBand=ReadingOrder.band(ofTitle:entry.rule.title); showPsalter=false
        case .psalter: openPsalter()
        case .prayers:
            page = .prayers; showPsalter=false; rulePrayerID=entry.rule.id
        default: openEditor(entry.rule)
        }
    }
    var customEntries: [Rule] {
        get throws {
            CustomLibrary.entries(from: try store.rules(includeArchived: true),
                                  in: RuleLibrary.shared.scoped(to: settings.jurisdiction.tradition))

        }
    }
    func selectedCustomRule() throws -> Rule? {
        let own = try customEntries
        return customLibrary && own.indices.contains(selectedRow) ? own[selectedRow] : nil
    }
    func selectedHomeEntry() throws -> DayEntry? {
        let entries = try practice.entries(on: selectedDate)
        return entries.indices.contains(selectedRow) ? entries[selectedRow] : nil
    }
    func ruleIsActive(_ rule: Rule) throws -> Bool {
        guard !rule.isArchived else { return false }
        return !(try practice.isPaused(rule))
    }
    func ruleSummary(_ rule: Rule) -> String {
        let form = RecurrenceForm(rule.recurrence)
        var lines = [rule.title, form.kind.rawValue]
        switch rule.recurrence {
        case .once(let day): lines.append(Format.dateWithYear(day))
        case .weekly(let days): lines.append(Weekday.allCases.filter(days.contains).map(Format.weekdayName).joined(separator: ", "))
        case .monthly(let day, let policy): lines.append("Day \(day) · \(policy == .skip ? "skip a short month" : "use its last day")")
        case .liturgical(.season(let season)): lines.append(["Great Lent", "Nativity Fast", "Apostles' Fast", "Dormition Fast"][Self.fastingSeasons.firstIndex(of: season) ?? 0])
        default: break
        }
        if let time = rule.timeOfDay { lines.append(Format.time(time, settings.clockStyle)) }
        if let note = rule.note, !note.isEmpty { lines.append(note) }
        if let source = rule.source, !source.isEmpty {
            lines.append("\(rule.givenByPriest == true ? "Given by" : "Suggested by") \(source)")
        }
        return lines.joined(separator: "\n\n")
    }
    func repairObservances() throws {
        var updated = settings
        for trigger in try practice.observancesNeeded() { updated.observances.observe(trigger) }
        if updated != settings { try store.saveSettings(updated); settings = updated }
    }
    func takeUp(_ rule: Rule) throws {
        guard try !ruleIsActive(rule) else { notice = "\(rule.title) is already on your rule."; return }
        var plan = EditPlan()
        plan.updatedRules = [CustomLibrary.takingUp(rule)]
        if try practice.isPaused(rule) {
            plan.newActivations = [Activation(ruleID: rule.id, from: CalendarDate(Date(), in: .current))]
        }
        try store.apply(plan)
        try repairObservances()
        notice = "\(rule.title) is back on your rule. Its earlier record is still counted."
    }
    func takeSelectedRule() throws {
        if customLibrary {
            if let rule = try selectedCustomRule() { try takeUp(rule) }
            return
        }
        guard templates.indices.contains(selectedRow) else { return }
        let template = templates[selectedRow]
        let matches = try store.rules(includeArchived: true).filter {
            $0.title.compare(template.title, options: .caseInsensitive) == .orderedSame
        }
        for rule in matches where try ruleIsActive(rule) {
            notice = "\(rule.title) is already on your rule."; return
        }
        if let resting = matches.first { try takeUp(resting); return }
        let rule = template.makeRule(source: "the library")
        var plan = EditPlan()
        plan.newRules = [rule]
        plan.newActivations = [Activation(ruleID: rule.id, from: CalendarDate(Date(), in: .current))]
        try store.apply(plan)
        try repairObservances()
        notice = "\(rule.title) is on your rule."
    }
    func togglePause(_ rule: Rule) throws {
        let today = CalendarDate(Date(), in: .current)
        if try practice.isPaused(rule) { try takeUp(rule) }
        else {
            try store.apply(EditPlanner().pause(rule: rule, activations: try store.activations(ruleID: rule.id), on: today))
            notice = "\(rule.title) is paused. The gap will not be counted against you."
        }
    }
    func removeRule(_ rule: Rule, scope: EditScope) throws {
        try store.apply(EditPlanner().delete(rule: rule, activations: try store.activations(ruleID: rule.id),
                                            on: selectedDate, scope: scope))
        selectedRow = 0
        notice = "\(rule.title) removed in the chosen scope. Its kept record is preserved."
    }
    func showRuleMenu() throws {
        guard let entry = try selectedHomeEntry() else { return }
        let destination:String
        switch entry.rule.reference {
        case .rope: destination="Go to the Rope"
        case .prayers: destination="Read the Prayers"
        case .reading: destination=entry.rule.title.lowercased().contains("life of the day") ? "Read the Saint’s Life" : "Read the Day’s Readings"
        case .psalter: destination="Read Today’s Kathisma"
        default: destination="Open"
        }
        let paused=try practice.isPaused(entry.rule)
        destination.withCString { ch_rule_menu(paused ? 1 : 0, entry.isDispensed ? 1 : 0, entry.isKept ? 1 : 0, expandedRuleID==entry.rule.id ? 1 : 0, entry.rule.glossarySlug==nil ? 0 : 1,$0) }
    }
    func homeRuleAction(_ id: Int32) throws {
        guard let entry = try selectedHomeEntry() else { return }
        switch id {
        case 450...453:
            guard !entry.isDispensed else { return }
            if id == 452 { try store.removeOccurrence(ruleID: entry.rule.id, date: selectedDate) }
            else {
                let status: OccurrenceStatus = id == 451 ? .completedLate : id == 453 ? .skipped : .completed
                try store.save(Occurrence(ruleID: entry.rule.id, date: selectedDate, status: status,
                                          completedAt: status == .skipped ? nil : Date()))
            }
        case 456:
            guard !entry.isDispensed else { return }
            expandedRuleID=nil; try openHomeEntry(entry)
        case 457:
            guard !entry.isDispensed else { return }
            expandedRuleID=expandedRuleID==entry.rule.id ? nil : entry.rule.id
            revealExpandedCard=expandedRuleID != nil
        case 458:
            if let slug=entry.rule.glossarySlug { showGlossaryTerm(slug) }
        case 454: openEditor(entry.rule)
        case 455: try togglePause(entry.rule)
        case 460...462: try removeRule(entry.rule, scope: Self.editScopes[Int(id)-460])
        default: break
        }
    }
}
