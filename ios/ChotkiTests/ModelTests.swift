import Testing
import Foundation
@testable import Chotki
import ChotkiCore

/// The model, driven rather than looked at.
///
/// Core already carries every decision and has its own 353 tests, so these
/// check only what this layer adds: that the right thing reaches the store and
/// that the screen is reading back what was written. That is the seam where
/// every interface bug in this project has lived.
@Suite("The iOS model")
struct ModelTests {

    private func model() throws -> Model {
        // On disk, in a temporary place. The model takes a SQLiteStore, and a
        // test must never touch the real one.
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-test-\(UUID().uuidString).sqlite").path
        return Model(store: try SQLiteStore(path: path))
    }

    private var morningPrayers: RuleTemplate {
        RuleLibrary.bundled.first { $0.id == "morning-prayers" }!
    }

    @Test("a rule taken on appears on the day")
    func takingOnPutsItOnTheDay() throws {
        let model = try model()
        #expect(model.entries(on: model.today).isEmpty)

        model.take(morningPrayers)

        #expect(model.rules.count == 1)
        #expect(model.entries(on: model.today).map(\.rule.title) == ["Morning prayers"])
    }

    @Test("it carries its prayers and its time")
    func itCarriesWhatTheTemplateSaid() throws {
        let model = try model()
        model.take(morningPrayers)

        let rule = try #require(model.rules.first)
        #expect(rule.hasPrayers)
        #expect(rule.timeOfDay?.hour == 6)
        #expect(rule.timeOfDay?.minute == 30)
    }

    @Test("ticking marks the day kept")
    func tickingKeepsIt() throws {
        let model = try model()
        model.take(morningPrayers)
        let entry = try #require(model.entries(on: model.today).first)
        #expect(!entry.isKept)

        model.toggleKept(entry)

        let after = try #require(model.entries(on: model.today).first)
        #expect(after.isKept)
    }

    /// Un-ticking removes the record rather than writing "skipped". Absence is
    /// the default state; skipped means a day deliberately stood down, which
    /// leaves both sides of the score.
    @Test("un-ticking takes the record away rather than writing skipped")
    func unTickingRemovesTheRecord() throws {
        let model = try model()
        model.take(morningPrayers)

        var entry = try #require(model.entries(on: model.today).first)
        model.toggleKept(entry)
        entry = try #require(model.entries(on: model.today).first)
        model.toggleKept(entry)

        let after = try #require(model.entries(on: model.today).first)
        #expect(!after.isKept)
        #expect(after.status == nil, "un-ticking wrote \(String(describing: after.status))")
    }

    /// A rule tied to the church calendar turns on the observance it needs, or
    /// it would sit there never coming due. Android shipped without this on the
    /// hand-written path and a fast-day rule silently never arrived.
    @Test("taking on a fasting rule starts observing fasting")
    func fastingRuleStartsObservance() throws {
        let model = try model()
        let lent = try #require(RuleLibrary.bundled.first { $0.title == "Great Lent" })

        model.take(lent)

        #expect(model.settings.observances.fasting == .observed)
    }

    @Test("what is taken on is known to be taken on")
    func takenIsReported() throws {
        let model = try model()
        #expect(!model.isTaken(morningPrayers))
        model.take(morningPrayers)
        #expect(model.isTaken(morningPrayers))
    }
}

/// The shape of the navigation, as a decision rather than an accident.
///
/// iOS shows five tabs before folding the rest into "More", so the glossary is
/// not one — it is reached by tapping a word that puzzled you, which is how
/// anyone actually arrives there. That is a per-platform arrangement, and it
/// must never become a per-platform *capability*: macOS uses three tabs and
/// Android six, and all three reach the same screens.
@Suite("The shape of the navigation")
struct NavigationTests {

    @Test("five places, which is what a phone shows without an overflow")
    func fivePlaces() {
        #expect(Place.allCases.count == 5)
        #expect(!Place.allCases.map(\.rawValue).contains("Glossary"))
    }

    /// The glossary is not a tab, so it must be a route. If this stops
    /// compiling or the case is removed, the screen has quietly become
    /// unreachable — which is exactly how Android lost its first-run screen.
    @Test("the glossary is reachable even though it is not a tab")
    func glossaryIsReachable() {
        let byTerm = Route.term(slug: "prayer-rule")
        let browsing = Route.term(slug: nil)
        #expect(byTerm != browsing)
    }

    /// Held as values, so a stack cannot guess. Android's navigation was
    /// "which screen is showing" and the back button guessed wrongly for three
    /// rounds before it went back one reliably.
    @Test("routes are values, and distinguish themselves")
    func routesAreValues() {
        let a = UUID(), b = UUID()
        #expect(Route.prayers(ruleID: a) == Route.prayers(ruleID: a))
        #expect(Route.prayers(ruleID: a) != Route.prayers(ruleID: b))
        #expect(Route.editor(ruleID: nil) != Route.editor(ruleID: a))
        #expect(Route.psalter != Route.rope)
    }
}

/// The screens, and that nothing has quietly gone missing.
///
/// Every one of these exists because a screen was lost on another platform, or
/// nearly was. Android had no first-run screen at all for months; the words
/// were in core and nothing on that side read them.
@Suite("The screens")
struct ScreenTests {

    private func model() throws -> Model {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-test-\(UUID().uuidString).sqlite").path
        return Model(store: try SQLiteStore(path: path))
    }

    @Test("a fresh record opens on the welcome, and only once")
    func welcomeIsFirstAndOnce() throws {
        let model = try model()
        #expect(!model.settings.hasCompletedFirstRun)

        model.beginningIsDone()

        #expect(model.settings.hasCompletedFirstRun)
    }

    /// The welcome's words are core's, not typed in here — which is what stops
    /// the three platforms drifting apart.
    @Test("the welcome says what core says")
    func welcomeReadsFromCore() {
        #expect(Welcome.beginLabel == "Begin")
        let urls = Welcome.paragraphs.flatMap(\.spans).compactMap(\.url)
        #expect(urls == [
            "https://www.skool.com/fathermoses/",
            "https://orthodoxaustin.org/our-clergy/",
        ])
    }

    /// Moving the reckoning shifts every fast and feast by thirteen days.
    /// Without the stamp, scoring re-derives the past from the new calendar and
    /// turns a fortnight someone kept into a fortnight of misses.
    @Test("changing the calendar stamps the day it changed")
    func reckoningChangeIsStamped() throws {
        let model = try model()
        #expect(model.settings.reckoningChangedOn == nil)

        let other: Reckoning = model.settings.jurisdiction.reckoning == .julian
            ? .revisedJulian : .julian
        model.update { $0.jurisdiction.reckoning = other }

        #expect(model.settings.reckoningChangedOn == model.today)
    }

    /// Changing church between two of the same reckoning must stamp nothing.
    @Test("changing church without changing calendar stamps nothing")
    func sameReckoningStampsNothing() throws {
        let model = try model()
        let same = Jurisdiction.known.first {
            $0.reckoning == model.settings.jurisdiction.reckoning
                && $0.name != model.settings.jurisdiction.name
        }
        let chosen = try #require(same)

        model.update { $0.jurisdiction = chosen }

        #expect(model.settings.reckoningChangedOn == nil)
        #expect(model.settings.jurisdiction.name == chosen.name)
    }

    @Test("the Psalter and its cycle are reachable from here")
    func psalterIsThere() {
        #expect(Psalter.all.count == 151)
        #expect(Kathisma.divisions.count == 20)
    }
}

/// Reminders: what is planned, and what stops being planned.
///
/// Every one of these stands where an Android reminder bug was. `Scheduler` was
/// right there throughout — it has always stopped returning a settled rule —
/// and five separate things around it were not.
@Suite("Reminders")
struct ReminderTests {

    private func model() throws -> Model {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-test-\(UUID().uuidString).sqlite").path
        return Model(store: try SQLiteStore(path: path))
    }

    /// Late enough that its reminder is still ahead of now whenever this runs.
    private func aRuleDueLateToday(_ model: Model) {
        let template = RuleLibrary.bundled.first { $0.id == "evening-prayers" }!
        model.take(template)
        let rule = model.rules.first { $0.title == template.title }!
        model.save(
            rule, title: rule.title, note: nil, source: nil,
            recurrence: .daily, timeOfDay: TimeOfDay(hour: 23, minute: 55),
            reminders: RuleReminders(enabled: true, leads: [.atTheTime])
        )
    }

    @Test("a rule due later today is planned for")
    func plannedWhenDue() throws {
        let model = try model()
        aRuleDueLateToday(model)

        let planned = model.plannedReminders()
        #expect(!planned.isEmpty, "nothing was planned for a rule due tonight")
    }

    /// The reported bug, in its iOS form.
    @Test("marking it kept stops it being planned for")
    func keptStopsThePlan() throws {
        let model = try model()
        aRuleDueLateToday(model)

        let today = model.today
        let before = model.plannedReminders().filter { $0.date == today }
        #expect(!before.isEmpty)

        let entry = try #require(model.entries(on: today).first)
        model.toggleKept(entry)

        let after = model.plannedReminders().filter { $0.date == today }
        #expect(after.isEmpty, "still planned after being kept: \(after.map(\.request.id))")
    }

    /// Keeping today says nothing about tomorrow.
    @Test("tomorrow is still planned for after today is kept")
    func tomorrowSurvives() throws {
        let model = try model()
        aRuleDueLateToday(model)

        let entry = try #require(model.entries(on: model.today).first)
        model.toggleKept(entry)

        let tomorrow = model.today.adding(days: 1)
        #expect(model.plannedReminders().contains { $0.date == tomorrow })
    }

    /// Planning only today could never arm "the evening before", which fires at
    /// 20:00 the day *before* the rule is due. On Android that lead had never
    /// once worked.
    @Test("tomorrow is planned as well as today")
    func tomorrowIsPlanned() throws {
        let model = try model()
        aRuleDueLateToday(model)

        let tomorrow = model.today.adding(days: 1)
        #expect(model.plannedReminders().contains { $0.date == tomorrow })
    }

    @Test("turning reminders off for a rule stops them")
    func silencedStopsThePlan() throws {
        let model = try model()
        aRuleDueLateToday(model)
        #expect(!model.plannedReminders().isEmpty)

        let rule = try #require(model.rules.first)
        model.save(
            rule, title: rule.title, note: nil, source: nil,
            recurrence: rule.recurrence, timeOfDay: rule.timeOfDay,
            reminders: .silent
        )

        #expect(model.plannedReminders().isEmpty)
    }

    /// Removing a rule archives it, and takes its reminders with it.
    @Test("removing the rule stops its reminders")
    func removingStopsThem() throws {
        let model = try model()
        aRuleDueLateToday(model)

        model.remove(try #require(model.rules.first))

        #expect(model.plannedReminders().isEmpty)
    }
}

/// What syncing the schedule would actually do.
///
/// The part with the mistakes in it, tested apart from the system that makes it
/// awkward to test. On Android the equivalent was asserted against the app's
/// own note of what it had armed, and passed with the fix taken out.
@Suite("Reconciling what is scheduled")
struct ReconcileTests {

    private func planned(_ id: String, at fireAt: Date) -> PlannedNotification {
        PlannedNotification(
            id: id,
            ruleID: UUID(),
            date: CalendarDate(Date(), in: .current),
            fireAt: fireAt,
            request: NotificationRequest(id: id, title: "A rule", body: "At 06:30")
        )
    }

    private var now: Date { Date() }
    private var soon: Date { Date().addingTimeInterval(3600) }
    private var gone: Date { Date().addingTimeInterval(-3600) }

    @Test("something newly planned is added")
    func addsWhatIsMissing() {
        let work = Reminders.reconcile(
            planned: [planned("a:2026-08-26:lead10", at: soon)],
            pending: [], delivered: [], now: now
        )
        #expect(work.add.map(\.request.id) == ["a:2026-08-26:lead10"])
        #expect(work.removePending.isEmpty)
    }

    @Test("something no longer planned is taken back")
    func removesWhatIsStale() {
        let work = Reminders.reconcile(
            planned: [], pending: ["a:2026-08-26:lead10"], delivered: [], now: now
        )
        #expect(work.removePending == ["a:2026-08-26:lead10"])
        #expect(work.add.isEmpty)
    }

    /// The reported Android bug, as arithmetic: a notification already showing
    /// for a rule since kept must come down, not merely stop repeating.
    @Test("a delivered notification for a rule since kept is withdrawn")
    func withdrawsDelivered() {
        let id = "\(UUID()):2026-08-26:lead10"
        let work = Reminders.reconcile(
            planned: [], pending: [], delivered: [id], now: now
        )
        #expect(work.removeDelivered == [id])
    }

    /// Somebody else's notification is not ours to remove.
    @Test("notifications from elsewhere are left alone")
    func leavesOthersAlone() {
        let work = Reminders.reconcile(
            planned: [], pending: [], delivered: ["com.example.something"], now: now
        )
        #expect(work.removeDelivered.isEmpty)
    }

    /// Handing the system a moment that has passed delivers it at once, which
    /// is how a restart at lunchtime would deliver the whole morning.
    @Test("a moment already past is not scheduled")
    func doesNotSchedulueThePast() {
        let work = Reminders.reconcile(
            planned: [planned("a:2026-08-26:lead10", at: gone)],
            pending: [], delivered: [], now: now
        )
        #expect(work.add.isEmpty)
    }

    @Test("what is already scheduled is left where it is")
    func leavesSettledAlone() {
        let id = "a:2026-08-26:lead10"
        let work = Reminders.reconcile(
            planned: [planned(id, at: soon)], pending: [id], delivered: [], now: now
        )
        #expect(work == Reminders.Work())
    }
}

/// The record leaving and coming back.
///
/// The parity test can see that an export exists; it cannot see whether it
/// works — gutting the function body and leaving its name passes it, and that
/// was tried. This is where the behaviour is actually checked.
@Suite("Keeping the record")
struct BackupTests {

    private func model() throws -> Model {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("chotki-test-\(UUID().uuidString).sqlite").path
        return Model(store: try SQLiteStore(path: path))
    }

    @Test("everything comes back")
    func roundTrip() throws {
        let from = try model()
        from.take(RuleLibrary.bundled.first { $0.id == "morning-prayers" }!)
        let entry = try #require(from.entries(on: from.today).first)
        from.toggleKept(entry)

        let data = try #require(from.exportBackup())
        #expect(!data.isEmpty)

        let to = try model()
        #expect(to.rules.isEmpty)
        to.restore(from: data)

        #expect(to.rules.map(\.title) == ["Morning prayers"])
        #expect(to.entries(on: to.today).first?.isKept == true)
    }

    /// A restore is a merge. Nothing already here is removed — a restore that
    /// silently wiped a month would be far worse than a duplicate.
    @Test("a restore never removes what is already there")
    func restoreMerges() throws {
        let mine = try model()
        mine.take(RuleLibrary.bundled.first { $0.id == "evening-prayers" }!)

        let other = try model()
        other.take(RuleLibrary.bundled.first { $0.id == "morning-prayers" }!)
        let data = try #require(other.exportBackup())

        mine.restore(from: data)

        let titles = Set(mine.rules.map(\.title))
        #expect(titles.contains("Evening prayers"))
        #expect(titles.contains("Morning prayers"))
    }

    @Test("restoring the same copy twice changes nothing the second time")
    func restoringTwiceIsSafe() throws {
        let from = try model()
        from.take(RuleLibrary.bundled.first { $0.id == "morning-prayers" }!)
        let data = try #require(from.exportBackup())

        let to = try model()
        to.restore(from: data)
        let after = to.rules.count
        to.restore(from: data)

        #expect(to.rules.count == after)
    }

    @Test("something that is not a backup does not destroy anything")
    func rubbishIsRefused() throws {
        let model = try model()
        model.take(RuleLibrary.bundled.first { $0.id == "morning-prayers" }!)

        model.restore(from: Data("this is not a backup".utf8))

        #expect(model.rules.count == 1, "a bad file took the record with it")
        #expect(model.trouble != nil, "it failed silently")
    }
}
