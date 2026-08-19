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
    /// Set by the app delegate. The model asks for a window; it does not know
    /// what a window is.
    var openDetachedReport: (() -> Void)?

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
        startsReminders: Bool = true
    ) {
        self.store = store
        self.notifier = notifier
        self.launchAtLogin = launchAtLogin
        self.storage = storage
        let loaded = storage.load()
        self.settings = loaded
        self.liturgical = LiturgicalService(store: store, jurisdiction: loaded.jurisdiction)
        let now = CalendarDate(Date(), in: .current)
        self.selectedDate = now
        self.visibleMonth = now

        reload()
        if startsReminders { startDriver() }
        listenForActions()
        Task { await refreshLiturgical() }
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
        rearmReminders()
    }

    func refreshLiturgical() async {
        try? liturgical.loadSnapshot(around: today)
        _ = await liturgical.refresh(from: today.adding(days: -1), days: 16)
        objectWillChange.send()
    }

    // MARK: what is due

    /// Rules due on a day, with what has become of each.
    func entries(on date: CalendarDate) -> [DayEntry] {
        let byRule = Dictionary(
            occurrences.filter { $0.date == date }.map { ($0.ruleID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return rules.compactMap { rule in
            let due = engine.dueDates(rule: rule, activations: activations, from: date, through: date)
            guard !due.isEmpty else { return nil }
            return DayEntry(rule: rule, date: date, occurrence: byRule[rule.id])
        }
        .sorted { a, b in
            switch (a.rule.timeOfDay, b.rule.timeOfDay) {
            case let (x?, y?): return x < y
            case (nil, _?): return false      // untimed rules sit below timed ones
            case (_?, nil): return true
            case (nil, nil): return a.rule.title < b.rule.title
            }
        }
    }

    /// The report over a trailing window. Recomputed on demand rather than
    /// cached: it is cheap, and a stale figure would be worse than none.
    func report(days: Int = 30) -> ProgressReport {
        ScoringEngine(engine: engine, timeZone: .current).report(
            rules: rules, activations: activations, occurrences: occurrences,
            from: today.adding(days: -(days - 1)), through: today
        )
    }

    func isPaused(_ rule: Rule) -> Bool {
        !activations.contains { $0.ruleID == rule.id && $0.isOpen }
    }

    // MARK: acting

    func setStatus(_ status: OccurrenceStatus?, for rule: Rule, on date: CalendarDate) {
        do {
            if let status {
                try store.save(Occurrence(
                    ruleID: rule.id, date: date, status: status,
                    completedAt: status == .completed || status == .completedLate ? Date() : nil
                ))
                // Completing silences the rest of the day immediately.
                let ids = scheduler.cancellationIDs(
                    ruleID: rule.id, date: date, rules: rules, activations: activations
                )
                Task { await notifier.cancel(ids: ids) }
            } else {
                try store.save(Occurrence(ruleID: rule.id, date: date, status: .skipped))
            }
            reload()
        } catch {
            loadError = "Could not save that. \(error)"
        }
    }

    /// Marks kept, or un-marks it if it was already kept.
    func toggleKept(_ entry: DayEntry) {
        if entry.isKept {
            clearOccurrence(entry)
        } else {
            let late = entry.date < today
            setStatus(late ? .completedLate : .completed, for: entry.rule, on: entry.date)
        }
    }

    private func clearOccurrence(_ entry: DayEntry) {
        // Returning a day to "simply due" means removing the row, since absence
        // is the default state.
        guard let existing = entry.occurrence else { return }
        do {
            try store.save(Occurrence(
                id: existing.id, ruleID: existing.ruleID, date: existing.date,
                status: .skipped, completedAt: nil
            ))
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

    // MARK: settings

    func update(_ change: (inout AppSettings) -> Void) {
        var updated = settings
        change(&updated)
        let jurisdictionChanged = updated.jurisdiction != settings.jurisdiction
        settings = updated
        storage.save(updated)

        if jurisdictionChanged {
            try? liturgical.setJurisdiction(updated.jurisdiction, around: today)
            Task { await refreshLiturgical() }
        }
        if updated.launchAtLogin != launchAtLogin.isEnabled {
            try? launchAtLogin.setEnabled(updated.launchAtLogin)
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
        Task { [weak self] in
            guard let self else { return }
            for await event in await self.notifier.actionEvents {
                await self.handle(event)
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

/// One rule on one day, with whatever has become of it.
struct DayEntry: Identifiable, Hashable {
    let rule: Rule
    let date: CalendarDate
    let occurrence: Occurrence?

    var id: String { "\(rule.id):\(date.iso)" }
    var status: OccurrenceStatus? { occurrence?.status }
    var isKept: Bool { status == .completed || status == .completedLate }
    var isStoodDown: Bool { status == .skipped || status == .cancelled }
}
