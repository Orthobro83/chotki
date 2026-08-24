import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ChotkiCore

struct SettingsViewContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("Your church")
            jurisdictionPicker
            reckoningPicker
            practiceNotes

            section("The calendar")
            observanceRow(
                "Fasting",
                value: model.settings.observances.fasting,
                set: { new in model.update { $0.observances.fasting = new } }
            )
            observanceRow(
                "Feasts",
                value: model.settings.observances.feasts,
                set: { new in model.update { $0.observances.feasts = new } }
            )
            toggleRow(
                "Show old-style dates",
                help: "Shows the Julian date alongside the civil one.",
                isOn: model.settings.showOldStyleDates,
                set: { new in model.update { $0.showOldStyleDates = new } }
            )

            section("Reminders")
            toggleRow(
                "Notifications",
                help: "Turning these off silences the app. It does not change what is due, or how anything is counted.",
                isOn: model.settings.reminders.notificationsEnabled,
                set: { new in model.update { $0.reminders.notificationsEnabled = new } }
            )
            leadPicker

            section("Prayer rope")
            toggleRow(
                "Chime when a knot is complete",
                help: nil,
                isOn: model.settings.chimeOnCompletion,
                set: { new in model.update { $0.chimeOnCompletion = new } }
            )
            toggleRow(
                "Click on each knot",
                help: "A soft click confirms a press landed, for praying with your eyes closed.",
                isOn: model.settings.tickEachKnot,
                set: { new in model.update { $0.tickEachKnot = new } }
            )

            section("Your record")
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Button("Export a backup…") { exportBackup() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gold)
                    Button("Restore from a backup…") { importBackup() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gold)
                }
                Text("A copy is also written automatically each day, in Application Support › Chotki › backups. Restoring merges into what is already here; nothing is removed.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14).padding(.vertical, 4)

            section("General")
            toggleRow(
                "Show in the Dock",
                help: "With this off, Chotki lives only in the menu bar. The menu bar icon is there either way.",
                isOn: model.settings.showInDock,
                set: { new in model.update { $0.showInDock = new } }
            )
            toggleRow(
                "Open at login",
                help: nil,
                isOn: model.settings.launchAtLogin,
                set: { new in model.update { $0.launchAtLogin = new } }
            )
            toggleRow(
                "Show the consistency figure",
                help: "With this off, progress is reported in words only.",
                isOn: model.settings.showConsistencyNumber,
                set: { new in model.update { $0.showConsistencyNumber = new } }
            )
        }
        .padding(.bottom, 14)
    
    }

    // MARK: backup

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.title = "Export a backup"
        panel.allowedContentTypes = [.json]
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withFullDate]
        panel.nameFieldStringValue = "chotki-\(stamp.string(from: Date())).json"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            model.exportBackup(to: url)
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "Restore from a backup"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            model.importBackup(from: url)
        }
    }

    // MARK: pieces

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 4)
    }

    private var jurisdictionPicker: some View {
        Picker("", selection: Binding(
            get: { model.settings.jurisdiction.name },
            set: { name in
                guard let chosen = Jurisdiction.known.first(where: { $0.name == name }) else { return }
                model.update { $0.jurisdiction = chosen }
            }
        )) {
            ForEach(Jurisdiction.known, id: \.name) { jurisdiction in
                Text(jurisdiction.name).tag(jurisdiction.name)
            }
        }
        .labelsHidden()
        .font(.system(size: 12))
        .padding(.horizontal, 14)
    }

    /// The calendar, set apart from the jurisdiction.
    ///
    /// Picking a church sets this to whatever that church usually keeps, and
    /// that is right nearly always. But jurisdictions are not uniform — a parish
    /// sometimes keeps a different calendar from the body it belongs to — and
    /// the app should record what is actually kept rather than what is usual.
    /// It is the setting that decides which days the fasts and feasts fall on,
    /// so getting it wrong moves a fortnight of someone's year.
    private var reckoningPicker: some View {
        Picker("", selection: Binding(
            get: { model.settings.jurisdiction.reckoning },
            set: { chosen in model.update { $0.jurisdiction.reckoning = chosen } }
        )) {
            ForEach(Reckoning.allCases, id: \.self) { reckoning in
                Text(reckoning.displayName).tag(reckoning)
            }
        }
        .labelsHidden()
        .font(.system(size: 12))
        .padding(.horizontal, 14).padding(.top, 6)
    }

    private var practiceNotes: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.settings.jurisdiction.reckoningDiffersFromJurisdiction,
               let usual = model.settings.jurisdiction.asShipped {
                // Stated, never corrected. Someone who has set this has a reason
                // the app does not know.
                Text("\(usual.name) usually keeps the \(usual.reckoning.displayName).")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.goldDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(model.settings.jurisdiction.practice.notes, id: \.self) { note in
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14).padding(.top, 6)
    }

    /// Three plain options, with no prompt asking why. Someone who cannot fast
    /// for health reasons, or has no parish within reach, is not asked to
    /// explain themselves to an app.
    // Swift 6 warns that these setters are not Sendable when handed to a
    // Binding. Annotating them @Sendable breaks the call sites, which legitimately
    // capture the main-actor model, and @MainActor crashes the 6.1.2 compiler
    // outright. The closures only ever run on the main actor, so the warning is
    // benign and left alone deliberately.
    private func observanceRow(
        _ title: String, value: Observance, set: @escaping (Observance) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.parchment)
            Spacer()
            Picker("", selection: Binding(get: { value }, set: set)) {
                Text("Hidden").tag(Observance.hidden)
                Text("Shown").tag(Observance.shown)
                Text("Observed").tag(Observance.observed)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 116)
            .font(.system(size: 11))
        }
        .padding(.horizontal, 14).padding(.vertical, 3)
    }

    private var leadPicker: some View {
        HStack {
            Text("Warn me")
                .font(.system(size: 12))
                .foregroundStyle(
                    model.settings.reminders.notificationsEnabled ? Theme.parchment : Theme.faint
                )
            Spacer()
            Picker("", selection: Binding(
                get: { model.settings.reminders.defaultLead },
                set: { new in model.update { $0.reminders.defaultLead = new } }
            )) {
                ForEach(ReminderLead.choices, id: \.self) { lead in
                    Text(lead.label).tag(lead)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 150)
            .font(.system(size: 11))
            .disabled(!model.settings.reminders.notificationsEnabled)
        }
        .padding(.horizontal, 14).padding(.vertical, 3)
    }

    private func toggleRow(
        _ title: String, help: String?, isOn: Bool, set: @escaping (Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.parchment)
                Spacer()
                Toggle("", isOn: Binding(get: { isOn }, set: set))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            if let help {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }
}

/// Scroll chrome only. Content is `SettingsViewContent` so it can be rendered
/// directly — ImageRenderer does not draw ScrollView contents.
struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView { SettingsViewContent(model: model) }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
    }
}
