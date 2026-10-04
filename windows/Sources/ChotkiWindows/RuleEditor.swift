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
        ch_reset_home_scroll()
    }

    func renderEditor() {
        guard let draft = editor else { return }
        title(draft.original == nil ? "Write your own rule" : "Edit your rule", subtitle: "\(selectedDate.iso) · A rule is yours to change or set down.")
        let width=min(620,contentWidth)-44
        ch_home_begin(contentLeft,124,contentWidth,max(120,ch_height()-164),1100)
        var y:Int32=8
        func label(_ id:Int32,_ text:String) {
            let h=max(20,text.withCString { ch_measure_text($0,width,0) })
            control(id,0,text,14,y,width,h); ch_style(id,64); y += h+5
        }
        label(500,"What is it?")
        control(501,3,draft.rule.title,14,y,width,32); y += 48
        label(510,"How often?")
        let kinds=RecurrenceForm.Kind.allCases
        choice(511,kinds.map(\.rawValue),selected:kinds.firstIndex(of:draft.form.kind) ?? 1,x:14,y:y,width:width); y += 42
        switch draft.form.kind {
        case .weekly:
            let columns=max(1,min(7,Int(width/76)))
            for (i,day) in Weekday.allCases.enumerated() {
                checkbox(Int32(512+i),["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][i],checked:draft.form.weekdays.contains(day),
                         x:14+Int32(i%columns)*76,y:y+Int32(i/columns)*36,width:74)
            }
            y += Int32((7+columns-1)/columns)*36+8
        case .monthly:
            choice(512,(1...31).map { "Day \($0)" },selected:draft.form.monthDay-1,x:14,y:y,width:100)
            choice(513,["Use the last day","Skip a short month"],selected:draft.form.shortMonthPolicy == .skip ? 1 : 0,x:124,y:y,width:width-110); y += 42
        case .once:
            control(512,3,draft.onceDate,14,y,width,32); y += 38
            label(519,"Date: YYYY-MM-DD")
        case .season:
            choice(512,["Great Lent","Nativity Fast","Apostles' Fast","Dormition Fast"],selected:Self.fastingSeasons.firstIndex(of:draft.form.season) ?? 0,x:14,y:y,width:width); y += 42
        default: break
        }
        checkbox(530,"At a set time",checked:draft.hasTime,x:14,y:y,width:width); y += 38
        choice(531,(0...23).map { Format.hourLabel($0,settings.clockStyle) },selected:draft.hour,x:14,y:y,width:150)
        choice(532,(0...59).map { String(format:"%02d",$0) },selected:draft.minute,x:174,y:y,width:90)
        ch_enable(531,draft.hasTime ? 1 : 0); ch_enable(532,draft.hasTime ? 1 : 0); y += 40
        label(529,draft.hasTime ? "" : "It runs all day, and reminders are spread across the waking hours.")
        checkbox(533,"Remind me",checked:draft.reminders,x:14,y:y,width:width); y += 38
        let leadColumns=max(1,Int(width/190))
        for (i,lead) in ReminderLead.choices.enumerated() {
            checkbox(Int32(534+i),lead.label,checked:draft.leads.contains(lead),x:14+Int32(i%leadColumns)*190,y:y+Int32(i/leadColumns)*36,width:185)
            ch_enable(Int32(534+i),draft.reminders && draft.hasTime ? 1 : 0)
        }
        y += Int32((ReminderLead.choices.count+leadColumns-1)/leadColumns)*36+8
        label(539,draft.reminders ? "More than one is fine — an hour before to get ready, ten minutes before to go." : "Silencing a rule does not change whether it is due, or how it is counted.")
        label(520,"A note, if it helps")
        let note=(draft.rule.note ?? "").replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\n",with:"\r\n")
        control(521,8,note,14,y,width,66); y += 82
        label(522,"Who suggested it?")
        let hasAttribution=draft.givenByPriest && !draft.priestAttribution.isEmpty
        control(523,3,hasAttribution ? draft.priestAttribution : draft.rule.source ?? "",14,y,width,32)
        ch_enable(523,hasAttribution ? 0 : 1); y += 38
        let father=draft.priestAttribution.isEmpty ? settings.spiritualFatherName : draft.priestAttribution
        checkbox(524,father.isEmpty ? "Given to me by my priest" : "Given to me by \(father)",checked:draft.givenByPriest,x:14,y:y,width:width); y += 42
        label(525,"Months from now this is how you will remember where a rule came from.")
        if draft.original != nil {
            label(540,"Apply the change to")
            choice(541,["Just this day","This day and after","The whole rule"],selected:Self.editScopes.firstIndex(of:draft.scope) ?? 2,x:14,y:y,width:width); y += 42
            control(552,18,"Remove in This Scope",14,y,width,32); y += 42
        }
        control(550,18,"Save Rule",14,y,130,32); ch_style(550,128)
        control(551,18,"Cancel",164,y,100,32); y += 42
        ch_update(202,"")
        label(553,notice)
        ch_home_content(y+20)
        ch_home_end()
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
