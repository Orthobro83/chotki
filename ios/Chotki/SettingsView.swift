import SwiftUI
import UniformTypeIdentifiers
import ChotkiCore

/// What someone has chosen, and what the app can honestly report about itself.
struct SettingsView_: View {
    @Bindable var model: Model
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        Form {
            Section("Your church") {
                Picker("Church", selection: Binding(
                    get: { model.settings.jurisdiction.name },
                    set: { name in
                        guard let chosen = Jurisdiction.known.first(where: { $0.name == name })
                        else { return }
                        model.update { $0.jurisdiction = chosen }
                    }
                )) {
                    ForEach(Jurisdiction.known, id: \.name) { Text($0.name).tag($0.name) }
                }

                // Set apart from the church on purpose. Picking a church sets
                // this to what that church usually keeps, which is right nearly
                // always — but a parish sometimes differs from the body it
                // belongs to, and the app should record what is actually kept.
                Picker("Calendar", selection: Binding(
                    get: { model.settings.jurisdiction.reckoning },
                    set: { chosen in model.update { $0.jurisdiction.reckoning = chosen } }
                )) {
                    ForEach(Reckoning.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }

                Text("Changing the calendar moves fasts and feasts by thirteen days from today. What you have already kept is untouched.")
                    .font(.footnote).foregroundStyle(Chotki.faint)

                ForEach(Array(model.settings.jurisdiction.practice.notes.enumerated()), id: \.offset) {
                    _, note in
                    Text(note).font(.footnote).foregroundStyle(Chotki.faint)
                }
            }

            Section("The calendar") {
                Picker("Fasting", selection: Binding(
                    get: { model.settings.observances.fasting },
                    set: { chosen in model.update { $0.observances.fasting = chosen } }
                )) {
                    ForEach(Observance.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                Picker("Feasts", selection: Binding(
                    get: { model.settings.observances.feasts },
                    set: { chosen in model.update { $0.observances.feasts = chosen } }
                )) {
                    ForEach(Observance.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                Text("Neither is assumed. People have health conditions and no parish within reach; neither is a failure.")
                    .font(.footnote).foregroundStyle(Chotki.faint)
            }

            Section("The clock") {
                Picker("How times are written", selection: Binding(
                    get: { model.settings.clockStyle },
                    set: { chosen in model.update { $0.clockStyle = chosen } }
                )) {
                    ForEach(ClockStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Show a consistency figure", isOn: Binding(
                    get: { model.settings.showConsistencyNumber },
                    set: { on in model.update { $0.showConsistencyNumber = on } }
                ))
            }

            Section("Your record") {
                Text("Your record is kept on this phone. Save a copy before you change phones, or if you want it somewhere of your own.")
                    .font(.footnote).foregroundStyle(Chotki.faint)

                Button("Save a copy of your record") { exporting = true }
                Button("Restore from a copy") { importing = true }
            }

            Section("Elsewhere") {
                NavigationLink("Glossary", value: Route.term(slug: nil))
                NavigationLink("The Psalter", value: Route.psalter)
                NavigationLink("The prayer rope", value: Route.rope)
            }

            Section("This is an alpha") {
                Text("The glossary, the prayers and the readings are awaiting a priest's review. Nothing here tells you what you must do; what you keep is settled with your priest or spiritual father.")
                    .font(.footnote).foregroundStyle(Chotki.faint)
                Text("Chotki is an independent project. It was inspired by The Brotherhood of the Narrow Path, but it is not sanctioned by, affiliated with, or endorsed by them, and nothing in it speaks for them.")
                    .font(.footnote).foregroundStyle(Chotki.faint)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Chotki.ground)
        .listRowBackground(Chotki.panel)
        .tint(Chotki.gold)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        // The system's own pickers, so no file permission is involved and the
        // person chooses where their record goes.
        .fileExporter(
            isPresented: $exporting,
            document: BackupFile(data: model.exportBackup() ?? Data()),
            contentType: .json,
            defaultFilename: "chotki-\(model.today.iso)"
        ) { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            // A security-scoped URL, which must be opened before it can be read
            // and closed afterwards, or the read silently returns nothing.
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) { model.restore(from: data) }
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
