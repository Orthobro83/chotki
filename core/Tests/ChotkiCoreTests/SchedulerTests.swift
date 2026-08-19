import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}
private let zone = TimeZone(identifier: "Europe/London")!

private func localTime(_ instant: Date) -> String {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = zone
    let p = c.dateComponents([.hour, .minute], from: instant)
    return String(format: "%02d:%02d", p.hour!, p.minute!)
}

@Suite("Scheduler")
struct SchedulerTests {

    private func scheduler(_ policy: ReminderPolicy = .default) -> Scheduler {
        Scheduler(policy: policy, timeZone: zone)
    }

    private func timedRule(_ hour: Int, _ minute: Int) -> (Rule, [Activation]) {
        let rule = Rule(
            title: "Evening prayers", recurrence: .daily,
            timeOfDay: TimeOfDay(hour: hour, minute: minute)
        )
        return (rule, [Activation(ruleID: rule.id, from: d(2026, 1, 1))])
    }

    private func untimedRule() -> (Rule, [Activation]) {
        let rule = Rule(title: "Jesus prayer — 50 knots", recurrence: .daily)
        return (rule, [Activation(ruleID: rule.id, from: d(2026, 1, 1))])
    }

    // MARK: timed rules

    @Test("a timed rule warns ten minutes ahead")
    func timedLeadTime() throws {
        let (rule, activations) = timedRule(21, 30)
        let planned = scheduler().plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        #expect(planned.count == 1)
        #expect(localTime(try #require(planned.first).fireAt) == "21:20")
        #expect(planned[0].request.body == "At 21:30")
    }

    // The bug this test exists to prevent: with quiet hours ending 06:30, a
    // 06:30 rule has a lead time of 06:20 — inside the quiet window. Silencing
    // it would make the app useless for the rule people most want kept.
    @Test("a reminder the user set themselves is never silenced by quiet hours")
    func timedReminderSurvivesQuietHours() throws {
        let (rule, activations) = timedRule(6, 30)
        let planned = scheduler().plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        #expect(planned.count == 1, "morning prayers must still remind")
        #expect(localTime(try #require(planned.first).fireAt) == "06:20")
    }

    @Test("a rule not due that day produces nothing")
    func notDueProducesNothing() {
        let rule = Rule(
            title: "Sunday Liturgy", recurrence: .weekly(days: [.sunday]),
            timeOfDay: TimeOfDay(hour: 9, minute: 0)
        )
        let activations = [Activation(ruleID: rule.id, from: d(2026, 1, 1))]
        // 19 August 2026 is a Wednesday.
        #expect(scheduler().plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        ).isEmpty)
    }

    @Test("a rule outside its activation produces nothing")
    func pausedProducesNothing() {
        let rule = Rule(title: "Evening prayers", recurrence: .daily, timeOfDay: TimeOfDay(hour: 21, minute: 30))
        let paused = [Activation(ruleID: rule.id, from: d(2026, 1, 1), to: d(2026, 5, 10))]
        #expect(scheduler().plan(
            rules: [rule], activations: paused, occurrences: [], on: d(2026, 8, 19)
        ).isEmpty)
    }

    // MARK: untimed rules

    @Test("the default spreads reminders across the waking day")
    func untimedSpreadsAcrossDay() {
        let (rule, activations) = untimedRule()
        let planned = scheduler().plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        #expect(planned.count == 4, "the default cap")
        let times = planned.map { localTime($0.fireAt) }
        #expect(times.first == "07:00", "starts at the first waking hour")
        #expect(times.last == "21:00", "and is still in front of you in the evening")
        // The point of spreading: no two reminders back to back.
        #expect(Set(zip(times, times.dropFirst()).map { $1 }).count == 3)
    }

    // The literal original cadence, kept available. Four nudges before
    // breakfast and then silence for fourteen hours.
    @Test("the hourly policy clusters in the morning")
    func untimedHourlyClusters() {
        let (rule, activations) = untimedRule()
        let planned = Scheduler(policy: .hourly, timeZone: zone).plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        #expect(planned.map { localTime($0.fireAt) } == ["07:00", "08:00", "09:00", "10:00"])
    }

    @Test("nothing is ever scheduled inside the quiet window")
    func nothingInQuietHours() {
        let (rule, activations) = untimedRule()
        let planned = Scheduler(policy: ReminderPolicy(untimedCap: 0, spacing: .hourly), timeZone: zone).plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        let times = planned.map { localTime($0.fireAt) }
        #expect(times.first == "07:00")
        #expect(times.last == "21:00")
        #expect(!times.contains("03:00"), "the 3am case this exists to prevent")
        #expect(!times.contains("22:00"))
        #expect(!times.contains("06:00"))
    }

    @Test("the gentle policy asks once and then leaves you alone")
    func gentlePolicy() {
        let (rule, activations) = untimedRule()
        let planned = Scheduler(policy: .gentle, timeZone: zone).plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        #expect(planned.count == 1)
    }

    // MARK: settling a day

    @Test("completing silences the rest of the day", arguments: [
        OccurrenceStatus.completed, .completedLate, .skipped, .cancelled, .moved
    ])
    func settledStatusesSilenceTheDay(status: OccurrenceStatus) {
        let (rule, activations) = untimedRule()
        let occurrence = Occurrence(ruleID: rule.id, date: d(2026, 8, 19), status: status)
        #expect(scheduler().plan(
            rules: [rule], activations: activations, occurrences: [occurrence], on: d(2026, 8, 19)
        ).isEmpty, "\(status) must stop the reminders")
    }

    @Test("an archived rule reminds about nothing")
    func archivedRuleIsSilent() {
        var (rule, activations) = timedRule(21, 30)
        rule.archivedAt = Date()
        #expect(scheduler().plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        ).isEmpty)
    }

    @Test("cancellation covers every reminder armed for that day")
    func cancellationIsComplete() {
        let (rule, activations) = untimedRule()
        let planned = scheduler().plan(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19)
        )
        let cancelled = scheduler().cancellationIDs(
            ruleID: rule.id, date: d(2026, 8, 19), rules: [rule], activations: activations
        )
        #expect(Set(cancelled) == Set(planned.map(\.id)), "no reminder may survive completion")
        #expect(!cancelled.isEmpty)
    }

    @Test("pending only returns reminders still ahead")
    func pendingFiltersThePast() throws {
        let (rule, activations) = untimedRule()
        let nineAM = try #require(d(2026, 8, 19).dueInstant(at: TimeOfDay(hour: 9, minute: 0)!, in: zone))
        let pending = scheduler().pending(
            rules: [rule], activations: activations, occurrences: [], on: d(2026, 8, 19), after: nineAM
        )
        #expect(pending.map { localTime($0.fireAt) } == ["12:00", "16:00", "21:00"],
                "the 07:00 reminder is behind us; the rest of the day is not")
    }

    // MARK: tone

    @Test("no reminder ever carries guilt language")
    func reminderCopyIsNeutral() {
        let (timed, timedActivations) = timedRule(21, 30)
        let (untimed, untimedActivations) = untimedRule()
        let planned = scheduler().plan(
            rules: [timed, untimed],
            activations: timedActivations + untimedActivations,
            occurrences: [], on: d(2026, 8, 19)
        )
        #expect(!planned.isEmpty)
        let forbidden = ["overdue", "missed", "still", "again", "behind", "failed", "!", "don't forget"]
        for notification in planned {
            let text = (notification.request.title + " " + notification.request.body).lowercased()
            for word in forbidden {
                #expect(!text.contains(word), "\(text) contains \(word)")
            }
        }
    }
}

/// The Phase 4 proof: a month of ticks, headless, against an injected clock.
@Suite("A simulated month")
struct SimulatedMonthTests {

    @Test("a month of days produces reminders only when a rule is actually due")
    func simulatedMonth() throws {
        let morning = Rule(title: "Morning prayers", recurrence: .daily, timeOfDay: TimeOfDay(hour: 6, minute: 30))
        let liturgy = Rule(
            title: "Sunday Liturgy", recurrence: .weekly(days: [.sunday]),
            timeOfDay: TimeOfDay(hour: 9, minute: 0)
        )
        let knots = Rule(title: "Jesus prayer", recurrence: .daily)

        let rules = [morning, liturgy, knots]
        let activations = rules.map { Activation(ruleID: $0.id, from: d(2026, 8, 1)) }
        let scheduler = Scheduler(policy: .default, timeZone: zone)

        let clock = FixedClock(try #require(d(2026, 8, 1).dueInstant(at: TimeOfDay(hour: 0, minute: 0)!, in: zone)))
        var byRule: [UUID: Int] = [:]
        var everQuiet = false

        for day in 1...31 {
            let date = d(2026, 8, day)
            let planned = scheduler.plan(
                rules: rules, activations: activations, occurrences: [], on: date
            )
            for notification in planned {
                byRule[notification.ruleID, default: 0] += 1
                var c = Calendar(identifier: .gregorian)
                c.timeZone = zone
                let parts = c.dateComponents([.hour, .minute], from: notification.fireAt)
                let time = TimeOfDay(hour: parts.hour!, minute: parts.minute!)!
                // Timed reminders are exempt by design; untimed must never be quiet.
                if notification.request.body == "Today" && QuietHours.default.contains(time) {
                    everQuiet = true
                }
            }
            clock.advance(by: 24 * 60 * 60)
        }

        #expect(byRule[morning.id] == 31, "daily, every day of the month")
        #expect(byRule[liturgy.id] == 5, "five Sundays in August 2026")
        #expect(byRule[knots.id] == 31 * 4, "four reminders a day, capped")
        #expect(!everQuiet, "no untimed reminder landed in the quiet window across a whole month")
    }

    @Test("completing each day silences that day and no other")
    func completionIsPerDay() {
        let rule = Rule(title: "Evening prayers", recurrence: .daily, timeOfDay: TimeOfDay(hour: 21, minute: 30))
        let activations = [Activation(ruleID: rule.id, from: d(2026, 8, 1))]
        let scheduler = Scheduler(timeZone: zone)

        // Kept on the 19th only.
        let occurrences = [Occurrence(ruleID: rule.id, date: d(2026, 8, 19), status: .completed)]

        var reminded: [Int] = []
        for day in 17...21 {
            let planned = scheduler.plan(
                rules: [rule], activations: activations, occurrences: occurrences, on: d(2026, 8, day)
            )
            if !planned.isEmpty { reminded.append(day) }
        }
        #expect(reminded == [17, 18, 20, 21], "only the 19th is silent")
    }
}
