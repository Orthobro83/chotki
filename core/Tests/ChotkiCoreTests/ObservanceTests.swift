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
