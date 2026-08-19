import SwiftUI
import ChotkiCore

/// Adding and editing a rule. A rule written here and one taken from the
/// library are the same kind of thing, with the same fields.
struct RuleEditorView: View {
    @ObservedObject var model: AppModel
    let ruleID: UUID?

    @State private var title = ""
    @State private var note = ""
    @State private var source = ""
    @State private var kind: Kind = .daily
    @State private var weekdays: Set<Weekday> = [.sunday]
    @State private var monthDay = 1
    @State private var hasTime = false
    @State private var hour = 6
    @State private var minute = 30
    @State private var remindersOn = true
    @State private var leads: Set<ReminderLead> = [.tenMinutes]
    @State private var loaded = false

    enum Kind: String, CaseIterable, Hashable {
        case daily = "Every day"
        case weekly = "Certain weekdays"
        case monthly = "Once a month"
        case fastDays = "Fast days"
        case greatFeasts = "Great feasts"
    }

    private var existing: Rule? {
        ruleID.flatMap { id in model.rules.first { $0.id == id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                field("What is it?") {
                    TextField("Morning prayers", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.parchment)
                }

                field("How often?") {
                    Picker("", selection: $kind) {
                        ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).font(.system(size: 11))
                }

                if kind == .weekly { weekdayPicker }
                if kind == .monthly { monthDayPicker }

                timeRow
                remindersSection

                field("A note, if it helps") {
                    TextField("Start with the Trisagion", text: $note)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.parchment)
                }

                field("Who suggested it?") {
                    TextField("my godfather", text: $source)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.parchment)
                }
                Text("Months from now this is how you will remember where a rule came from.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)

                Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 4)
                actions
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .frame(maxHeight: 520)
        .scrollContentBackgroundHidden()
        .onAppear(perform: load)
    }

    // MARK: pieces

    private func field<Content: View>(
        _ label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
            content()
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases, id: \.self) { day in
                Button {
                    if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(shortName(day))
                        .font(.system(size: 11))
                        .frame(width: 30, height: 22)
                        .foregroundStyle(weekdays.contains(day) ? Theme.ground : Theme.muted)
                        .background {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(weekdays.contains(day) ? Theme.gold : Theme.panel)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthDayPicker: some View {
        HStack {
            Text("On day")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
            Picker("", selection: $monthDay) {
                ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
            }
            .labelsHidden().frame(width: 70).font(.system(size: 11))
            Text("— a short month uses its last day")
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
        }
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $hasTime) {
                Text("At a set time")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.parchment)
            }
            .toggleStyle(.switch).controlSize(.mini)

            if hasTime {
                HStack(spacing: 4) {
                    Picker("", selection: $hour) {
                        ForEach(0...23, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }.labelsHidden().frame(width: 60)
                    Text(":").foregroundStyle(Theme.muted)
                    Picker("", selection: $minute) {
                        ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }.labelsHidden().frame(width: 60)
                }
                .font(.system(size: 11))
            } else {
                Text("Without a time it is simply due today, and reminders are spread across the day.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $remindersOn) {
                Text("Remind me")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.parchment)
            }
            .toggleStyle(.switch).controlSize(.mini)

            if remindersOn && hasTime {
                FlowLeads(selected: $leads)
                Text("More than one is fine — an hour before to get ready, ten minutes before to go.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !remindersOn {
                Text("Silencing a rule does not change whether it is due, or how it is counted.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("Save") { save() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.faint : Theme.gold)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()

            if let rule = existing {
                if model.isPaused(rule) {
                    Button("Resume") { model.resume(rule); model.screen = .main }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.muted)
                } else {
                    Button("Pause") { model.standDown(rule); model.screen = .main }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Menu("Remove") {
                    Button("Just this day") { model.delete(rule, scope: .thisDay); model.screen = .main }
                    Button("This day and after") { model.delete(rule, scope: .thisAndFuture); model.screen = .main }
                    Button("The whole rule") { model.delete(rule, scope: .wholeSeries); model.screen = .main }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 84)
                .font(.system(size: 12))
            }
        }
    }

    // MARK: loading and saving

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let rule = existing else { return }
        title = rule.title
        note = rule.note ?? ""
        source = rule.source ?? ""
        switch rule.recurrence {
        case .daily, .once: kind = .daily
        case .weekly(let days): kind = .weekly; weekdays = days
        case .monthly(let day, _): kind = .monthly; monthDay = day
        case .liturgical(let trigger):
            kind = trigger == .greatFeast ? .greatFeasts : .fastDays
        }
        if let time = rule.timeOfDay {
            hasTime = true; hour = time.hour; minute = time.minute
        }
        remindersOn = rule.effectiveReminders.enabled
        leads = Set(rule.effectiveReminders.leads)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let recurrence: Recurrence
        switch kind {
        case .daily: recurrence = .daily
        case .weekly: recurrence = .weekly(days: weekdays.isEmpty ? [.sunday] : weekdays)
        case .monthly: recurrence = .monthly(day: monthDay)
        case .fastDays: recurrence = .liturgical(.fastDay)
        case .greatFeasts: recurrence = .liturgical(.greatFeast)
        }

        var rule = existing ?? Rule(title: trimmed, recurrence: recurrence)
        rule.title = trimmed
        rule.note = note.isEmpty ? nil : note
        rule.source = source.isEmpty ? nil : source
        rule.recurrence = recurrence
        rule.timeOfDay = hasTime ? TimeOfDay(hour: hour, minute: minute) : nil
        rule.reminders = RuleReminders(
            enabled: remindersOn,
            leads: leads.isEmpty ? [.tenMinutes] : leads.sorted()
        )

        model.save(rule, isNew: existing == nil)
        model.screen = .main
    }

    private func shortName(_ day: Weekday) -> String {
        ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][day.rawValue - 1]
    }
}

struct FlowLeads: View {
    @Binding var selected: Set<ReminderLead>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(chunks, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { lead in
                        Button {
                            if selected.contains(lead) { selected.remove(lead) } else { selected.insert(lead) }
                        } label: {
                            Text(short(lead))
                                .font(.system(size: 10))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .foregroundStyle(selected.contains(lead) ? Theme.ground : Theme.muted)
                                .background {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(selected.contains(lead) ? Theme.gold : Theme.panel)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var chunks: [[ReminderLead]] {
        let all = ReminderLead.choices
        return [Array(all.prefix(3)), Array(all.dropFirst(3))]
    }

    private func short(_ lead: ReminderLead) -> String {
        switch lead {
        case .atTheTime: return "at the time"
        case .tenMinutes: return "10 min"
        case .thirtyMinutes: return "30 min"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .theEveningBefore: return "evening before"
        }
    }
}
