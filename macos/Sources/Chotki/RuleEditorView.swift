import SwiftUI
import ChotkiCore

/// Adding and editing a rule. A rule written here and one taken from the
/// library are the same kind of thing, with the same fields.
struct RuleEditorView: View {
    @ObservedObject var model: AppModel
    let ruleID: UUID?
    /// How this editor goes away. The popover pops a screen; the window closes
    /// a sheet. The editor should not need to know which.
    let dismiss: () -> Void

    @State private var title = ""
    @State private var note = ""
    @State private var source = ""
    @State private var form = RecurrenceForm()
    @State private var hasTime = false
    @State private var hour = 6
    @State private var minute = 30
    @State private var remindersOn = true
    @State private var leads: Set<ReminderLead> = [.tenMinutes]
    @State private var loaded = false
    @State private var givenByPriest = false
    @State private var priestAttribution = ""


    private var existing: Rule? {
        ruleID.flatMap { id in model.rules.first { $0.id == id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                field("What is it?") {
                    TextField("Morning prayers", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.parchment)
                }

                field("How often?") {
                    Picker("", selection: $form.kind) {
                        ForEach(RecurrenceForm.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).font(.system(size: 13))
                }

                if form.kind == .weekly { weekdayPicker }
                if form.kind == .monthly { monthDayPicker }
                if form.kind == .season { seasonPicker }
                if form.kind == .once { onceRow }

                timeRow
                remindersSection

                field("A note, if it helps") {
                    TextField("Start with the Trisagion", text: $note)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.parchment)
                }

                suggesterField
                Text("Months from now this is how you will remember where a rule came from.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)

                Rectangle().fill(Theme.line).frame(height: 1).padding(.top, 4)
                actions
            }
            .padding(.horizontal, 24).padding(.vertical, 20)
        }
        .frame(maxHeight: .infinity)
        .scrollContentBackgroundHidden()
        .softVerticalScrollEdges()
        .onAppear(perform: load)
    }

    // MARK: pieces

    private var suggesterField: some View {
        let father = model.settings.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Who suggested it?").font(.system(size: 13)).foregroundStyle(Theme.muted)
            if father.isEmpty || !givenByPriest {
                suggestedByInput
            }
            if !father.isEmpty {
                Toggle("Given to me by \(givenByPriest ? (priestAttribution.isEmpty ? father : priestAttribution) : father)", isOn: Binding(
                    get: { givenByPriest },
                    set: { selected in
                        givenByPriest = selected
                        if selected { priestAttribution = father }
                    }
                ))
                .foregroundStyle(Theme.parchment).toggleStyle(.checkbox)
            }
        }
    }

    private var suggestedByInput: some View {
        TextField("Suggested by", text: $source)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(Theme.parchment)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 5))
    }

    private func field<Content: View>(
        _ label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 13))
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
                    if form.weekdays.contains(day) {
                        form.weekdays.remove(day)
                    } else {
                        form.weekdays.insert(day)
                    }
                } label: {
                    Text(shortName(day))
                        .font(.system(size: 13))
                        .frame(width: 30, height: 22)
                        .foregroundStyle(form.weekdays.contains(day) ? Theme.ground : Theme.muted)
                        .background {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(form.weekdays.contains(day) ? Theme.gold : Theme.panel)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var seasonPicker: some View {
        HStack {
            Text("Which season")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            Picker("", selection: $form.season) {
                Text("Great Lent").tag(FastingSeason.greatLent)
                Text("Nativity Fast").tag(FastingSeason.nativityFast)
                Text("Apostles' Fast").tag(FastingSeason.apostlesFast)
                Text("Dormition Fast").tag(FastingSeason.dormitionFast)
            }
            .labelsHidden().frame(width: 150).font(.system(size: 13))
        }
    }

    private var onceRow: some View {
        Text(form.onceDate.map { "On \($0.iso)." } ?? "On the selected day.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.faint)
    }

    private var monthDayPicker: some View {
        HStack {
            Text("On day")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            Picker("", selection: $form.monthDay) {
                ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
            }
            .labelsHidden().frame(width: 70).font(.system(size: 13))
            Text("— a short month uses its last day")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
        }
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $hasTime) {
                Text("At a set time")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.parchment)
            }
            .toggleStyle(.switch).controlSize(.mini)

            if hasTime {
                HStack(spacing: 4) {
                    Picker("", selection: $hour) {
                        // Labelled in whichever clock the person reads, so an
                        // evening rule cannot be set to the morning by picking
                        // the number that looks right.
                        ForEach(0...23, id: \.self) {
                            Text(Format.hourLabel($0, model.settings.clockStyle)).tag($0)
                        }
                    }.labelsHidden().frame(width: model.settings.clockStyle == .twelveHour ? 76 : 60)
                    Text(":").foregroundStyle(Theme.muted)
                    Picker("", selection: $minute) {
                        ForEach(Array(0...59), id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }.labelsHidden().frame(width: 60)
                }
                .font(.system(size: 13))
            } else {
                Text("It runs all day, and reminders are spread across the waking hours.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $remindersOn) {
                Text("Remind me")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.parchment)
            }
            .toggleStyle(.switch).controlSize(.mini)

            if remindersOn && hasTime {
                FlowLeads(selected: $leads)
                Text("More than one is fine — an hour before to get ready, ten minutes before to go.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !remindersOn {
                Text("Silencing a rule does not change whether it is due, or how it is counted.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        HStack {
            Button("Save") { save() }
                .buttonStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.faint : Theme.gold)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()

            if let rule = existing {
                if model.isPaused(rule) {
                    Button("Resume") { model.resume(rule); dismiss() }
                        .buttonStyle(.plain).font(.system(size: 14)).foregroundStyle(Theme.muted)
                } else {
                    Button("Pause") { model.standDown(rule); dismiss() }
                        .buttonStyle(.plain).font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Menu("Remove") {
                    Button("Just this day") { model.delete(rule, scope: .thisDay); dismiss() }
                    Button("This day and after") { model.delete(rule, scope: .thisAndFuture); dismiss() }
                    Button("The whole rule") { model.delete(rule, scope: .wholeSeries); dismiss() }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 84)
                .font(.system(size: 14))
            }
        }
    }

    // MARK: loading and saving

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let rule = existing ?? model.editorDraft else { return }
        givenByPriest = rule.givenByPriest == true
        title = rule.title
        note = rule.note ?? ""
        source = rule.source ?? ""
        let father = model.settings.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines)
        if givenByPriest {
            priestAttribution = source.isEmpty || source == "the library" ? father : source
        }
        form = RecurrenceForm(rule.recurrence)
        if let time = rule.timeOfDay {
            hasTime = true; hour = time.hour; minute = time.minute
        }
        remindersOn = rule.effectiveReminders.enabled
        leads = Set(rule.effectiveReminders.leads)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let recurrence = form.recurrence(fallback: model.selectedDate)

        var rule = existing ?? model.editorDraft ?? Rule(title: trimmed, recurrence: recurrence)
        let father = model.settings.spiritualFatherName.trimmingCharacters(in: .whitespacesAndNewlines)
        let retainsOldAttribution = father.isEmpty && givenByPriest && source == priestAttribution
        rule.givenByPriest = !father.isEmpty ? givenByPriest : retainsOldAttribution
        rule.title = trimmed
        rule.note = note.isEmpty ? nil : note
        let selectedSource = givenByPriest && !father.isEmpty ? priestAttribution : source
        rule.source = selectedSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : selectedSource
        rule.recurrence = recurrence
        rule.timeOfDay = hasTime ? TimeOfDay(hour: hour, minute: minute) : nil
        rule.reminders = RuleReminders(
            enabled: remindersOn,
            leads: leads.isEmpty ? [.tenMinutes] : leads.sorted()
        )

        model.save(rule, isNew: existing == nil)
        dismiss()
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
                                .font(.system(size: 12))
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
