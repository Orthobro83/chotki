import SwiftUI
import ChotkiCore

/// Writing a rule, or changing one.
///
/// Android shipped without this offering reminders at all — a rule took
/// whatever the library decided and there was no way to change it, so the phone
/// testing the port could not test the thing the port was for. Everything a
/// rule holds is editable here.
struct RuleEditor: View {
    @Bindable var model: Model
    /// Nil when writing a new one; the rule itself when changing an existing.
    var existing: Rule?
    /// Filled in from a template, not yet saved.
    var startingFrom: Rule?

    @Environment(\.dismiss) private var dismiss

    private var filling: Rule? { existing ?? startingFrom }

    @State private var title = ""
    @State private var note = ""
    @State private var source = ""
    @State private var form = RecurrenceForm()
    @State private var hasTime = false
    @State private var time = Date()
    @State private var remind = true
    @State private var leads: Set<ReminderLead> = [.tenMinutes]
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextField("Write something…", text: $title)
                    .accessibilityLabel("Rule title")
            } header: { Text("What is it?") }

            Section {
                TextField("Write something…", text: $note)
                TextField("Write something…", text: $source)
            } header: { Text("A note, and where it came from") } footer: {
                // Rules arrive from other people over months and their origin
                // matters later. The hint is neutral rather than an example: an
                // example that contradicts the rule being taken on — "before
                // sleep" under Morning prayers — reads as inattention.
                Text("Both optional.")
            }

            Section("How often") {
                Picker("How often", selection: $form.kind) {
                    ForEach(RecurrenceForm.Kind.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                if form.kind == .weekly {
                    WeekdayPicker(chosen: $form.weekdays)
                }
            }

            Section("At a set time") {
                Toggle("At a set time", isOn: $hasTime)
                if hasTime {
                    // The platform's own picker, which cannot be ambiguous
                    // about morning and evening — on Android a list of bare
                    // hours let an evening rule be set to the morning, and
                    // then could not be scrolled past the ninth at all.
                    DatePicker("Due at", selection: $time, displayedComponents: .hourAndMinute)
                } else {
                    Text("It runs all day, and reminders are spread across the waking hours.")
                        .font(.footnote).foregroundStyle(Chotki.faint)
                }
            }

            Section("Remind me") {
                Toggle("Remind me", isOn: $remind)
                if remind {
                    ForEach(ReminderLead.choices, id: \.self) { lead in
                        Button {
                            if leads.contains(lead) { leads.remove(lead) } else { leads.insert(lead) }
                        } label: {
                            HStack {
                                Text(lead.label).foregroundStyle(Chotki.parchment)
                                Spacer()
                                if leads.contains(lead) {
                                    Image(systemName: "checkmark").foregroundStyle(Chotki.gold)
                                }
                            }
                        }
                        .accessibilityLabel("Remind \(lead.label)")
                    }
                } else {
                    Text("This rule will not buzz. It is still due, and still counted.")
                        .font(.footnote).foregroundStyle(Chotki.faint)
                }
            }

            if let existing {
                Section {
                    Button("Remove from your rule", role: .destructive) {
                        model.remove(existing); dismiss()
                    }
                    Text("Everything it has kept stays in the record, and it can be taken up again from the library.")
                        .font(.footnote).foregroundStyle(Chotki.faint)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Chotki.ground)
        .tint(Chotki.gold)
        .navigationTitle(existing != nil ? "Edit this rule" : (startingFrom != nil ? "Take this on" : "Write your own rule"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(existing == nil ? "Take it on" : "Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Save the rule")
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            guard !loaded else { return }
            loaded = true
            fill()
        }
    }

    /// From whichever rule is being filled in — reading only `existing` dropped
    /// the template's own time on Android, so Morning prayers arrived at half
    /// past six and the editor said it ran all day.
    private func fill() {
        guard let filling else { return }
        title = filling.title
        note = filling.note ?? ""
        source = filling.source ?? ""
        form = RecurrenceForm(filling.recurrence)
        hasTime = filling.timeOfDay != nil
        if let clock = filling.timeOfDay {
            time = Calendar.current.date(
                bySettingHour: clock.hour, minute: clock.minute, second: 0, of: Date()
            ) ?? Date()
        }
        remind = filling.effectiveReminders.enabled
        leads = Set(filling.effectiveReminders.leads)
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        model.save(
            (existing ?? startingFrom ?? Rule(title: title, recurrence: .daily)),
            title: title.trimmingCharacters(in: .whitespaces),
            note: note.isEmpty ? nil : note,
            source: source.isEmpty ? nil : source,
            recurrence: form.recurrence(fallback: model.today),
            timeOfDay: hasTime ? TimeOfDay(hour: parts.hour ?? 6, minute: parts.minute ?? 30) : nil,
            reminders: RuleReminders(
                enabled: remind,
                leads: leads.isEmpty
                    ? RuleReminders.default.leads
                    // ReminderLead is Comparable in core, and its order is
                    // fire order rather than the order they are offered in.
                    : Array(leads).sorted()
            )
        )
        dismiss()
    }
}

private struct WeekdayPicker: View {
    @Binding var chosen: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let on = chosen.contains(day)
                Button {
                    if on { chosen.remove(day) } else { chosen.insert(day) }
                } label: {
                    Text(String(describing: day).prefix(3).capitalized)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(on ? Chotki.gold : Chotki.panel, in: Capsule())
                        .foregroundStyle(on ? Chotki.ground : Chotki.muted)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
