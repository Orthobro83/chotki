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
@Observable
final class Model {

    private let store: SQLiteStore

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
        reload()
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
    func liturgicalDay(_ date: CalendarDate) -> LiturgicalDay? {
        try? store.liturgicalDay(civilDate: date, reckoning: settings.jurisdiction.reckoning)
    }

    func report(days: Int = 30) -> ProgressReport {
        practice.report(days: days, today: today)
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
        do {
            try store.saveSettings(updated)
            settings = updated
        } catch {
            trouble = "That setting did not save. \(error.localizedDescription)"
        }
    }

    func beginningIsDone() { update { $0.hasCompletedFirstRun = true } }

    // MARK: the library, enough of it for now

    /// Takes a template on. The observance a liturgical rule depends on is
    /// turned on with it, or the rule would never come due.
    func take(_ template: RuleTemplate) {
        do {
            let rule = template.makeRule(source: "the library")
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: today))
            reload()

            let needed = practice.observancesNeeded()
            if !needed.isEmpty {
                var updated = settings
                for trigger in needed { updated.observances.observe(trigger) }
                try store.saveSettings(updated)
                settings = updated
            }
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    var isTaken: (RuleTemplate) -> Bool {
        { [rules] template in rules.contains { $0.title == template.title } }
    }
}
