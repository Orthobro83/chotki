import Foundation
import Testing
@testable import ChotkiCore

@Suite("Due attention")
struct DueAttentionTests {
    let day = CalendarDate(year: 2026, month: 8, day: 19)!
    let zone = TimeZone(secondsFromGMT: 0)!

    @Test("an early warning leaves the navigation quiet; the due instant alerts once")
    func timedWarningAndDueInstant() throws {
        let rule = Rule(title: "Morning prayers", recurrence: .daily,
                        timeOfDay: TimeOfDay(hour: 6, minute: 30), category: RuleCategory.prayer.rawValue,
                        prayerIDs: PrayerSequence.all.first(where: { $0.id == "morning" })?.prayerIDs)
        let activation = Activation(ruleID: rule.id, from: day)
        let plan = Scheduler(policy: .default, timeZone: zone, includesDueAlert: true)
            .plan(rules: [rule], activations: [activation], occurrences: [], on: day)
        #expect(plan.count == 2)
        let early = try #require(plan.first)
        let due = try #require(plan.last)
        #expect(DueAttention.destination(for: early, rule: rule, timeZone: zone) == nil)
        #expect(DueAttention.destination(for: due, rule: rule, timeZone: zone) == .prayers)

        var ticker = ReminderTicker()
        #expect(ticker.tick(planned: plan, now: early.fireAt, timeZone: zone).show.map(\.id) == [early.id])
        #expect(ticker.tick(planned: plan, now: due.fireAt, timeZone: zone).show.map(\.id) == [due.id])
        #expect(ticker.tick(planned: plan, now: due.fireAt.addingTimeInterval(30), timeZone: zone).show.isEmpty)
    }

    @Test("an explicit due lead is not scheduled twice")
    func explicitDueLead() {
        let rule = Rule(title: "Read the day's Gospel", recurrence: .daily,
                        timeOfDay: TimeOfDay(hour: 12, minute: 0), category: RuleCategory.reading.rawValue,
                        reminders: RuleReminders(leads: [.atTheTime]))
        let plan = Scheduler(timeZone: zone, includesDueAlert: true)
            .plan(rules: [rule], activations: [Activation(ruleID: rule.id, from: day)], occurrences: [], on: day)
        #expect(plan.count == 1)
        #expect(plan.first.flatMap { DueAttention.destination(for: $0, rule: rule, timeZone: zone) } == .reading)
    }

    @Test("settled and silenced rules do not raise attention")
    func settlementAndSilence() {
        let rule = Rule(title: "Evening prayers", recurrence: .daily,
                        timeOfDay: TimeOfDay(hour: 21, minute: 30))
        let active = [Activation(ruleID: rule.id, from: day)]
        let kept = [Occurrence(ruleID: rule.id, date: day, status: .completed)]
        #expect(Scheduler(timeZone: zone, includesDueAlert: true)
            .plan(rules: [rule], activations: active, occurrences: kept, on: day).isEmpty)
        #expect(Scheduler(policy: .silent, timeZone: zone, includesDueAlert: true)
            .plan(rules: [rule], activations: active, occurrences: [], on: day).isEmpty)
    }
}
