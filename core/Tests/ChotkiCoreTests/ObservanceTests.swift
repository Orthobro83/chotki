import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

/// Stands in for the Phase 3 liturgical layer: every Wednesday and Friday is a
/// fast, the Dormition is a great feast.
private struct StubCalendar: LiturgicalDayProvider {
    func isFastDay(_ date: CalendarDate) -> Bool {
        date.weekday == .wednesday || date.weekday == .friday
    }
    func isGreatFeast(_ date: CalendarDate) -> Bool {
        date.month == 8 && date.day == 28
    }
    func season(_ date: CalendarDate) -> FastingSeason? {
        (date.month == 3) ? .greatLent : nil
    }
}

@Suite("Observance settings")
struct ObservanceTests {

    private func rule(_ trigger: LiturgicalTrigger) -> (Rule, [Activation]) {
        let r = Rule(title: "Observance", recurrence: .liturgical(trigger))
        return (r, [Activation(ruleID: r.id, from: d(2026, 1, 1))])
    }

    private func due(_ trigger: LiturgicalTrigger, _ settings: ObservanceSettings) -> [CalendarDate] {
        let (r, activations) = rule(trigger)
        let engine = RecurrenceEngine(liturgical: StubCalendar(), observances: settings)
        return engine.dueDates(
            rule: r, activations: activations, from: d(2026, 8, 1), through: d(2026, 8, 31)
        )
    }

    @Test("an observed fast drives its rule")
    func observedFastDrivesRules() {
        let days = due(.fastDay, ObservanceSettings(fasting: .observed))
        #expect(!days.isEmpty)
        #expect(days.allSatisfy { $0.weekday == .wednesday || $0.weekday == .friday })
    }

    // Someone who cannot fast for health reasons still sees the day on the
    // calendar. They are simply never asked to keep it, and never scored on it.
    @Test("a fast that is only shown never becomes due", arguments: [Observance.shown, .hidden])
    func shownOrHiddenFastIsNeverDue(state: Observance) {
        #expect(due(.fastDay, ObservanceSettings(fasting: state)).isEmpty)
    }

    // No parish within reach means a Liturgy on a great feast is not something
    // that can be attended. The feast is still worth seeing.
    @Test("a feast that is only shown never becomes due", arguments: [Observance.shown, .hidden])
    func shownOrHiddenFeastIsNeverDue(state: Observance) {
        #expect(due(.greatFeast, ObservanceSettings(feasts: state)).isEmpty)
    }

    @Test("fasting and feasts are settable independently")
    func independentSettings() {
        let fastOnly = ObservanceSettings(fasting: .observed, feasts: .shown)
        #expect(!due(.fastDay, fastOnly).isEmpty)
        #expect(due(.greatFeast, fastOnly).isEmpty)

        let feastOnly = ObservanceSettings(fasting: .shown, feasts: .observed)
        #expect(due(.fastDay, feastOnly).isEmpty)
        #expect(!due(.greatFeast, feastOnly).isEmpty)
    }

    @Test("a fasting season follows the fasting setting, not the feast one")
    func seasonFollowsFasting() {
        let engine = RecurrenceEngine(
            liturgical: StubCalendar(),
            observances: ObservanceSettings(fasting: .observed, feasts: .hidden)
        )
        let (r, activations) = rule(.season(.greatLent))
        let days = engine.dueDates(
            rule: r, activations: activations, from: d(2026, 3, 1), through: d(2026, 3, 31)
        )
        #expect(days.count == 31)
    }

    // The important property: standing an observance down is a pause, not a
    // failure. The days leave the record entirely rather than accruing as misses.
    @Test("standing an observance down removes its days rather than failing them")
    func standingDownIsNotFailure() {
        let (r, activations) = rule(.fastDay)
        let observed = RecurrenceEngine(
            liturgical: StubCalendar(), observances: ObservanceSettings(fasting: .observed)
        )
        let stoodDown = RecurrenceEngine(
            liturgical: StubCalendar(), observances: ObservanceSettings(fasting: .shown)
        )
        let before = observed.dueDates(
            rule: r, activations: activations, from: d(2026, 8, 1), through: d(2026, 8, 31)
        )
        let after = stoodDown.dueDates(
            rule: r, activations: activations, from: d(2026, 8, 1), through: d(2026, 8, 31)
        )
        #expect(before.count == 8, "four Wednesdays and four Fridays in August 2026")
        #expect(after.isEmpty, "nothing is due, so nothing can be scored as missed")
    }

    @Test("defaults show the calendar without expecting anything of it")
    func defaultsAreInformationalOnly() {
        #expect(ObservanceSettings.default.fasting == .shown)
        #expect(ObservanceSettings.default.feasts == .shown)
        #expect(!ObservanceSettings.default.fasting.drivesRules)
        #expect(ObservanceSettings.default.fasting.isVisible)
        #expect(!ObservanceSettings.plain.fasting.isVisible)
    }

    @Test("settings survive a round trip")
    func codable() throws {
        let settings = ObservanceSettings(fasting: .hidden, feasts: .observed)
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(ObservanceSettings.self, from: data) == settings)
    }
}

/// The Church lifts the Wednesday and Friday fast in several stretches of the
/// year. A rule that simply disappeared on those days would look broken and
/// teach nothing.
@Suite("Dispensations")
struct DispensationTests {

    /// Bright Week is fast-free; everything else here is an ordinary fast.
    private struct BrightWeekCalendar: LiturgicalDayProvider {
        func isFastDay(_ date: CalendarDate) -> Bool {
            date.weekday == .wednesday || date.weekday == .friday
        }
        func isGreatFeast(_ date: CalendarDate) -> Bool { false }
        func season(_ date: CalendarDate) -> FastingSeason? { nil }
        func fastFreeReason(_ date: CalendarDate) -> String? {
            (13...18).contains(date.day) && date.month == 4 ? "Bright Week" : nil
        }
    }

    private func fastRule() -> (Rule, [Activation]) {
        let rule = Rule(
            title: "The Wednesday and Friday fast",
            recurrence: .weekly(days: [.wednesday, .friday]),
            category: RuleCategory.fasting.rawValue
        )
        return (rule, [Activation(ruleID: rule.id, from: d(2026, 1, 1))])
    }

    private var engine: RecurrenceEngine {
        RecurrenceEngine(liturgical: BrightWeekCalendar(),
                         observances: ObservanceSettings(fasting: .observed))
    }

    @Test("a dispensed day is not due, so it can never be missed")
    func dispensedIsNotDue() {
        let (rule, activations) = fastRule()
        let due = engine.dueDates(
            rule: rule, activations: activations, from: d(2026, 4, 13), through: d(2026, 4, 18)
        )
        #expect(due.isEmpty, "Bright Week Wednesday and Friday are not kept")
    }

    @Test("a dispensed day is reported separately, with its reason")
    func dispensedIsExplained() {
        let (rule, activations) = fastRule()
        let lifted = engine.dispensations(
            rule: rule, activations: activations, from: d(2026, 4, 13), through: d(2026, 4, 18)
        )
        #expect(lifted.count == 2, "the Wednesday and the Friday")
        #expect(lifted.allSatisfy { $0.reason == "Bright Week" })
        #expect(lifted.map(\.date.weekday).sorted { $0.rawValue < $1.rawValue }
                == [.wednesday, .friday])
    }

    @Test("ordinary weeks are unaffected")
    func ordinaryWeeksStillApply() {
        let (rule, activations) = fastRule()
        let due = engine.dueDates(
            rule: rule, activations: activations, from: d(2026, 8, 17), through: d(2026, 8, 22)
        )
        #expect(due.count == 2)
        #expect(engine.dispensations(
            rule: rule, activations: activations, from: d(2026, 8, 17), through: d(2026, 8, 22)
        ).isEmpty)
    }

    // Dispensation is about fasting. A prayer rule falling in Bright Week is
    // still a prayer rule.
    @Test("a rule that is not about fasting is never dispensed")
    func onlyFastingRulesAreDispensed() {
        let prayer = Rule(
            title: "Morning prayers", recurrence: .daily,
            category: RuleCategory.prayer.rawValue
        )
        let activations = [Activation(ruleID: prayer.id, from: d(2026, 1, 1))]
        let due = engine.dueDates(
            rule: prayer, activations: activations, from: d(2026, 4, 13), through: d(2026, 4, 18)
        )
        #expect(due.count == 6, "prayer continues through Bright Week")
        #expect(engine.dispensations(
            rule: prayer, activations: activations, from: d(2026, 4, 13), through: d(2026, 4, 18)
        ).isEmpty)
    }

    @Test("a dispensed day outside the rule's activation is not reported at all")
    func dispensationRespectsActivation() {
        let rule = Rule(
            title: "The Wednesday and Friday fast",
            recurrence: .weekly(days: [.wednesday, .friday]),
            category: RuleCategory.fasting.rawValue
        )
        // Taken on after Bright Week.
        let activations = [Activation(ruleID: rule.id, from: d(2026, 5, 1))]
        #expect(engine.dispensations(
            rule: rule, activations: activations, from: d(2026, 4, 13), through: d(2026, 4, 18)
        ).isEmpty)
    }
}

@Suite("Naming the fast-free stretches")
struct FastFreeReasonTests {

    private func day(
        _ date: CalendarDate, observed: CalendarDate, paschaDistance: Int,
        fastLevel: Int, exception: Int, title: String?
    ) -> LiturgicalDay {
        LiturgicalDay(
            civilDate: date, reckoning: .julian, observedDate: observed,
            tone: nil, title: title, summaryTitle: title ?? "", saints: [], feasts: [],
            fastLevel: fastLevel, fastLevelDescription: fastLevel == 0 ? "No Fast" : "Fast",
            fastException: exception,
            fastExceptionDescription: exception == 11 ? "Fast Free" : nil,
            abstentions: [], feastLevel: 0, feastLevelDescription: "Liturgy",
            readings: [], paschaDistance: paschaDistance, fetchedAt: Date()
        )
    }

    // Each of these matches real orthocal data for 2026.
    @Test("Bright Week names itself")
    func brightWeek() {
        let d = day(CalendarDate(year: 2026, month: 4, day: 15)!,
                    observed: CalendarDate(year: 2026, month: 4, day: 2)!,
                    paschaDistance: 3, fastLevel: 0, exception: 11, title: "Bright Wednesday")
        #expect(d.fastFreeReason == "Bright Week")
    }

    @Test("the week after Pentecost is recognised by its distance from Pascha")
    func trinityWeek() {
        let d = day(CalendarDate(year: 2026, month: 6, day: 3)!,
                    observed: CalendarDate(year: 2026, month: 5, day: 21)!,
                    paschaDistance: 52, fastLevel: 0, exception: 11,
                    title: "Wednesday of the 1st week after Pentecost")
        #expect(d.fastFreeReason == "the week after Pentecost")
    }

    @Test("the week of the Publican and the Pharisee")
    func publicanAndPharisee() {
        let d = day(CalendarDate(year: 2026, month: 2, day: 4)!,
                    observed: CalendarDate(year: 2026, month: 1, day: 22)!,
                    paschaDistance: -67, fastLevel: 0, exception: 11, title: nil)
        #expect(d.fastFreeReason == "the week of the Publican and the Pharisee")
    }

    @Test("the days between the Nativity and Theophany, by old-style date")
    func svyatki() {
        let d = day(CalendarDate(year: 2026, month: 1, day: 14)!,
                    observed: CalendarDate(year: 2026, month: 1, day: 1)!,
                    paschaDistance: 269, fastLevel: 0, exception: 11,
                    title: "Wednesday of the 32nd week after Pentecost")
        #expect(d.fastFreeReason == "the days between the Nativity and Theophany")
    }

    @Test("an ordinary fast day has no dispensation")
    func ordinaryFastDay() {
        let d = day(CalendarDate(year: 2026, month: 8, day: 19)!,
                    observed: CalendarDate(year: 2026, month: 8, day: 6)!,
                    paschaDistance: 129, fastLevel: 4, exception: 4,
                    title: "Wednesday of the 12th week after Pentecost")
        #expect(d.fastFreeReason == nil)
    }
}
