import SwiftUI
import UniformTypeIdentifiers
import ChotkiCore

/// What someone has chosen.
///
/// The same groups as the phone: you, your church, the calendar, reminders,
/// the prayer rope, the record, then general. Reflections and the glossary
/// stay reachable from here. The glossary is not a tab.
struct SettingsView_: View {
    @Bindable var model: Model
    @Environment(\.pushRoute) private var pushRoute
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                group("You")
                panel {
                    nameField(
                        "My name",
                        value: model.settings.displayName,
                        hint: "First name or Baptismal name."
                    ) { next in model.update { $0.displayName = next } }
                    hairline
                    nameField(
                        "My spiritual father's name",
                        value: model.settings.spiritualFatherName,
                        hint: "Name"
                    ) { next in model.update { $0.spiritualFatherName = next } }
                    Button {
                        model.update { $0.spiritualFatherName = "" }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 13.5))
                            .foregroundStyle(model.settings.spiritualFatherName.isEmpty ? Chotki.faint : Chotki.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.settings.spiritualFatherName.isEmpty)
                    .accessibilityLabel("Clear spiritual father's name")
                }

                group("Your church")
                panel {
                    Menu {
                        Button(Welcome.noChurchAffiliation) {
                            model.update { $0.chooseChurch(named: nil) }
                        }
                        ForEach(Jurisdiction.known, id: \.name) { church in
                            Button(church.name) {
                                model.update { $0.chooseChurch(named: church.name) }
                            }
                        }
                    } label: {
                        valueRow(
                            "Church",
                            model.settings.namedChurch ?? Welcome.noChurchAffiliation
                        )
                    }
                    .accessibilityLabel("Church")
                    hairline
                    Button {
                        let next: Reckoning = model.settings.jurisdiction.reckoning == .julian
                            ? .revisedJulian : .julian
                        model.update { $0.jurisdiction.reckoning = next }
                    } label: {
                        valueRow("Reckoning", reckoningName(model.settings.jurisdiction.reckoning))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reckoning")
                }
                help("Changing the calendar moves fasts and feasts by thirteen days from today. What you have already kept is untouched.")

                group("The calendar")
                panel {
                    observanceRow("Fasting", model.settings.observances.fasting) { chosen in
                        model.update { $0.observances.fasting = chosen }
                    }
                    hairline
                    observanceRow("Feasts", model.settings.observances.feasts) { chosen in
                        model.update { $0.observances.feasts = chosen }
                    }
                    hairline
                    switchRow("Old-style dates", model.settings.showOldStyleDates) { on in
                        model.update { $0.showOldStyleDates = on }
                    }
                }
                help("Shown reports what the calendar marks. Observed is a rule you take on. Neither is assumed.")

                group("Reminders")
                panel {
                    switchRow("Notifications", model.settings.reminders.notificationsEnabled) { on in
                        model.update { $0.reminders.notificationsEnabled = on }
                        if on { Task { _ = await Reminders().requestAuthorization() } }
                    }
                    hairline
                    Menu {
                        ForEach(ReminderLead.choices, id: \.self) { lead in
                            Button(leadName(lead)) {
                                model.update { $0.reminders.defaultLead = lead }
                            }
                        }
                    } label: {
                        valueRow("Lead", leadName(model.settings.reminders.defaultLead))
                    }
                    .accessibilityLabel("Lead")
                }
                help("Turning these off silences the app. It does not change what is due, or how anything is counted.")

                group("Prayer rope")
                panel {
                    switchRow("Chime when a knot is complete", model.settings.chimeOnCompletion) { on in
                        model.update { $0.chimeOnCompletion = on }
                    }
                    hairline
                    switchRow("Click on each knot", model.settings.tickEachKnot) { on in
                        model.update { $0.tickEachKnot = on }
                    }
                }

                group("Your record")
                panel {
                    Button { exporting = true } label: {
                        valueRow("Export a backup", "JSON")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Export a backup")
                    hairline
                    Button { importing = true } label: {
                        valueRow("Restore from a backup", "Merges")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Restore from a backup")
                }

                group("General")
                panel {
                    switchRow("Consistency figure", model.settings.showConsistencyNumber) { on in
                        model.update { $0.showConsistencyNumber = on }
                    }
                    hairline
                    Button {
                        let next: ClockStyle = model.settings.clockStyle == .twentyFourHour
                            ? .twelveHour : .twentyFourHour
                        model.update { $0.clockStyle = next }
                    } label: {
                        valueRow("Clock", clockName(model.settings.clockStyle))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clock")
                }

                group("Also")
                panel {
                    Button { pushRoute(.reflections(weekday: nil)) } label: {
                        valueRow("Reflections", "")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reflections")
                    hairline
                    Button { pushRoute(.term(slug: nil)) } label: {
                        valueRow("Glossary", "")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Glossary")
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .background(Chotki.ground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $exporting,
            document: BackupFile(data: model.exportBackup() ?? Data()),
            contentType: .json,
            defaultFilename: "chotki-\(model.today.iso)"
        ) { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) { model.restore(from: data) }
        }
    }

    private func group(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(Chotki.faint)
            .padding(.leading, 6)
            .padding(.top, 8)
            .padding(.bottom, 3)
    }

    private func help(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Chotki.faint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
            .padding(.top, 4)
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var hairline: some View {
        Rectangle().fill(Chotki.lineSoft).frame(height: 1)
    }

    private func nameField(
        _ label: String, value: String, hint: String, onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13.5))
                .foregroundStyle(Chotki.parchment)
            TextField(hint, text: Binding(get: { value }, set: onChange))
                .font(Chotki.reading(15))
                .foregroundStyle(Chotki.parchment)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Chotki.ground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5))
                .foregroundStyle(Chotki.parchment)
            Spacer(minLength: 12)
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(Chotki.muted)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func switchRow(_ label: String, _ on: Bool, change: @escaping (Bool) -> Void) -> some View {
        Button { change(!on) } label: {
            HStack {
                Text(label)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Chotki.parchment)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 10)
                Capsule()
                    .fill(on ? Color(red: 0.239, green: 0.204, blue: 0.094) : Color(red: 0.165, green: 0.173, blue: 0.204))
                    .frame(width: 32, height: 18)
                    .overlay(alignment: on ? .trailing : .leading) {
                        Circle()
                            .fill(on ? Chotki.gold : Chotki.faint)
                            .padding(2)
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(on ? "On" : "Off")
    }

    private func observanceRow(
        _ label: String, _ selected: Observance, choose: @escaping (Observance) -> Void
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5))
                .foregroundStyle(Chotki.parchment)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                ForEach(Observance.allCases, id: \.self) { option in
                    let on = option == selected
                    Button { choose(option) } label: {
                        Text(option.rawValue.prefix(1).uppercased() + option.rawValue.dropFirst())
                            .font(.system(size: 11))
                            .foregroundStyle(on ? Chotki.gold : Chotki.faint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                on ? Color(red: 0.165, green: 0.149, blue: 0.094) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) \(option.rawValue.prefix(1).uppercased() + option.rawValue.dropFirst())")
                }
            }
            .padding(2)
            .background(Chotki.ground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func reckoningName(_ reckoning: Reckoning) -> String {
        switch reckoning {
        case .julian: return "Old calendar"
        case .revisedJulian: return "New calendar"
        }
    }

    private func clockName(_ style: ClockStyle) -> String {
        switch style {
        case .twentyFourHour: return "24-hour"
        case .twelveHour: return "12-hour"
        }
    }

    private func leadName(_ lead: ReminderLead) -> String {
        switch lead {
        case .atTheTime: return "At the time"
        case .tenMinutes: return "10 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .theEveningBefore: return "The evening before"
        }
    }
}

/// A backup on its way out through the system's file picker.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
