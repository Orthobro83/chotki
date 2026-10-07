import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ChotkiCore

struct SettingsViewContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section("You")
            Text("My Name").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.horizontal, 14)
            TextField("First name or Baptismal name", text: Binding(get: { model.settings.displayName }, set: { value in model.update { $0.displayName = value } }))
                .textFieldStyle(.roundedBorder).padding(.horizontal, 14).padding(.bottom, 10)
            Text("My Spiritual Father's Name").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.horizontal, 14)
            TextField("Name", text: Binding(get: { model.settings.spiritualFatherName }, set: { value in model.update { $0.spiritualFatherName = value } }))
                .textFieldStyle(.roundedBorder).padding(.horizontal, 14)
            Button("Clear") { model.clearSpiritualFatherName() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(model.settings.spiritualFatherName.isEmpty ? Theme.faint : Theme.gold)
                .disabled(model.settings.spiritualFatherName.isEmpty)
                .padding(.horizontal, 14).padding(.top, 5)
                .accessibilityLabel("Clear Spiritual Father's Name")
            section("Your Church")
            jurisdictionPicker
            reckoningPicker
            practiceNotes

            section("The Calendar")
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

            clockStylePicker
            section("Reminders")
            toggleRow(
                "Notifications",
                help: "Turning these off silences the app. It does not change what is due, or how anything is counted.",
                isOn: model.settings.reminders.notificationsEnabled,
                set: { new in model.update { $0.reminders.notificationsEnabled = new } }
            )
            leadPicker

            section("Prayer Rope")
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

            section("Your Record")
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Button("Export a backup…") { exportBackup() }
                        .buttonStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gold)
                    Button("Restore from a backup…") { importBackup() }
                        .buttonStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.gold)
                }
                Text("A copy is also written automatically each day, in Application Support › Chotki › backups. Restoring merges into what is already here; nothing is removed.")
                    .font(.system(size: 13))
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
            HStack(spacing: 18) {
                Link("About Chotki", destination: URL(string: "https://chotki.app/about")!)
                Link("Privacy", destination: URL(string: "https://chotki.app/privacy")!)
            }
            .font(.system(size: 12)).foregroundStyle(Theme.faint)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            if let version = Bundle.main.object(forInfoDictionaryKey: "ChotkiDevelopmentVersion") as? String {
                Text("Version \(version)").font(.system(size: 12)).foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14).padding(.top, 8)
            }
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
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 4)
    }

    private var jurisdictionPicker: some View {
        Picker("", selection: Binding(
            get: { model.settings.namedChurch ?? "" },
            set: { name in
                model.update { $0.chooseChurch(named: name.isEmpty ? nil : name) }
            }
        )) {
            Text(Welcome.noChurchAffiliation).tag("")
            ForEach(Jurisdiction.known, id: \.name) { jurisdiction in
                Text(jurisdiction.name).tag(jurisdiction.name)
            }
        }
        .labelsHidden()
        .font(.system(size: 14))
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
        .font(.system(size: 14))
        .padding(.horizontal, 14).padding(.top, 6)
    }

    /// How times are written, everywhere they are written.
    ///
    /// Not decoration. On the 24-hour clock an evening rule set to the morning
    /// looks entirely correct — the list stays in order, so nothing draws the
    /// eye — and that is exactly how Evening prayers came to sit at half past
    /// ten in the morning here for several days.
    private var clockStylePicker: some View {
        HStack {
            Text("Clock")
                .font(.system(size: 14))
                .foregroundStyle(Theme.parchment)
            Spacer()
            Picker("", selection: Binding(
                get: { model.settings.clockStyle },
                set: { chosen in model.update { $0.clockStyle = chosen } }
            )) {
                ForEach(ClockStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .labelsHidden()
            .font(.system(size: 14))
            .frame(width: 170)
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }

    private var practiceNotes: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let note = model.settings.calendarDifferenceNote {
                // Stated, never corrected. Someone who has set this has a reason
                // the app does not know. Omitted when no church was named, so
                // the sentence cannot introduce one.
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.goldDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(model.settings.jurisdiction.practice.notes, id: \.self) { note in
                Text(note)
                    .font(.system(size: 13))
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
        _ title: String, value: Observance, set: @escaping @MainActor (Observance) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.parchment)
            Spacer()
            Picker("", selection: Binding(get: { value }, set: { newValue in MainActor.assumeIsolated { set(newValue) } })) {
                Text("Hidden").tag(Observance.hidden)
                Text("Shown").tag(Observance.shown)
                Text("Observed").tag(Observance.observed)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 116)
            .font(.system(size: 13))
        }
        .padding(.horizontal, 14).padding(.vertical, 3)
    }

    private var leadPicker: some View {
        HStack {
            Text("Warn me")
                .font(.system(size: 14))
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
            .font(.system(size: 13))
            .disabled(!model.settings.reminders.notificationsEnabled)
        }
        .padding(.horizontal, 14).padding(.vertical, 3)
    }

    private func toggleRow(
        _ title: String, help: String?, isOn: Bool, set: @escaping @MainActor (Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.parchment)
                Spacer()
                Toggle("", isOn: Binding(get: { isOn }, set: { newValue in MainActor.assumeIsolated { set(newValue) } }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            if let help {
                Text(help)
                    .font(.system(size: 13))
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
        ScrollView { SettingsViewContent(model: model).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).chotkiScrollContent() }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
            .softVerticalScrollEdges()
    }
}
