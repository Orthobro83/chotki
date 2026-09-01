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

    /// The seven questions and every answer to them. Loaded whole: seven rows
    /// and a journal are small, and the screen needs all of it at once to count
    /// what each weekday holds.
    private(set) var reflections: [Reflection] = []
    private(set) var reflectionEntries: [ReflectionEntry] = []

    /// Said out loud when something goes wrong with the record, rather than
    /// swallowed. A setting that fails to save reverts on the next launch with
    /// nobody the wiser, which is exactly how an earlier bug hid.
    var trouble: String?

    var selectedDate: CalendarDate
    var visibleMonth: CalendarDate

    /// The day this model last believed was today.
    ///
    /// Not a "follow today" flag: comparing the selection against this is what
    /// tells `DayRollover` whether the view was on today, and it means tapping
    /// back onto today resumes following with nothing to keep in step.
    private var lastKnownToday: CalendarDate

    var today: CalendarDate { CalendarDate(Date(), in: .current) }

    init(store: SQLiteStore) {
        self.store = store
        let now = CalendarDate(Date(), in: .current)
        self.selectedDate = now
        self.visibleMonth = now
        self.lastKnownToday = now
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
            // Idempotent, and it fills a gap rather than overwriting, so a
            // question changed here survives every launch.
            try store.seedReflections()
            reflections = try store.reflections()
            reflectionEntries = try store.reflectionEntries(weekday: nil, from: nil, through: nil)
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

    /// Moves the view on when the day has changed under it.
    ///
    /// Chotki was opened on the 28th, closed, and opened again on the 29th
    /// still showing the 28th — so the rules on screen were yesterday's, and
    /// ticking one wrote to the wrong day. A phone is the worst case for this:
    /// the app is rarely quit, so without a check on coming back to the
    /// foreground the view can sit on a stale day for a week.
    ///
    /// Whether to move is `DayRollover`'s decision, not this one. `now` is
    /// injectable so the move can be tested without waiting for midnight.
    func advanceDayIfNeeded(now: CalendarDate? = nil) {
        let now = now ?? today
        guard now != lastKnownToday else { return }

        let next = DayRollover.selection(
            showing: selectedDate, wasToday: lastKnownToday, isToday: now
        )
        lastKnownToday = now

        guard next != selectedDate else { return }
        selectedDate = next
        // Show the month the day is actually in, or the selection lands
        // off-screen in a grid still displaying somewhere else.
        visibleMonth = next
        reload()
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

    // MARK: what the day's menu can do
    //
    // Every one of these existed on the Mac and reached iOS as nothing at all.
    // The row had a checkbox and a way to the prayers; the Mac's right-click
    // menu — stand down, mark kept late, pause, resume, edit — had no
    // equivalent here, so a rule once taken on could not be changed or stopped
    // from the day at all.

    /// Writes a status for one day of one rule.
    ///
    /// Settling a day silences the rest of it: `reload` reschedules, and
    /// `ReminderTicker` withdraws what the day no longer needs.
    func setStatus(_ status: OccurrenceStatus, for rule: Rule, on date: CalendarDate) {
        let kept = status == .completed || status == .completedLate
        do {
            try store.save(Occurrence(
                ruleID: rule.id, date: date, status: status,
                completedAt: kept ? Date() : nil
            ))
            reload()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    /// Kept, but after its moment had passed.
    ///
    /// Deliberately a thing you say rather than a thing the app infers.
    /// Someone who kept a rule and only remembered to tick it afterwards has
    /// not done anything late, and the app cannot tell the difference — so
    /// ticking the box never means this. Only choosing it does.
    func markKeptLate(_ entry: DayEntry) {
        setStatus(.completedLate, for: entry.rule, on: entry.date)
    }

    /// This one day excused. The rule itself is untouched.
    func standDownForTheDay(_ entry: DayEntry) {
        setStatus(.skipped, for: entry.rule, on: entry.date)
    }

    func isPaused(_ rule: Rule) -> Bool { practice.isPaused(rule) }

    /// Stops a rule from today, keeping everything it has kept. Pausing
    /// removes days from the record rather than counting them against anyone.
    func pause(_ rule: Rule) {
        apply(EditPlanner().pause(rule: rule, activations: activations, on: today))
    }

    func resume(_ rule: Rule) {
        apply(EditPlanner().resume(rule: rule, on: today))
    }

    private func apply(_ plan: EditPlan) {
        do {
            try store.apply(plan)
            reload()
        } catch {
            trouble = "That change did not apply. \(error.localizedDescription)"
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

    /// The rule a template would make, without saving it.
    ///
    /// So the editor can be shown first, filled in. Taking something on is a
    /// decision about how often and at what time — iOS saved the template's
    /// defaults straight to the day and never asked, which left no way to say
    /// when, on which days, or whether to be reminded. Android already does
    /// this; the words here are its comment, because it is the same decision.
    func ruleFrom(_ template: RuleTemplate) -> Rule {
        template.makeRule(source: "the library")
    }

    /// Takes a template on as it stands, without asking. Kept for the tests
    /// that predate the editor-first flow.
    func take(_ template: RuleTemplate) {
        save(ruleFrom(template))
    }

    /// Saves a rule the editor has filled in, new or changed.
    ///
    /// The observance a liturgical rule depends on is turned on with it, or the
    /// rule would sit there never coming due.
    func save(_ rule: Rule) {
        do {
            let isNew = (try store.rule(id: rule.id)) == nil
            try store.save(rule)
            if isNew { try store.save(Activation(ruleID: rule.id, from: today)) }
            reload()
            turnOnNeededObservances()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    var isTaken: (RuleTemplate) -> Bool {
        { [rules] template in rules.contains { $0.title == template.title } }
    }

    // MARK: rules of his own

    /// The Custom section: rules he wrote, whether or not they are in force.
    ///
    /// Missing from iOS entirely, along with the whole lower half of the
    /// library — so a rule written by hand and later set aside could not be
    /// found again on this platform.
    var customEntries: [Rule] {
        CustomLibrary.entries(from: (try? store.rules(includeArchived: true)) ?? [])
    }

    /// Puts a rule of his own back on the rule, from today.
    ///
    /// The same rule, not a copy: its history follows it, and the gap shows as
    /// a gap rather than as two unrelated rules with the record split between
    /// them.
    func takeUp(_ rule: Rule) {
        do {
            try store.save(CustomLibrary.takingUp(rule))
            if practice.isPaused(rule) {
                try store.save(Activation(ruleID: rule.id, from: today))
            }
            reload()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    /// Out of the Custom list. The rule and its history are untouched.
    func setAside(_ rule: Rule) {
        do {
            try store.save(CustomLibrary.settingAside(rule))
            reload()
        } catch {
            trouble = "That did not save. \(error.localizedDescription)"
        }
    }

    func isOnTheRule(_ rule: Rule) -> Bool { !rule.isArchived && !isPaused(rule) }

    // MARK: reflections

    /// The question for a weekday as it currently stands.
    func reflection(for weekday: Weekday) -> Reflection {
        reflections.first { $0.weekday == weekday } ?? .bundled(for: weekday)
    }

    /// One weekday's answers, newest first, scoped to a period.
    func reflectionSeries(
        for weekday: Weekday, in period: ReflectionPeriod = .all
    ) -> ReflectionSeries {
        ReflectionJournal.series(reflectionEntries, on: weekday, in: period)
    }

    /// The date this weekday fell on in the week containing today.
    ///
    /// A reflection is answered on its own weekday, so writing on Sunday's card
    /// files the answer under this week's Sunday — not under today, which may
    /// be a Wednesday.
    func dateOfCurrentWeek(_ weekday: Weekday) -> CalendarDate {
        today.adding(days: weekday.rawValue - today.weekday.rawValue)
    }

    /// Whether this week's answer for a weekday is already written. An answer
    /// locks once saved, so this is what stops a second being offered.
    func hasAnswered(_ weekday: Weekday) -> Bool {
        ReflectionJournal.hasEntry(reflectionEntries, on: dateOfCurrentWeek(weekday))
    }

    func answer(for weekday: Weekday) -> ReflectionEntry? {
        let date = dateOfCurrentWeek(weekday)
        return reflectionEntries.first { $0.weekday == weekday && $0.date == date }
    }

    /// Writes an answer. It locks immediately: there is no path back through here.
    func saveReflection(_ weekday: Weekday, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let date = dateOfCurrentWeek(weekday)
        let entry = ReflectionEntry(
            answering: reflection(for: weekday), on: date, text: trimmed)

        // Persist and display are separate concerns. The entry is already in
        // memory and is valid; swallowing the redraw would make a successful
        // write look like a dead button, which is how this went wrong on the
        // web. Show it either way and say so if the write failed.
        reflectionEntries.removeAll { $0.weekday == weekday && $0.date == date }
        reflectionEntries.append(entry)
        do {
            try store.save(entry)
        } catch {
            trouble = "That was written down here but could not be saved to your record."
        }
    }

    /// Rewrites a question from today onward. Answers already written keep the
    /// question they were written against — see `ReflectionQuestion` in core.
    func rewriteReflection(_ weekday: Weekday, to question: ReflectionQuestion) {
        let updated = reflection(for: weekday).rewritten(question)
        reflections.removeAll { $0.weekday == weekday }
        reflections.append(updated)
        reflections.sort { $0.weekday.rawValue < $1.weekday.rawValue }
        do {
            try store.save(updated)
        } catch {
            trouble = "The question was changed here but could not be saved to your record."
        }
    }

    func restoreBundledReflection(_ weekday: Weekday) {
        rewriteReflection(weekday, to: Reflection.bundled(for: weekday).question)
    }

    /// The library rule that puts Reflections on the rule.
    var reflectionTemplate: RuleTemplate? {
        RuleLibrary.shared.templates.first { $0.id == "reflection" }
    }

    /// Whether it is already there. Matched on title, because a template taken
    /// from the library copies itself and keeps no link back — so a renamed copy
    /// stops counting, which is right: it is theirs then, not ours. The same
    /// rule that decides whether the day's row offers a way through.
    var hasReflectionsOnRule: Bool {
        rules.contains { $0.title == reflectionRuleTitle }
    }

    func exportReflectionsJSON() throws -> Data { try store.exportReflectionsJSON() }

    /// Merges a journal file in. Never discards what is already held.
    @discardableResult
    func importReflectionsJSON(_ data: Data) -> ReflectionImportResult? {
        do {
            let result = try store.importReflectionsJSON(data)
            reflectionEntries = try store.reflectionEntries(weekday: nil, from: nil, through: nil)
            reflections = try store.reflections()
            trouble = summary(of: result)
            return result
        } catch is ReflectionImportError {
            trouble = "That file could not be read as a journal. Nothing was changed."
            return nil
        } catch {
            trouble = "That journal could not be read in. Nothing was changed."
            return nil
        }
    }

    private func summary(of result: ReflectionImportResult) -> String {
        var parts = [result.addedCount == 1 ? "1 answer added" : "\(result.addedCount) answers added"]
        if result.alreadyPresent > 0 { parts.append("\(result.alreadyPresent) already here") }
        if result.collided > 0 { parts.append("\(result.collided) skipped, that day was taken") }
        return parts.joined(separator: ", ") + "."
    }
}
