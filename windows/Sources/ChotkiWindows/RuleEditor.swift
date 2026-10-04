import Foundation
import ChotkiCore
import WindowsUI

struct RuleDraft {
    let original: Rule?
    var rule: Rule
    var form: RecurrenceForm
    var onceDate: String
    var hasTime: Bool
    var hour: Int
    var minute: Int
    var reminders: Bool
    var leads: Set<ReminderLead>
    var givenByPriest: Bool
    var priestAttribution: String
    var scope: EditScope = .wholeSeries

    init(_ existing: Rule?, on date: CalendarDate, father: String) {
        original = existing
        rule = existing ?? Rule(title: "", recurrence: .daily)
        form = RecurrenceForm(rule.recurrence)
        onceDate = (form.onceDate ?? date).iso
        hasTime = rule.timeOfDay != nil
        hour = rule.timeOfDay?.hour ?? 6; minute = rule.timeOfDay?.minute ?? 30
        reminders = rule.effectiveReminders.enabled
        leads = Set(rule.effectiveReminders.leads)
        givenByPriest = rule.givenByPriest == true
        let source = rule.source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        priestAttribution = givenByPriest && !source.isEmpty && source != "the library" ? source : father
    }
}

struct RuleInputError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

extension WindowsApp {
    static let editScopes: [EditScope] = [.thisDay, .thisAndFuture, .wholeSeries]
    static let fastingSeasons: [FastingSeason] = [.greatLent, .nativityFast, .apostlesFast, .dormitionFast]

    func choice(_ id: Int32, _ items: [String], selected: Int, x: Int32, y: Int32, width: Int32) {
        control(id, 7, "", x, y, width)
        for item in items { item.withCString { ch_list_add(id, $0) } }
        ch_select(id, Int32(selected))
    }
    func checkbox(_ id: Int32, _ text: String, checked: Bool, x: Int32, y: Int32, width: Int32 = 350) {
        control(id, 6, text, x, y, width, 36)
        ch_check(id, checked ? 1 : 0)
    }

    func openEditor(_ rule: Rule? = nil) {
        editor = RuleDraft(rule, on: selectedDate,
                           father: settings.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines))
        notice = ""
    }

    func renderEditor() {
        guard let draft = editor else { return }
        title(draft.original == nil ? "Write your own rule" : "Edit your rule", subtitle: "\(selectedDate.iso) · A rule is yours to change or set down.")
        control(500, 0, "What is it?", 260, 150, 770)
        control(501, 3, draft.rule.title, 260, 185, 770)
        control(510, 0, "How often?", 260, 235, 350)
        let kinds = RecurrenceForm.Kind.allCases
        choice(511, kinds.map(\.rawValue), selected: kinds.firstIndex(of: draft.form.kind) ?? 1, x: 260, y: 270, width: 350)
        switch draft.form.kind {
        case .weekly:
            for (i, day) in Weekday.allCases.enumerated() {
                checkbox(Int32(512+i), ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][i],
                         checked: draft.form.weekdays.contains(day), x: 260 + Int32(i % 4)*88,
                         y: 315 + Int32(i / 4)*36, width: 85)
            }
        case .monthly:
            choice(512, (1...31).map { "Day \($0)" }, selected: draft.form.monthDay-1, x: 260, y: 315, width: 120)
            choice(513, ["Use the last day", "Skip a short month"], selected: draft.form.shortMonthPolicy == .skip ? 1 : 0, x: 390, y: 315, width: 220)
        case .once:
            control(512, 3, draft.onceDate, 260, 315, 350)
            control(519, 0, "Date: YYYY-MM-DD", 260, 353, 350)
        case .season:
            choice(512, ["Great Lent", "Nativity Fast", "Apostles' Fast", "Dormition Fast"],
                   selected: Self.fastingSeasons.firstIndex(of: draft.form.season) ?? 0, x: 260, y: 315, width: 350)
        default: break
        }
        control(520, 0, "A note, if it helps", 260, 406, 350)
        let note = (draft.rule.note ?? "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n")
        control(521, 8, note, 260, 441, 350, 66)
        control(522, 0, "Who suggested it?", 260, 520, 350)
        let hasAttribution = draft.givenByPriest && !draft.priestAttribution.isEmpty
        control(523, 3, hasAttribution ? draft.priestAttribution : draft.rule.source ?? "", 260, 555, 350)
        ch_enable(523, hasAttribution ? 0 : 1)
        let father = draft.priestAttribution.isEmpty ? settings.spiritualFatherName : draft.priestAttribution
        checkbox(524, father.isEmpty ? "Given to me by my priest" : "Given to me by \(father)",
                 checked: draft.givenByPriest, x: 260, y: 602)

        checkbox(530, "At a set time", checked: draft.hasTime, x: 650, y: 235)
        choice(531, (0...23).map { Format.hourLabel($0, settings.clockStyle) }, selected: draft.hour, x: 650, y: 278, width: 175)
        choice(532, (0...59).map { String(format: "%02d", $0) }, selected: draft.minute, x: 835, y: 278, width: 100)
        ch_enable(531, draft.hasTime ? 1 : 0); ch_enable(532, draft.hasTime ? 1 : 0)
        control(529, 0, draft.hasTime ? "" : "It runs all day.", 650, 317, 370)
        checkbox(533, "Remind me", checked: draft.reminders, x: 650, y: 355)
        for (i, lead) in ReminderLead.choices.enumerated() {
            checkbox(Int32(534+i), lead.label, checked: draft.leads.contains(lead),
                     x: 650 + Int32(i % 2)*195, y: 397 + Int32(i / 2)*36, width: 190)
            ch_enable(Int32(534+i), draft.reminders && draft.hasTime ? 1 : 0)
        }
        if draft.original != nil {
            control(540, 0, "Apply the change to", 650, 520, 370)
            choice(541, ["Just this day", "This day and after", "The whole rule"],
                   selected: Self.editScopes.firstIndex(of: draft.scope) ?? 2, x: 650, y: 555, width: 370)
            control(552, 1, "Remove in This Scope", 650, 620, 240)
        }
        control(550, 1, "Save Rule", 260, 655, 150)
        control(551, 1, "Cancel", 430, 655, 150)
        // Notice is below the editor actions; keep validation in the same window.
        ch_update(202, "")
        control(553, 0, notice, 650, 660, 380, 60)
    }

    /// Read before rebuilding controls, so changing recurrence never drops typed fields.
    func captureEditor() {
        guard var draft = editor else { return }
        draft.rule.title = text(501); draft.rule.note = text(521).replacingOccurrences(of: "\r\n", with: "\n")
        if !draft.givenByPriest || draft.priestAttribution.isEmpty { draft.rule.source = text(523) }
        switch draft.form.kind {
        case .weekly:
            draft.form.weekdays = Set(Weekday.allCases.enumerated().compactMap { i, day in ch_checked(Int32(512+i)) == 1 ? day : nil })
        case .monthly:
            draft.form.monthDay = max(1, Int(ch_selected(512))+1)
            draft.form.shortMonthPolicy = ch_selected(513) == 1 ? .skip : .lastDay
        case .once: draft.onceDate = text(512)
        case .season: draft.form.season = Self.fastingSeasons[max(0, Int(ch_selected(512)))]
        default: break
        }
        draft.form.kind = RecurrenceForm.Kind.allCases[max(0, Int(ch_selected(511)))]
        draft.hasTime = ch_checked(530) == 1
        draft.hour = max(0, Int(ch_selected(531))); draft.minute = max(0, Int(ch_selected(532)))
        draft.reminders = ch_checked(533) == 1
        draft.leads = Set(ReminderLead.choices.enumerated().compactMap { i, lead in ch_checked(Int32(534+i)) == 1 ? lead : nil })
        let given = ch_checked(524) == 1
        if given && !draft.givenByPriest && !settings.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.priestAttribution = settings.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        draft.givenByPriest = given
        if draft.original != nil { draft.scope = Self.editScopes[max(0, Int(ch_selected(541)))] }
        editor = draft
    }

    func saveEditor() throws {
        captureEditor()
        guard var draft = editor else { return }
        let name = draft.rule.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw RuleInputError(message: "Give the rule a name before saving.") }
        if draft.form.kind == .once {
            guard let day = CalendarDate(iso: draft.onceDate.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw RuleInputError(message: "Use a valid date in YYYY-MM-DD form.")
            }
            draft.form.onceDate = day
        }
        draft.rule.title = name
        draft.rule.note = draft.rule.note?.isEmpty == true ? nil : draft.rule.note
        let source = draft.givenByPriest && !draft.priestAttribution.isEmpty ? draft.priestAttribution : draft.rule.source ?? ""
        draft.rule.source = source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : source
        draft.rule.givenByPriest = draft.givenByPriest
        draft.rule.recurrence = draft.form.recurrence(fallback: selectedDate)
        draft.rule.timeOfDay = draft.hasTime ? TimeOfDay(hour: draft.hour, minute: draft.minute) : nil
        draft.rule.reminders = RuleReminders(enabled: draft.reminders, leads: draft.leads.isEmpty ? [.tenMinutes] : draft.leads.sorted())
        if let original = draft.original {
            try store.apply(EditPlanner().edit(rule: original, changes: draft.rule,
                            activations: try store.activations(ruleID: original.id), on: selectedDate, scope: draft.scope))
        } else {
            var plan = EditPlan()
            plan.newRules = [draft.rule]
            plan.newActivations = [Activation(ruleID: draft.rule.id, from: CalendarDate(Date(), in: .current))]
            try store.apply(plan)
        }
        try repairObservances()
        if draft.original == nil { customLibrary = true; page = .library }
        editor = nil; selectedRow = 0; notice = "\(name) saved."
    }

    func removeEditor() throws {
        captureEditor()
        guard let draft = editor, let original = draft.original else { return }
        try removeRule(original, scope: draft.scope)
        editor = nil; selectedRow = 0
    }
}
