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
        storage: .ephemeral(),
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
        let requests: [Screen] = [
            .library, .settings, .glossary(nil), .glossary("pascha"),
            .editor(nil), .editor(UUID())
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
    }

    @Test("adding a rule opens the editor rather than being swallowed")
    func addOpensEditor() {
        #expect(WindowRoute.route(for: .editor(nil)) == .editor(nil))
        let id = UUID()
        #expect(WindowRoute.route(for: .editor(id)) == .editor(id))
    }
}
