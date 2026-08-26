import Foundation
import Observation
import ChotkiCore

/// What the interface reads and writes, and nothing more.
///
/// Deliberately thin. Every decision — what is due on a day, whether a day is
/// settled, what an edit does to a series — belongs to `Practice`, `Scheduler`
/// and `EditPlanner` in core, and this only assembles them and holds what the
/// screen is looking at.
///
/// It is not the macOS `AppModel` copied across. That file carries the dock,
/// launch-at-login, the menu bar and a run-loop timer, none of which exist
/// here; copying it would have brought five hundred lines of wiring for the
/// sake of a dozen. Where the two platforms must *decide* the same thing, the
/// deciding belongs in core rather than in either of them.
/// Main-actor by declaration rather than by convention. It was already only
/// ever touched from a view body; saying so is what lets the calendar fetch be
/// an ordinary `Task` instead of a hand-audited hop.
@MainActor
@Observable
final class Model {

    private let store: SQLiteStore

    /// The church calendar. The only thing Chotki asks the network for.
    ///
    /// iOS shipped without this: `ReadingView` read `liturgicalDay(_:)` from
    /// the store and nothing ever wrote to it, so the reading screen was
    /// permanently empty and looked like a slow network rather than a missing
    /// half. The reader was built and the writer was not — the same shape as
    /// Android's missing INTERNET permission, arrived at independently.
    let liturgical: LiturgicalService

    /// What the prayers screen is showing. Core's, not a local copy.
    ///
    /// It lives on the model rather than in the view because following a word
    /// into the glossary destroys and rebuilds the view, and losing your place
    /// in a hundred-knot count because you looked up "Publican" is a poor
    /// trade. The iOS build had its own three-field struct in `@State`, which
    /// lost the count on every push and had none of the rope rule.
    var prayers = PrayerScreen()

    /// Bumped when the calendar changes under us, so anything showing a day
    /// re-reads it. `liturgicalDay(_:)` reads the store directly, and an
    /// `@Observable` model cannot see that a table it does not hold has
    /// changed.
    private(set) var calendarVersion = 0
    private(set) var isFetchingCalendar = false

    private(set) var rules: [Rule] = []
    private(set) var activations: [Activation] = []
    private(set) var occurrences: [Occurrence] = []
    private(set) var settings: AppSettings = .default

    /// Said out loud when something goes wrong with the record, rather than
    /// swallowed. A setting that fails to save reverts on the next launch with
    /// nobody the wiser, which is exactly how an earlier bug hid.
    var trouble: String?

    var selectedDate: CalendarDate
    var visibleMonth: CalendarDate

    var today: CalendarDate { CalendarDate(Date(), in: .current) }

    init(store: SQLiteStore) {
        self.store = store
        let now = CalendarDate(Date(), in: .current)
        self.selectedDate = now
        self.visibleMonth = now
        let loaded = (try? store.loadSettings()) ?? .default
        self.liturgical = LiturgicalService(store: store, jurisdiction: loaded.jurisdiction)
        reload()
        Task { await refreshCalendar() }
    }

    /// Fetches the calendar around today and tells the screens to look again.
    ///
    /// Deliberately not silent about failing: `isFetchingCalendar` is what lets
    /// the reading screen say it is trying rather than say nothing, and offer
    /// the fetch again when it did not work.
    func refreshCalendar(around date: CalendarDate? = nil) async {
        guard !isFetchingCalendar else { return }
        isFetchingCalendar = true
        defer { isFetchingCalendar = false }

        let centre = date ?? today
        try? liturgical.loadSnapshot(around: centre)
        _ = await liturgical.refresh(from: centre.adding(days: -1), days: 16)
        calendarVersion += 1
    }

    /// Rescheduled after anything that changes when a rule is due.
    ///
    /// Android reloaded and stopped there, so a reminder set in the editor did
    /// not schedule until the app had been backgrounded and reopened — which is
    /// indistinguishable from reminders being broken. Every path that touches
    /// the record comes through `reload`, so this hangs off it.
    private func rescheduleReminders() {
        // Built here and handed over as a value, so nothing of the model
        // crosses into the task. Swift 6 is right to object: this object is
        // main-actor state and the sync is not.
        let planned = plannedReminders()
        Task.detached { await Reminders().sync(to: planned) }
    }

    /// Today and tomorrow, not today alone.
    ///
    /// "The evening before" fires at 20:00 the day *before* the rule is due, so
    /// planning only today could never arm it — on Android that lead had never
    /// once worked.
    func plannedReminders(now: Date = Date()) -> [PlannedNotification] {
        let scheduler = Scheduler(
            engine: RecurrenceEngine(observances: settings.observances),
            policy: settings.reminders
        )
        return [today, today.adding(days: 1)].flatMap { day in
            scheduler.plan(
                rules: rules, activations: activations,
                occurrences: occurrences, on: day
            )
        }
    }

    private var practice: Practice {
        Practice(
            rules: rules, activations: activations,
            occurrences: occurrences, settings: settings
        )
    }

    func reload() {
        do {
            rules = try store.rules(includeArchived: false)
            activations = try store.activations(ruleID: nil)
            occurrences = try store.occurrences(ruleID: nil, from: nil, through: nil)
            settings = (try store.loadSettings()) ?? .default
        } catch {
            trouble = "Chotki could not read the record. \(error.localizedDescription)"
        }
        rescheduleReminders()
    }

    // MARK: the day

    func entries(on date: CalendarDate) -> [DayEntry] { practice.entries(on: date) }
    func isSettled(on date: CalendarDate) -> Bool { practice.isSettled(on: date) }

    /// Marking kept, and un-marking it.
    ///
    /// Un-ticking removes the record rather than writing "skipped": absence is
    /// the default state, and skipped means something else entirely — a day
    /// deliberately stood down, which leaves both sides of the score.
    func toggleKept(_ entry: DayEntry) {
        guard !entry.isDispensed else { return }
        do {
            if entry.isKept {
                try store.removeOccurrence(ruleID: entry.rule.id, date: entry.date)
            } else {
                try store.save(Occurrence(
                    ruleID: entry.rule.id, date: entry.date,
                    status: .completed, completedAt: Date()
                ))
            }
            reload()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    /// The church calendar for a day, if it has been fetched.
    ///
    /// Reads `calendarVersion` so that a fetch redraws whatever is showing.
    /// Without that touch the value is invisible to observation and the screen
    /// stays empty until something else happens to change.
    func liturgicalDay(_ date: CalendarDate) -> LiturgicalDay? {
        _ = calendarVersion
        return try? store.liturgicalDay(civilDate: date, reckoning: settings.jurisdiction.reckoning)
    }

    func report(days: Int = 30) -> ProgressReport {
        practice.report(days: days, today: today)
    }

    // MARK: keeping the record

    /// The record, as a file that outlives the app.
    ///
    /// iOS backs the sandbox up with the phone, but a record of someone's
    /// prayer life should not depend on that alone — a new phone, a restore
    /// that goes wrong, a move to the Mac. macOS and Android both offer this
    /// and iOS did not, which is what the parity test caught.
    func exportBackup() -> Data? {
        do { return try store.exportJSON() } catch {
            trouble = "Could not make a copy. \(error.localizedDescription)"
            return nil
        }
    }

    /// Merges a copy back in. Nothing already here is removed — a restore that
    /// silently wiped a month would be far worse than a duplicate.
    func restore(from data: Data) {
        do {
            try store.importJSON(data)
            reload()
        } catch {
            trouble = "That file could not be restored. \(error.localizedDescription)"
        }
    }

    // MARK: settings

    /// Any settings change, with the consequence that follows it.
    ///
    /// The reckoning is the one that bites. Moving it shifts every fast and
    /// feast by thirteen days, and without the stamp the scoring re-derives the
    /// past from the new calendar — turning a fortnight someone kept into a
    /// fortnight of misses.
    func update(_ change: (inout AppSettings) -> Void) {
        var updated = settings
        change(&updated)
        if updated.jurisdiction.reckoning != settings.jurisdiction.reckoning {
            updated.reckoningChangedOn = today
        }
        let jurisdictionChanged = updated.jurisdiction != settings.jurisdiction
        do {
            try store.saveSettings(updated)
            settings = updated
        } catch {
            trouble = "That setting did not save. \(error.localizedDescription)"
        }
        // A new church or a new reckoning means a different calendar, and the
        // one already cached answers for the old one. macOS re-fetches here;
        // iOS would have kept showing the previous jurisdiction's days.
        if jurisdictionChanged {
            try? liturgical.setJurisdiction(updated.jurisdiction, around: today)
            calendarVersion += 1
            Task { await refreshCalendar() }
        }
    }

    func beginningIsDone() { update { $0.hasCompletedFirstRun = true } }

    /// Saves an edited or newly written rule, and activates a new one.
    func save(
        _ rule: Rule,
        title: String, note: String?, source: String?,
        recurrence: Recurrence, timeOfDay: TimeOfDay?, reminders: RuleReminders
    ) {
        var updated = rule
        updated.title = title
        updated.note = note
        updated.source = source
        updated.recurrence = recurrence
        updated.timeOfDay = timeOfDay
        updated.reminders = reminders

        do {
            let isNew = (try store.rule(id: updated.id)) == nil
            try store.save(updated)
            if isNew { try store.save(Activation(ruleID: updated.id, from: today)) }
            reload()
            turnOnNeededObservances()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    /// Removing a rule archives it. Nothing is destroyed — its history stays in
    /// the record and it can be taken up again.
    func remove(_ rule: Rule) {
        do {
            var archived = rule
            archived.archivedAt = Date()
            try store.save(archived)
            reload()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    /// A rule tied to the church calendar turns on the observance it needs, or
    /// it sits there never coming due. Android covered only the library path,
    /// so a fast-day rule written by hand never arrived.
    private func turnOnNeededObservances() {
        let needed = practice.observancesNeeded()
        guard !needed.isEmpty else { return }
        var updated = settings
        for trigger in needed { updated.observances.observe(trigger) }
        try? store.saveSettings(updated)
        settings = updated
    }

    // MARK: the library, enough of it for now

    /// Takes a template on. The observance a liturgical rule depends on is
    /// turned on with it, or the rule would never come due.
    func take(_ template: RuleTemplate) {
        do {
            let rule = template.makeRule(source: "the library")
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: today))
            reload()

            turnOnNeededObservances()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    var isTaken: (RuleTemplate) -> Bool {
        { [rules] template in rules.contains { $0.title == template.title } }
    }
}
