import Foundation
import SwiftUI
import ChotkiCore

/// Where the popover currently is. A menu bar window handles sheets badly, so
/// navigation is an explicit stack of screens inside the popover instead.
enum Screen: Hashable {
    case main
    case library
    case settings
    case glossary(String?)
    case editor(UUID?)
    case prayerRope
    case prayers(UUID)
}

@MainActor
final class AppModel: ObservableObject {

    // MARK: state

    @Published private(set) var settings: AppSettings
    @Published private(set) var rules: [Rule] = []
    @Published private(set) var activations: [Activation] = []
    @Published private(set) var occurrences: [Occurrence] = []
    @Published var selectedDate: CalendarDate
    @Published var visibleMonth: CalendarDate
    @Published var screen: Screen = .main
    @Published private(set) var loadError: String?
    /// A neutral note, not an error. Cleared when the popover reopens.
    @Published var notice: String?
    /// Shown briefly when the last thing on a day is settled.
    @Published private(set) var thanksgiving: String?
    private var thanksgivingTask: Task<Void, Never>?
    /// Set by the app delegate. The model asks for a window; it does not know
    /// what a window is.
    var openDetachedReport: (() -> Void)?
    var openMainWindow: (() -> Void)?
    /// Called when the Dock setting changes, so the delegate can switch the
    /// activation policy. The model still knows nothing about windows.
    var onDockPresenceChanged: ((Bool) -> Void)?

    let store: any Store
    let liturgical: LiturgicalService
    private let storage: SettingsStorage
    private let notifier: any Notifier
    private let launchAtLogin: any LaunchAtLogin
    private var driver: ReminderDriver?

    var today: CalendarDate { CalendarDate(Date(), in: .current) }

    // MARK: setup

    init(
        store: any Store,
        notifier: any Notifier,
        launchAtLogin: any LaunchAtLogin,
        storage: SettingsStorage = SettingsStorage(),
        startsReminders: Bool = true,
        writesBackups: Bool = true
    ) {
        self.store = store
        self.notifier = notifier
        self.launchAtLogin = launchAtLogin
        self.storage = storage
        // Settings live in the store. Anything left in the old preferences
        // location is carried across once and then ignored.
        let loaded = (try? store.loadSettings()) ?? storage.migratedSettings() ?? .default
        try? store.saveSettings(loaded)
        self.settings = loaded
        self.liturgical = LiturgicalService(store: store, jurisdiction: loaded.jurisdiction)
        let now = CalendarDate(Date(), in: .current)
        self.selectedDate = now
        self.visibleMonth = now

        // Registering is per-bundle-path. Moving the app — from the external
        // drive to /Applications, say — leaves the setting on while the actual
        // registration points at the old location, so re-assert it from here.
        if loaded.launchAtLogin && !launchAtLogin.isEnabled {
            try? launchAtLogin.setEnabled(true)
        }

        reload()
        if writesBackups { writeAutomaticBackup() }
        if startsReminders { startDriver() }
        listenForActions()
        Task { await refreshLiturgical() }
    }

    /// The decisions live in core; this is the current snapshot to ask.
    private var practice: Practice {
        Practice(
            rules: rules, activations: activations, occurrences: occurrences,
            settings: settings, liturgical: liturgical
        )
    }

    private var engine: RecurrenceEngine {
        RecurrenceEngine(liturgical: liturgical, observances: settings.observances)
    }

    private var scheduler: Scheduler {
        Scheduler(engine: engine, policy: settings.reminders, timeZone: .current)
    }

    // MARK: loading

    func reload() {
        do {
            rules = try store.rules(includeArchived: false)
            activations = try store.activations(ruleID: nil)
            occurrences = try store.occurrences(ruleID: nil, from: nil, through: nil)
            loadError = nil
        } catch {
            loadError = "Could not read your rules. \(error)"
        }
        reconcileObservances()
        reconcileFirstRun()
        rearmReminders()
    }

    /// Turns on any observance a rule depends on. What is needed is decided in
    /// core; this only writes the result.
    private func reconcileObservances() {
        let wanted = practice.observancesNeeded()
        guard !wanted.isEmpty else { return }
        var updated = settings
        for trigger in wanted { updated.observances.observe(trigger) }
        settings = updated
        persist(updated)
    }

    private func reconcileFirstRun() {
        guard practice.shouldMarkFirstRunComplete else { return }
        var updated = settings
        updated.hasCompletedFirstRun = true
        settings = updated
        persist(updated)
    }

    /// A setting that fails to save reverts on the next launch without anyone
    /// knowing — which is precisely how the observance bug went unnoticed. Say
    /// so instead of swallowing it.
    private func persist(_ settings: AppSettings) {
        do {
            try store.saveSettings(settings)
        } catch {
            loadError = "Could not save that setting, so it may not survive a restart. \(error)"
        }
    }

    func refreshLiturgical() async {
        try? liturgical.loadSnapshot(around: today)
        _ = await liturgical.refresh(from: today.adding(days: -1), days: 16)
        objectWillChange.send()
    }

    // MARK: what is due

    func entries(on date: CalendarDate) -> [DayEntry] { practice.entries(on: date) }

    func isPaused(_ rule: Rule) -> Bool { practice.isPaused(rule) }

    /// Every rule for the day accounted for, with at least one actually kept.
    func dayIsSettled(_ date: CalendarDate) -> Bool { practice.isSettled(on: date) }

    /// The report over a trailing window. Recomputed on demand rather than
    /// cached: it is cheap, and a stale figure would be worse than none.
    var progressThrough: CalendarDate { Practice.progressThrough(today: today) }

    func report(days: Int = 30) -> ProgressReport {
        practice.report(days: days, today: today)
    }

    // MARK: acting

    func setStatus(_ status: OccurrenceStatus, for rule: Rule, on date: CalendarDate) {
        let kept = status == .completed || status == .completedLate
        do {
            try store.save(Occurrence(
                ruleID: rule.id, date: date, status: status,
                completedAt: kept ? Date() : nil
            ))
            // Settling a day silences the rest of it immediately.
            let ids = scheduler.cancellationIDs(
                ruleID: rule.id, date: date, rules: rules, activations: activations
            )
            Task { await notifier.cancel(ids: ids) }
            reload()
        } catch {
            loadError = "Could not save that. \(error)"
        }
    }

    /// Marks kept, or un-marks it if it was already kept.
    /// Ticking says "I kept this", whenever the box happens to be ticked.
    ///
    /// It deliberately does not infer lateness from when the box was ticked.
    /// Someone who kept a rule on the day and only remembered to record it
    /// afterwards has not done anything late, and the app cannot tell the
    /// difference — so it trusts them. Recording something as kept late is a
    /// separate, deliberate choice.
    func toggleKept(_ entry: DayEntry) {
        // Nothing was asked of anyone today, so there is nothing to record.
        guard !entry.isDispensed else { return }
        if entry.isKept {
            clearOccurrence(entry)
        } else {
            let wasSettled = dayIsSettled(entry.date)
            setStatus(.completed, for: entry.rule, on: entry.date)
            if !wasSettled, dayIsSettled(entry.date) { giveThanks() }
        }
    }

    /// The app does not congratulate anyone for praying. Keeping a rule is
    /// answered with thanksgiving, not applause — Saint John Chrysostom's
    /// words, which the bundled passages already carry.
    private func giveThanks() {
        thanksgivingTask?.cancel()
        thanksgiving = "Glory to God for all things."
        thanksgivingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.thanksgiving = nil
        }
    }

    /// Moving to another day, or reopening, clears it — it belongs to the
    /// moment it was raised.
    func clearThanksgiving() {
        thanksgivingTask?.cancel()
        thanksgiving = nil
    }

    func markKeptLate(_ entry: DayEntry) {
        setStatus(.completedLate, for: entry.rule, on: entry.date)
    }

    /// Returns a day to having no record at all — due, or missed once its
    /// moment has passed. This previously wrote `.skipped`, which quietly took
    /// the day out of scoring altogether: un-ticking a box you had ticked by
    /// mistake silently excused the day instead of restoring it, and made the
    /// checkbox indistinguishable from standing the rule down.
    func clearOccurrence(_ entry: DayEntry) {
        do {
            try store.removeOccurrence(ruleID: entry.rule.id, date: entry.date)
            reload()
        } catch {
            loadError = "Could not update that. \(error)"
        }
    }

    func take(on template: RuleTemplate) {
        do {
            let rule = template.makeRule(source: "the library")
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: today))

            // A rule tied to the church calendar never comes due while its
            // observance is merely shown. Taking one on is a clear statement of
            // intent, so turn the observance on rather than adding a rule that
            // silently does nothing — and say that it happened.
            if let trigger = template.requiredTrigger,
               !settings.observances.setting(for: trigger).drivesRules {
                let name = ObservanceSettings.name(for: trigger)
                update { $0.observances.observe(trigger) }
                notice = "\(template.title) is on your rule, and \(name) is now being observed. You can change that in settings."
            } else {
                reload()
            }
        } catch {
            loadError = "Could not add that rule. \(error)"
        }
    }

    func standDown(_ rule: Rule) {
        applyPlan(EditPlanner().pause(rule: rule, activations: activations, on: today))
    }

    func resume(_ rule: Rule) {
        applyPlan(EditPlanner().resume(rule: rule, on: today))
    }

    func save(_ rule: Rule, isNew: Bool) {
        do {
            try store.save(rule)
            if isNew { try store.save(Activation(ruleID: rule.id, from: today)) }
            reload()
        } catch {
            loadError = "Could not save that rule. \(error)"
        }
    }

    func delete(_ rule: Rule, scope: EditScope) {
        applyPlan(EditPlanner().delete(
            rule: rule, activations: activations, on: selectedDate, scope: scope
        ))
    }

    private func applyPlan(_ plan: EditPlan) {
        do {
            try store.apply(plan)
            reload()
        } catch {
            loadError = "Could not apply that change. \(error)"
        }
    }

    // MARK: keeping the record safe

    /// Writes a dated JSON backup beside the database, keeping the last few.
    ///
    /// The value of this app is entirely cumulative — a year in, that database
    /// is the only copy of something that cannot be reconstructed. An automatic
    /// copy costs nothing and does not depend on anyone remembering.
    func writeAutomaticBackup(keeping limit: Int = 10) {
        do {
            let directory = try StoreLocation.backupsDirectory()
            let stamp = ISO8601DateFormatter()
            stamp.formatOptions = [.withFullDate]
            let name = "chotki-\(stamp.string(from: Date())).json"
            let url = directory.appendingPathComponent(name)

            // Never write an empty backup. If the store failed to open, or this
            // is a fresh install, an empty file would be worthless — and worse,
            // it could replace a good one.
            guard try !store.rules(includeArchived: true).isEmpty else { return }

            // One a day is plenty; do not rewrite it on every launch.
            guard !FileManager.default.fileExists(atPath: url.path) else { return }
            try store.exportJSON().write(to: url)

            let existing = try FileManager.default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
            for old in existing.dropFirst(limit) {
                try? FileManager.default.removeItem(at: old)
            }
        } catch {
            // A failed backup must never stop the app starting.
        }
    }

    func exportBackup(to url: URL) {
        do {
            try store.exportJSON().write(to: url)
            notice = "Backup written to \(url.lastPathComponent)."
        } catch {
            loadError = "Could not write that backup. \(error)"
        }
    }

    /// Merges a backup in. Nothing already here is removed — a restore that
    /// silently wiped a month of record would be far worse than a duplicate.
    func importBackup(from url: URL) {
        do {
            try store.importJSON(try Data(contentsOf: url))
            settings = (try? store.loadSettings()) ?? settings
            reload()
            notice = "Restored from \(url.lastPathComponent)."
        } catch {
            loadError = "Could not read that backup. \(error)"
        }
    }

    // MARK: settings

    func update(_ change: (inout AppSettings) -> Void) {
        let settingsBeforeChange = settings
        var updated = settings
        change(&updated)
        let jurisdictionChanged = updated.jurisdiction != settings.jurisdiction
        settings = updated
        persist(updated)

        if jurisdictionChanged {
            try? liturgical.setJurisdiction(updated.jurisdiction, around: today)
            Task { await refreshLiturgical() }
        }
        if updated.launchAtLogin != launchAtLogin.isEnabled {
            try? launchAtLogin.setEnabled(updated.launchAtLogin)
        }
        if updated.showInDock != settingsBeforeChange.showInDock {
            onDockPresenceChanged?(updated.showInDock)
        }
        reload()
    }

    // MARK: reminders

    private func startDriver() {
        let driver = ReminderDriver(notifier: notifier) { [weak self] in
            guard let self else { return [] }
            return self.scheduler.plan(
                rules: self.rules, activations: self.activations,
                occurrences: self.occurrences, on: self.today
            )
        }
        self.driver = driver
        driver.start()
    }

    private func rearmReminders() {
        driver?.refresh()
    }

    /// Acting on a notification's buttons.
    private func listenForActions() {
        // The task inherits the main actor from here, so neither the property
        // nor the handler needs awaiting — only the stream itself does.
        Task { [weak self] in
            guard let self else { return }
            for await event in self.notifier.actionEvents {
                self.handle(event)
            }
        }
    }

    private func handle(_ event: NotificationActionEvent) {
        // Ids are "<ruleID>:<date>:<suffix>".
        let parts = event.requestID.split(separator: ":")
        guard parts.count >= 2,
              let ruleID = UUID(uuidString: String(parts[0])),
              let date = CalendarDate(iso: String(parts[1])),
              let rule = rules.first(where: { $0.id == ruleID })
        else { return }

        switch event.actionID {
        case NotificationAction.markComplete.id:
            setStatus(.completed, for: rule, on: date)
        case NotificationAction.snooze.id:
            driver?.snooze(ruleID: ruleID, date: date, by: 60 * 60)
        default:
            break
        }
    }
}
