import Testing
import Foundation
import AppKit
import SwiftUI
@testable import Chotki
@testable import ChotkiCore

@MainActor
private func makeModel(store: any Store = InMemoryStore()) -> AppModel {
    AppModel(
        store: store,
        notifier: SilentReflectionNotifier(),
        launchAtLogin: NoReflectionLaunchAtLogin(),
        storage: .none(),
        startsReminders: false,
        writesBackups: false
    )
}

private struct SilentReflectionNotifier: Notifier {
    var supportsActions: Bool { true }
    func requestAuthorization() async throws -> Bool { true }
    func show(_ request: NotificationRequest) async throws {}
    func cancel(ids: [String]) async {}
    var actionEvents: AsyncStream<NotificationActionEvent> { AsyncStream { $0.finish() } }
}

private struct NoReflectionLaunchAtLogin: LaunchAtLogin {
    var isEnabled: Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

/// Forwards everything to a real store but can be told to refuse answers, so
/// the "a failed write still repaints" rule can actually be exercised.
/// `InMemoryStore` is final, hence delegation rather than a subclass.
private final class RefusingStore: Store, @unchecked Sendable {
    struct Refused: Error {}
    private let inner = InMemoryStore()
    var refusing = false

    func save(_ entry: ReflectionEntry) throws {
        if refusing { throw Refused() }
        try inner.save(entry)
    }

    func save(_ rule: Rule) throws { try inner.save(rule) }
    func rule(id: UUID) throws -> Rule? { try inner.rule(id: id) }
    func rules(includeArchived: Bool) throws -> [Rule] {
        try inner.rules(includeArchived: includeArchived)
    }
    func save(_ activation: Activation) throws { try inner.save(activation) }
    func removeActivation(id: UUID) throws { try inner.removeActivation(id: id) }
    func activations(ruleID: UUID?) throws -> [Activation] { try inner.activations(ruleID: ruleID) }
    func save(_ occurrence: Occurrence) throws { try inner.save(occurrence) }
    func occurrences(
        ruleID: UUID?, from: CalendarDate?, through: CalendarDate?
    ) throws -> [Occurrence] {
        try inner.occurrences(ruleID: ruleID, from: from, through: through)
    }
    func removeOccurrence(ruleID: UUID, date: CalendarDate) throws {
        try inner.removeOccurrence(ruleID: ruleID, date: date)
    }
    func saveLiturgicalDay(_ day: LiturgicalDay) throws { try inner.saveLiturgicalDay(day) }
    func liturgicalDay(civilDate: CalendarDate, reckoning: Reckoning) throws -> LiturgicalDay? {
        try inner.liturgicalDay(civilDate: civilDate, reckoning: reckoning)
    }
    func liturgicalDays(
        reckoning: Reckoning, from: CalendarDate, through: CalendarDate
    ) throws -> [LiturgicalDay] {
        try inner.liturgicalDays(reckoning: reckoning, from: from, through: through)
    }
    func clearLiturgicalCache(reckoning: Reckoning?) throws {
        try inner.clearLiturgicalCache(reckoning: reckoning)
    }
    func loadSettings() throws -> AppSettings? { try inner.loadSettings() }
    func saveSettings(_ settings: AppSettings) throws { try inner.saveSettings(settings) }
    func reflections() throws -> [Reflection] { try inner.reflections() }
    func save(_ reflection: Reflection) throws { try inner.save(reflection) }
    func reflectionEntries(
        weekday: Weekday?, from: CalendarDate?, through: CalendarDate?
    ) throws -> [ReflectionEntry] {
        try inner.reflectionEntries(weekday: weekday, from: from, through: through)
    }
}

@Suite("Reflections in the app")
@MainActor
struct ReflectionsAppModelTests {

    @Test("the seven arrive on first launch without anything being enabled")
    func seededOnLaunch() {
        let model = makeModel()
        #expect(model.reflections.count == 7)
        #expect(model.reflection(for: .sunday).title == "Notice the Resistance")
        // The questions are the section's content. The rules that answer them
        // are not, and stay in the library until they are taken on.
        #expect(model.rules.isEmpty)
    }

    /// An answer belongs to its weekday, not to today. Writing on Sunday's card
    /// on a Wednesday files it under this week's Sunday.
    @Test("an answer is filed under its own weekday's date")
    func filedUnderItsWeekday() {
        let model = makeModel()
        for weekday in Weekday.allCases {
            #expect(model.dateOfCurrentWeek(weekday).weekday == weekday)
        }
        let today = CalendarDate(Date(), in: .current)
        #expect(model.dateOfCurrentWeek(today.weekday) == today)
    }

    @Test("writing an answer keeps it and marks the day answered")
    func writingAnAnswer() {
        let model = makeModel()
        #expect(model.hasAnsweredToday(.sunday) == false)

        model.saveReflection(.sunday, text: "  what I noticed  ")

        #expect(model.hasAnsweredToday(.sunday))
        let series = model.reflectionSeries(for: .sunday)
        #expect(series.count == 1)
        #expect(series.entries.first?.text == "what I noticed", "trimmed on the way in")
        #expect(series.entries.first?.question.title == "Notice the Resistance")
    }

    @Test("an empty answer is not written")
    func emptyIsNotWritten() {
        let model = makeModel()
        model.saveReflection(.sunday, text: "   \n  ")
        #expect(model.hasAnsweredToday(.sunday) == false)
        #expect(model.reflectionEntries.isEmpty)
    }

    /// The snapshot rule, at the level someone actually touches: rewriting the
    /// question must not reach an answer already written.
    @Test("rewriting a question leaves answers already written alone")
    func rewritingLeavesAnswersAlone() {
        let model = makeModel()
        model.saveReflection(.sunday, text: "before the rewrite")

        model.rewriteReflection(.sunday, to: ReflectionQuestion(
            title: "Something else", notice: "n", task: "t"))

        #expect(model.reflection(for: .sunday).title == "Something else")
        #expect(model.reflectionSeries(for: .sunday).entries.first?.question.title
                == "Notice the Resistance")
    }

    @Test("a rewritten question survives the next launch")
    func rewriteSurvivesReload() {
        let store = InMemoryStore()
        let model = makeModel(store: store)
        model.rewriteReflection(.friday, to: ReflectionQuestion(
            title: "My own Friday", notice: "n", task: "t"))

        // A second model over the same store is the next launch, seeding and all.
        let again = makeModel(store: store)
        #expect(again.reflection(for: .friday).title == "My own Friday")
        #expect(again.reflections.count == 7)
    }

    @Test("a question can be put back to what it shipped with")
    func restoringTheBundledWording() {
        let model = makeModel()
        model.rewriteReflection(.tuesday, to: ReflectionQuestion(
            title: "elsewhere", notice: "n", task: "t"))
        model.restoreBundledReflection(.tuesday)
        #expect(model.reflection(for: .tuesday).matchesBundled)
    }

    /// Learned on the web and written down in the decisions: persist and
    /// display are separate concerns. A write that cannot reach the store must
    /// still show the entry, or a successful save looks like a dead button.
    @Test("an answer that cannot be saved is still shown, and the failure is said")
    func failedWriteStillShows() {
        let store = RefusingStore()
        let model = makeModel(store: store)
        store.refusing = true

        model.saveReflection(.sunday, text: "written anyway")

        #expect(model.reflectionSeries(for: .sunday).entries.first?.text == "written anyway")
        #expect(model.notice != nil, "the failure is reported rather than swallowed")
    }

    @Test("a journal exports and imports whole")
    func exportAndImport() throws {
        let model = makeModel()
        model.saveReflection(.sunday, text: "one")
        model.saveReflection(.wednesday, text: "two")
        let data = try model.exportReflectionsJSON()

        let fresh = makeModel()
        let result = fresh.importReflectionsJSON(data)

        #expect(result?.addedCount == 2)
        #expect(fresh.reflectionEntries.count == 2)
    }

    @Test("an import adds what is new and leaves what is here")
    func importMerges() throws {
        let model = makeModel()
        model.saveReflection(.sunday, text: "mine")
        let data = try model.exportReflectionsJSON()

        let again = model.importReflectionsJSON(data)
        #expect(again?.addedCount == 0)
        #expect(again?.alreadyPresent == 1)
        #expect(model.reflectionEntries.count == 1)
        #expect(model.reflectionEntries.first?.text == "mine")
    }

    @Test("a file that is not a journal changes nothing and says so")
    func rubbishImport() {
        let model = makeModel()
        model.saveReflection(.sunday, text: "mine")
        model.notice = nil

        let result = model.importReflectionsJSON(Data("not json at all".utf8))

        #expect(result == nil)
        #expect(model.notice != nil)
        #expect(model.reflectionEntries.count == 1)
    }
}

@Suite("Reflections in the window")
@MainActor
struct ReflectionsSectionTests {

    /// The mistake this project has already made twice: a feature that works on
    /// one surface and is unreachable on the other.
    @Test("the sidebar offers it")
    func sidebarHasIt() {
        #expect(MainSection.allCases.contains(.reflections))
        #expect(MainSection.reflections.rawValue == "Reflections")
        #expect(!MainSection.reflections.symbol.isEmpty)
    }

    /// Deliberately window-only: at 400 points the popover cannot hold seven
    /// questions, seven text fields and a journal, and its job is the day's
    /// rule. Stated as a test so it reads as a decision rather than a gap.
    @Test("nothing in the popover navigates to it")
    func notInThePopover() {
        // Every Screen the popover can ask for routes somewhere that is not
        // Reflections — there is no Screen case for it at all.
        let requests: [Screen] = [
            .main, .library, .settings, .glossary(nil), .editor(nil),
            .prayerRope, .prayers(UUID()), .psalter
        ]
        for screen in requests {
            #expect(WindowRoute.route(for: screen) != .section(.reflections))
        }
    }
}

@Suite("Putting Reflections on the rule")
@MainActor
struct ReflectionsOnRuleTests {

    @Test("nothing is on the rule until it is asked for")
    func nothingByDefault() {
        let model = makeModel()
        #expect(model.hasReflectionsOnRule == false)
        #expect(model.rules.isEmpty)
        #expect(model.reflectionTemplate != nil)
    }

    /// One rule, recurring every day, reading simply "Reflection". Not seven —
    /// which question is being asked is the section's business, and seven
    /// entries in the day list said more about the machinery than the practice.
    @Test("it adds one daily rule, not seven")
    func addsOneDailyRule() {
        let model = makeModel()
        model.addReflectionsToRule()

        #expect(model.rules.count == 1)
        #expect(model.rules.first?.title == "Reflection")
        #expect(model.rules.first?.recurrence == .daily)
        #expect(model.hasReflectionsOnRule)
    }

    /// It is due every day of the week — "all 7 days, recurring".
    @Test("it comes due on every day of the week")
    func dueEveryDay() {
        let model = makeModel()
        model.addReflectionsToRule()

        let start = model.today
        for offset in 0..<7 {
            let day = start.adding(days: offset)
            let titles = model.entries(on: day).map(\.rule.title)
            #expect(titles.contains("Reflection"), "nothing due on \(day.weekday)")
        }
    }

    /// The row needs a way through to the section, and the pencil has to behave
    /// like any other rule's.
    @Test("the rule on the day points at the section")
    func rowPointsAtTheSection() {
        let model = makeModel()
        model.addReflectionsToRule()
        #expect(model.rules.first?.reference == .reflections)
    }

    @Test("pressing it twice adds nothing the second time")
    func idempotent() {
        let model = makeModel()
        model.addReflectionsToRule()
        model.addReflectionsToRule()
        #expect(model.rules.count == 1)
    }

    /// Taking it from the library and pressing the header button should not
    /// leave two.
    @Test("the library and the header button are the same rule")
    func libraryAndHeaderAgree() throws {
        let model = makeModel()
        let template = try #require(model.reflectionTemplate)
        model.take(on: template)
        #expect(model.hasReflectionsOnRule)

        model.addReflectionsToRule()
        #expect(model.rules.count == 1)
    }

    /// The library copies a template and keeps no link back, so a renamed copy
    /// is his rule rather than this one — and loses the way through with it.
    @Test("a renamed copy is his rule, not this one")
    func renamedStopsCounting() throws {
        let model = makeModel()
        model.addReflectionsToRule()
        var renamed = try #require(model.rules.first)
        renamed.title = "My own reflections"
        model.save(renamed, isNew: false)

        #expect(model.hasReflectionsOnRule == false)
        // Spelled out: against an Optional<RuleReference>, a bare `.none`
        // resolves to `Optional.none` — nil — and the assertion quietly becomes
        // "the rule is gone" instead of "the rule no longer points anywhere".
        #expect(model.rules.first?.reference == RuleReference.none)
        #expect(model.rules.count == 1, "nothing was added or lost by renaming")
    }
}

@Suite("Reflections is reachable from both surfaces")
@MainActor
struct ReflectionsReachabilityTests {

    /// The mistake this app has made twice: a control that works in the window
    /// and does nothing in the popover.
    @Test("the window routes the request to the section")
    func windowRoutes() {
        #expect(WindowRoute.route(for: .reflections()) == .section(.reflections))
    }

    @Test("the sidebar offers it")
    func sidebarHasIt() {
        #expect(MainSection.allCases.contains(.reflections))
        #expect(MainSection.reflections.rawValue == "Reflections")
    }

    /// Tapping the way through from Tuesday's rule should land on Tuesday's
    /// question, not at the top of a seven-day scroll.
    @Test("the way through carries the day it was opened from", arguments: Weekday.allCases)
    func carriesTheWeekday(weekday: Weekday) {
        let model = makeModel()
        model.openReflections(on: weekday)

        #expect(model.screen == .reflections(weekday: weekday))
        #expect(model.reflectionsOpenAt == weekday)
        #expect(WindowRoute.route(for: model.screen) == .section(.reflections),
                "however it was opened, it still lands on the section")
    }

    /// Opened from the sidebar there is no day in mind, and the section should
    /// start where it starts.
    @Test("opened with no day in mind, it stays at the top")
    func noWeekday() {
        let model = makeModel()
        model.openReflections(on: nil)
        #expect(model.reflectionsOpenAt == nil)
        #expect(model.screen == .reflections(weekday: nil))
    }

    /// The popover cannot hold the section at 400 points, so it offers the way
    /// to the window instead — which is a landing place, not a dead end.
    @Test("the popover has somewhere to put the request")
    func popoverLands() {
        let model = makeModel()
        model.openReflections(on: .tuesday)
        #expect(model.screen == .reflections(weekday: .tuesday),
                "the popover keeps the request rather than dropping it")
    }
}

/// The window's size belongs to whoever set it, not to what is inside it.
///
/// Opening the Reflections explainer stretched the window to the full height of
/// the screen: `NSHostingView` defaults to `.standardBounds`, so AppKit asked
/// SwiftUI for an intrinsic size, and a `ScrollView` answers that question with
/// the height of all its content rather than the height it is being shown at.
/// Anything that invalidated the layout while a tall section was open moved the
/// window.
@Suite("The window keeps the size it was given")
@MainActor
struct WindowSizingTests {

    @Test("nothing inside the window can resize it")
    func hostingViewDoesNotSizeTheWindow() {
        let model = makeModel()
        let host = MainWindowController.hostingView(model: model)
        #expect(host.sizingOptions.isEmpty,
                "SwiftUI can resize the window again — this is the explainer bug returning")
    }

    /// The mechanism itself, and proof the fix is doing something.
    ///
    /// A hosting view left on the defaults reports an intrinsic height for this
    /// content — the whole scrolled section, far taller than any window anyone
    /// would set. With the options cleared it reports none at all, and AppKit
    /// has nothing to resize the window to.
    @Test("cleared options mean no intrinsic size to chase")
    func noIntrinsicSizeToChase() {
        let model = makeModel()

        let defaulted = NSHostingView(rootView: ReflectionsView(model: model))
        defaulted.frame = NSRect(x: 0, y: 0, width: 640, height: 660)
        defaulted.layoutSubtreeIfNeeded()
        let chased = defaulted.intrinsicContentSize.height
        #expect(chased > 660,
                "the defaults no longer report a tall intrinsic height — if SwiftUI changed, this test is now proving nothing")

        let fixed = MainWindowController.hostingView(model: model)
        fixed.frame = NSRect(x: 0, y: 0, width: 940, height: 660)
        fixed.layoutSubtreeIfNeeded()
        #expect(fixed.intrinsicContentSize.height == NSView.noIntrinsicMetric)
        #expect(fixed.intrinsicContentSize.width == NSView.noIntrinsicMetric)
    }
}
