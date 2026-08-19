import Testing
import Foundation
@testable import Chotki
@testable import ChotkiCore

/// Stand-ins so nothing is scheduled, shown, or registered during a test.
private struct SilentNotifier: Notifier {
    var supportsActions: Bool { true }
    func requestAuthorization() async throws -> Bool { true }
    func show(_ request: NotificationRequest) async throws {}
    func cancel(ids: [String]) async {}
    var actionEvents: AsyncStream<NotificationActionEvent> { AsyncStream { $0.finish() } }
}

private struct NoLaunchAtLogin: LaunchAtLogin {
    var isEnabled: Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

@MainActor
private func makeModel() throws -> AppModel {
    AppModel(
        store: InMemoryStore(),
        notifier: SilentNotifier(),
        launchAtLogin: NoLaunchAtLogin(),
        storage: .none(),
        startsReminders: false
    )
}

/// A Wednesday and a Friday, so fast-day rules have somewhere to land.
private struct StubCalendar: LiturgicalDayProvider {
    func isFastDay(_ date: CalendarDate) -> Bool {
        date.weekday == .wednesday || date.weekday == .friday
    }
    func isGreatFeast(_ date: CalendarDate) -> Bool { false }
    func season(_ date: CalendarDate) -> FastingSeason? { nil }
}

@Suite("Taking rules on")
@MainActor
struct TakingRulesOnTests {

    @Test("a rule written by hand shows up on the day it is due")
    func ownRuleAppears() throws {
        let model = try makeModel()
        let rule = Rule(title: "Read the Psalter", recurrence: .daily)
        model.save(rule, isNew: true)

        let entries = model.entries(on: model.today)
        #expect(entries.count == 1)
        #expect(entries.first?.rule.title == "Read the Psalter")
    }

    // The bug found by hand: taking on the Wednesday and Friday fast changed
    // nothing at all, because a liturgical rule produces no due days while its
    // observance is merely shown — and shown is the default.
    @Test("taking on a fast rule turns fasting on rather than doing nothing")
    func fastRuleTurnsObservanceOn() throws {
        let model = try makeModel()
        #expect(model.settings.observances.fasting == .shown, "the default")

        let template = try #require(RuleLibrary.shared.template(id: "wednesday-friday-fast"))
        model.take(on: template)

        #expect(model.settings.observances.fasting == .observed,
                "taking it on is a statement of intent")
        #expect(model.rules.contains { $0.title == template.title })
        #expect(model.notice != nil, "and the change is stated, not silent")
    }

    @Test("a rule taken from the library is due, not merely stored")
    func libraryRuleBecomesDue() throws {
        let model = try makeModel()
        let template = try #require(RuleLibrary.shared.template(id: "morning-prayers"))
        model.take(on: template)

        let entries = model.entries(on: model.today)
        #expect(entries.contains { $0.rule.title == template.title },
                "storing a rule that never comes due is the same as doing nothing")
    }

    @Test("a template with no observance requirement leaves settings alone")
    func ordinaryTemplateDoesNotChangeSettings() throws {
        let model = try makeModel()
        let before = model.settings.observances
        model.take(on: try #require(RuleLibrary.shared.template(id: "evening-prayers")))
        #expect(model.settings.observances == before)
        #expect(model.notice == nil)
    }

    @Test("every liturgical template declares what it needs")
    func liturgicalTemplatesDeclareTheirTrigger() {
        for template in RuleLibrary.bundled {
            if case .liturgical(let trigger) = template.recurrence {
                #expect(template.requiredTrigger == trigger,
                        "\(template.id) would silently do nothing when taken on")
            } else {
                #expect(template.requiredTrigger == nil)
            }
        }
    }
}

@Suite("Marking rules kept")
@MainActor
struct MarkingKeptTests {

    private func modelWithRule() throws -> (AppModel, DayEntry) {
        let model = try makeModel()
        model.save(Rule(title: "Morning prayers", recurrence: .daily), isNew: true)
        let entry = try #require(model.entries(on: model.today).first)
        return (model, entry)
    }

    @Test("marking kept records it and shows as kept")
    func markKept() throws {
        let (model, entry) = try modelWithRule()
        #expect(!entry.isKept)

        model.toggleKept(entry)

        let updated = try #require(model.entries(on: model.today).first)
        #expect(updated.isKept)
        #expect(updated.status == .completed)
    }

    @Test("marking kept twice returns the day to simply due")
    func toggleBack() throws {
        let (model, entry) = try modelWithRule()
        model.toggleKept(entry)
        let kept = try #require(model.entries(on: model.today).first)
        model.toggleKept(kept)

        let cleared = try #require(model.entries(on: model.today).first)
        #expect(!cleared.isKept)
    }

    @Test("a day kept in the past counts as kept late")
    func keptLate() throws {
        let model = try makeModel()
        model.save(Rule(title: "Evening prayers", recurrence: .daily), isNew: true)
        model.selectedDate = model.today.adding(days: -1)

        // Yesterday is inside the activation only if the rule started then.
        let rule = try #require(model.rules.first)
        try model.store.save(Activation(ruleID: rule.id, from: model.today.adding(days: -7)))
        model.reload()

        let yesterday = try #require(model.entries(on: model.today.adding(days: -1)).first)
        model.toggleKept(yesterday)

        let updated = try #require(model.entries(on: model.today.adding(days: -1)).first)
        #expect(updated.status == .completedLate, "done, but after the day was out")
    }
}

@Suite("Pausing and resuming")
@MainActor
struct PausingTests {

    @Test("pausing takes a rule off the day, resuming puts it back")
    func pauseAndResume() throws {
        let model = try makeModel()
        model.save(Rule(title: "Jesus prayer", recurrence: .daily), isNew: true)
        let rule = try #require(model.rules.first)
        #expect(!model.isPaused(rule))

        model.standDown(rule)
        #expect(model.isPaused(rule))
        #expect(model.entries(on: model.today.adding(days: 1)).isEmpty,
                "tomorrow is no longer due")

        model.resume(rule)
        #expect(!model.isPaused(rule))
        #expect(!model.entries(on: model.today).isEmpty)
    }

    @Test("pausing keeps the day it happened on")
    func pauseIsInclusiveOfToday() throws {
        let model = try makeModel()
        model.save(Rule(title: "Morning prayers", recurrence: .daily), isNew: true)
        let rule = try #require(model.rules.first)
        model.standDown(rule)
        #expect(!model.entries(on: model.today).isEmpty,
                "standing down in the evening still counts today")
    }
}

/// Shared content navigates by setting `model.screen`, which is the popover's
/// mechanism. The window has a sidebar instead and must translate every one of
/// those requests — a screen it forgets is a button that silently does nothing
/// there while working perfectly in the popover. That is exactly what happened
/// to Add, Library, Terms, Settings and the edit pencil.
@Suite("Window routing")
@MainActor
struct WindowRoutingTests {

    @Test("every screen shared content can ask for lands somewhere")
    func everyScreenIsHandled() {
        // Every case of `Screen` except `.main`. Add a case to the enum and
        // this list must grow with it, or the new control is dead in the window.
        let requests: [Screen] = [
            .library, .settings, .glossary(nil), .glossary("pascha"),
            .editor(nil), .editor(UUID()), .prayerRope
        ]
        for screen in requests {
            #expect(WindowRoute.route(for: screen) != .stay,
                    "\(screen) would do nothing in the window")
        }
    }

    @Test("only the main screen stays put")
    func mainStays() {
        #expect(WindowRoute.route(for: .main) == .stay)
    }

    @Test("each request lands in the right place")
    func routesAreCorrect() {
        #expect(WindowRoute.route(for: .library) == .section(.library))
        #expect(WindowRoute.route(for: .settings) == .section(.settings))
        #expect(WindowRoute.route(for: .glossary("pascha")) == .glossary("pascha"))
        #expect(WindowRoute.route(for: .editor(nil)) == .editor(nil))
        #expect(WindowRoute.route(for: .prayerRope) == .section(.rope))
    }

    @Test("adding a rule opens the editor rather than being swallowed")
    func addOpensEditor() {
        #expect(WindowRoute.route(for: .editor(nil)) == .editor(nil))
        let id = UUID()
        #expect(WindowRoute.route(for: .editor(id)) == .editor(id))
    }
}

/// Mapping a String range onto an AttributedString index is the part of the
/// term linking most likely to be subtly wrong — off by one and the wrong
/// words get underlined.
@Suite("Linking terms in running text")
@MainActor
struct TermTextTests {
    let glossary = Glossary.shared

    private func links(in text: String) -> [(String, URL)] {
        let attributed = TermText.link(text, in: glossary)
        var found: [(String, URL)] = []
        for run in attributed.runs {
            if let url = run.link {
                found.append((String(attributed[run.range].characters), url))
            }
        }
        return found
    }

    @Test("a known term is linked, and the link covers exactly that word")
    func linksTheRightCharacters() {
        // A real fasting description, as the reading tab produces it.
        let found = links(in: "The calendar marks this as dormition fast — fish, wine and oil are allowed.")
        #expect(found.count == 2, "the season and the dispensation are both terms")
        for (word, url) in found {
            #expect(url.scheme == "chotki-term")
            #expect(!word.isEmpty)
            #expect(!word.hasPrefix(" "), "the link starts mid-word: \(word)")
            #expect(!word.hasSuffix(" "), "the link runs past the word: \(word)")
        }
    }

    @Test("the linked text matches the term it points at")
    func linkTargetsMatchTheirText() {
        for (word, url) in links(in: "Pascha, the Theotokos, and Great Lent.") {
            let slug = try! #require(url.host)
            let entry = try! #require(glossary.entry(slug: slug))
            let candidates = ([entry.term] + entry.aliases).map { $0.lowercased() }
            #expect(candidates.contains(word.lowercased()),
                    "\"\(word)\" was linked to \(slug), whose term is \"\(entry.term)\"")
        }
    }

    @Test("text with nothing to link is returned unchanged")
    func plainTextIsUntouched() {
        let text = "Some ordinary sentence about nothing in particular."
        #expect(links(in: text).isEmpty)
        #expect(String(TermText.link(text, in: glossary).characters) == text)
    }

    @Test("linking never alters the text itself")
    func textIsPreserved() {
        let samples = [
            "Martyr Andrew Stratelates and Companions",
            "The calendar marks this as dormition fast — fish, wine and oil are allowed.",
            "Wednesday of the 12th week after Pentecost"
        ]
        for text in samples {
            #expect(String(TermText.link(text, in: glossary).characters) == text)
        }
    }
}

/// The failure this covers: a rule tied to the church calendar sat on the list
/// while its observance was not being observed, so it could never come due and
/// simply did not appear. That could happen to a rule taken on before this was
/// handled, or restored from an older backup.
@Suite("Repairing stranded rules")
@MainActor
struct ObservanceReconciliationTests {

    private struct AlwaysFasting: LiturgicalDayProvider {
        func isFastDay(_ date: CalendarDate) -> Bool { true }
        func isGreatFeast(_ date: CalendarDate) -> Bool { false }
        func season(_ date: CalendarDate) -> FastingSeason? { nil }
    }

    @Test("a fast rule already on the list turns fasting back on at load")
    func repairsOnLoad() throws {
        let store = InMemoryStore()

        // A rule saved directly, as an older build would have left it: on the
        // list, with fasting merely shown.
        let rule = Rule(title: "The Wednesday and Friday fast", recurrence: .liturgical(.fastDay))
        try store.save(rule)
        try store.save(Activation(ruleID: rule.id, from: CalendarDate(Date(), in: .current)))
        try store.saveSettings(AppSettings.default)
        #expect(try store.loadSettings()?.observances.fasting == .shown)

        let model = AppModel(
            store: store, notifier: SilentNotifier(), launchAtLogin: NoLaunchAtLogin(),
            storage: .none(), startsReminders: false
        )

        #expect(model.settings.observances.fasting == .observed,
                "a rule that can never come due is worse than a changed setting")
        #expect(try store.loadSettings()?.observances.fasting == .observed, "and it is written down")
    }

    @Test("a paused fast rule does not force the observance on")
    func pausedRulesAreLeftAlone() throws {
        let store = InMemoryStore()
        let rule = Rule(title: "Great Lent", recurrence: .liturgical(.season(.greatLent)))
        try store.save(rule)
        let today = CalendarDate(Date(), in: .current)
        // Closed activation: the rule is stood down.
        try store.save(Activation(ruleID: rule.id, from: today.adding(days: -10), to: today.adding(days: -1)))
        try store.saveSettings(AppSettings.default)

        let model = AppModel(
            store: store, notifier: SilentNotifier(), launchAtLogin: NoLaunchAtLogin(),
            storage: .none(), startsReminders: false
        )
        #expect(model.settings.observances.fasting == .shown,
                "nothing is stranded, so nothing needs changing")
    }

    @Test("settings chosen in the app are written to the store")
    func settingsPersist() throws {
        let store = InMemoryStore()
        let model = AppModel(
            store: store, notifier: SilentNotifier(), launchAtLogin: NoLaunchAtLogin(),
            storage: .none(), startsReminders: false
        )
        model.update { $0.showOldStyleDates = true }
        #expect(try store.loadSettings()?.showOldStyleDates == true)
    }
}
