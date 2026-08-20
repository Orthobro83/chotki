import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}
private let zone = TimeZone(identifier: "Europe/London")!

/// 20 August 2026, mid-morning — so the 19th and everything before it has
/// elapsed, and today's evening rules have not.
private let now: Date = d(2026, 8, 20).dueInstant(at: TimeOfDay(hour: 10, minute: 0)!, in: zone)!

private func engine() -> ScoringEngine {
    ScoringEngine(timeZone: zone)
}

private func dailyRule(_ title: String, at time: TimeOfDay? = nil) -> (Rule, Activation) {
    let rule = Rule(title: title, recurrence: .daily, timeOfDay: time)
    return (rule, Activation(ruleID: rule.id, from: d(2026, 8, 1)))
}

@Suite("Scoring")
struct ScoringTests {

    @Test("a day still ahead is not counted as missed")
    func futureIsNotMissed() {
        let (rule, activation) = dailyRule("Evening prayers", at: TimeOfDay(hour: 21, minute: 30))
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: [],
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
        let score = report.perRule[0]
        // 1–19 August elapsed; the 20th at 21:30 has not, nor has anything after.
        #expect(score.missed == 19)
        #expect(score.scoreable == 19)
    }

    @Test("an untimed rule counts only once its day is out")
    func untimedElapsesAtEndOfDay() {
        let (rule, activation) = dailyRule("Jesus prayer")
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: [],
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
        #expect(report.perRule[0].missed == 19, "today is still open")
    }

    @Test("nothing due yet gives no figure rather than zero")
    func noFigureWhenNothingDue() {
        let rule = Rule(title: "Sunday Liturgy", recurrence: .weekly(days: [.sunday]))
        let activation = Activation(ruleID: rule.id, from: d(2026, 8, 20))
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: [],
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
        #expect(report.overall == nil, "a zero would be a lie, not a score")
        #expect(!report.hasAnythingDue)
    }

    // The binding property from design.md: standing something down leaves the
    // score untouched rather than counting against anyone.
    @Test("standing a day down moves the score not at all")
    func stoodDownIsNeutral() {
        let (rule, activation) = dailyRule("Evening prayers")
        let allKept = (1...19).map {
            Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completed)
        }
        var withStandDown = allKept
        withStandDown[9] = Occurrence(ruleID: rule.id, date: d(2026, 8, 10), status: .skipped)

        let full = engine().report(
            rules: [rule], activations: [activation], occurrences: allKept,
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
        let paused = engine().report(
            rules: [rule], activations: [activation], occurrences: withStandDown,
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
        #expect(full.overall == 1.0)
        #expect(paused.overall == 1.0, "the day left the record entirely")
        #expect(paused.perRule[0].stoodDown == 1)
        #expect(paused.perRule[0].scoreable == 18)
    }

    @Test("keeping something late earns partial credit, not nothing")
    func lateEarnsPartialCredit() {
        let (rule, activation) = dailyRule("Evening prayers")
        let late = (1...19).map {
            Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completedLate)
        }
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: late,
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
        let ratio = try! #require(report.overall)
        #expect(ratio > 0.4 && ratio < 0.6, "half credit, not zero")
        #expect(report.perRule[0].keptLate == 19)
    }

    @Test("a rule taken on today reports no prior misses")
    func noRetroactiveMisses() {
        let rule = Rule(title: "Morning prayers", recurrence: .daily)
        let activation = Activation(ruleID: rule.id, from: d(2026, 8, 19))
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: [],
            from: d(2026, 1, 1), through: d(2026, 8, 31), now: now
        )
        #expect(report.perRule[0].missed == 1, "only the 19th, which has elapsed")
    }

    @Test("recent days weigh more than old ones")
    func recencyWeighting() {
        let (rule, activation) = dailyRule("Evening prayers")
        // Kept everything except one day, either long ago or yesterday.
        func report(missing day: CalendarDate) -> Double {
            let kept = (1...19).map { d(2026, 8, $0) }
                .filter { $0 != day }
                .map { Occurrence(ruleID: rule.id, date: $0, status: .completed) }
            let older = (1...31).map { d(2026, 5, $0) }
                .filter { $0 != day }
                .map { Occurrence(ruleID: rule.id, date: $0, status: .completed) }
            return engine().report(
                rules: [rule], activations: [Activation(ruleID: rule.id, from: d(2026, 5, 1))],
                occurrences: kept + older,
                from: d(2026, 5, 1), through: d(2026, 8, 31), now: now
            ).overall ?? 0
        }
        // Note both are the same count of misses; only the age differs.
        #expect(report(missing: d(2026, 8, 19)) < report(missing: d(2026, 5, 2)),
                "a recent slip should weigh more than one months ago")
        #expect(report(missing: d(2026, 5, 2)) < 1.0, "but an old one never vanishes")
    }

    @Test("a streak steps over stood-down days rather than breaking")
    func streakStepsOverPauses() {
        let (rule, activation) = dailyRule("Morning prayers")
        var occurrences = (1...19).map {
            Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completed)
        }
        occurrences[16] = Occurrence(ruleID: rule.id, date: d(2026, 8, 17), status: .skipped)
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: occurrences,
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
        #expect(report.perRule[0].streak == 18, "pausing is not a break")
    }
}

@Suite("The written summary")
struct ProseTests {

    private func report(_ occurrences: [Occurrence], rules: [Rule], activations: [Activation]) -> ProgressReport {
        engine().report(
            rules: rules, activations: activations, occurrences: occurrences,
            from: d(2026, 8, 1), through: d(2026, 8, 31), now: now
        )
    }

    @Test("nothing due yet says so plainly")
    func nothingDueYet() {
        let rule = Rule(title: "Sunday Liturgy", recurrence: .weekly(days: [.sunday]))
        let summary = report([], rules: [rule],
                             activations: [Activation(ruleID: rule.id, from: d(2026, 8, 25))]).summary
        #expect(summary.joined().contains("fills in"))
    }

    @Test("everything kept is said without gushing")
    func everythingKept() {
        let (rule, activation) = dailyRule("Morning prayers")
        let kept = (1...19).map { Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completed) }
        let summary = report(kept, rules: [rule], activations: [activation]).summary
        #expect(summary.first?.contains("kept") == true)
        #expect(!summary.joined().contains("!"))
    }

    // The example from the design: the pattern is the useful part.
    @Test("a pattern in the slips is named")
    func weekdayPatternIsNamed() {
        let (rule, activation) = dailyRule("Evening prayers")
        // Miss both Fridays in the elapsed window: 7 and 14 August.
        let kept = (1...19).filter { $0 != 7 && $0 != 14 }
            .map { Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completed) }
        let summary = report(kept, rules: [rule], activations: [activation]).summary.joined(separator: " ")
        #expect(summary.contains("twice"))
        #expect(summary.contains("Fridays"), "the pattern is what someone can act on")
    }

    @Test("a pattern is not invented from a single slip")
    func noPatternFromOneSlip() {
        let (rule, activation) = dailyRule("Evening prayers")
        let kept = (1...19).filter { $0 != 7 }
            .map { Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completed) }
        let summary = report(kept, rules: [rule], activations: [activation]).summary.joined(separator: " ")
        #expect(summary.contains("once"))
        #expect(!summary.contains("Fridays"))
    }

    @Test("what held is mentioned alongside what slipped")
    func whatHeldIsMentioned() {
        let (slipping, a1) = dailyRule("Evening prayers")
        let (holding, a2) = dailyRule("Morning prayers")
        var occurrences = (1...19).map { Occurrence(ruleID: holding.id, date: d(2026, 8, $0), status: .completed) }
        occurrences += (1...19).filter { $0 != 5 }
            .map { Occurrence(ruleID: slipping.id, date: d(2026, 8, $0), status: .completed) }
        let summary = report(occurrences, rules: [slipping, holding], activations: [a1, a2]).summary.joined(separator: " ")
        #expect(summary.contains("Evening prayers"))
        #expect(summary.lowercased().contains("held"))
    }

    @Test("standing down is reported neutrally")
    func standingDownIsNeutral() {
        let (rule, activation) = dailyRule("Jesus prayer")
        var occurrences = (1...19).map { Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completed) }
        occurrences[3] = Occurrence(ruleID: rule.id, date: d(2026, 8, 4), status: .skipped)
        let summary = report(occurrences, rules: [rule], activations: [activation]).summary.joined(separator: " ")
        #expect(summary.contains("stood down"))
        #expect(summary.contains("not counted"))
    }

    // The Tone constraint, applied to every shape of report this can produce.
    @Test("no summary ever shames, compares, or declares failure")
    func toneIsClean() {
        let (a, actA) = dailyRule("Evening prayers")
        let (b, actB) = dailyRule("Morning prayers", at: TimeOfDay(hour: 6, minute: 30))
        let (c, actC) = dailyRule("Jesus prayer")

        let shapes: [[Occurrence]] = [
            [],
            (1...19).map { Occurrence(ruleID: a.id, date: d(2026, 8, $0), status: .completed) },
            (1...19).map { Occurrence(ruleID: a.id, date: d(2026, 8, $0), status: .completedLate) },
            (1...19).map { Occurrence(ruleID: a.id, date: d(2026, 8, $0), status: .skipped) },
            (1...10).map { Occurrence(ruleID: b.id, date: d(2026, 8, $0), status: .completed) },
            (1...19).filter { $0 % 3 == 0 }.map { Occurrence(ruleID: c.id, date: d(2026, 8, $0), status: .completed) }
        ]

        let forbidden = [
            "fail", "failed", "failure", "missed", "behind", "should have",
            "only", "just", "poor", "bad", "worse", "better than", "down from",
            "target", "goal", "streak broken", "broke", "lost", "!"
        ]

        for shape in shapes {
            let summary = report(shape, rules: [a, b, c], activations: [actA, actB, actC])
                .summary.joined(separator: " ").lowercased()
            #expect(!summary.isEmpty)
            for word in forbidden {
                #expect(!summary.contains(word), "\"\(word)\" appeared in: \(summary)")
            }
        }
    }
}

/// The bug this covers: an all-day rule kept this morning did not appear in
/// the report at all, because the day had not finished. Elapsing decides
/// whether an absent record is a miss; it says nothing about a day that was
/// actually kept.
@Suite("Today counts")
struct TodayCountsTests {

    @Test("an all-day rule kept today shows up today")
    func allDayKeptTodayCounts() {
        let (rule, activation) = dailyRule("The Wednesday and Friday fast")
        let today = CalendarDate(now, in: zone)
        let kept = [Occurrence(ruleID: rule.id, date: today, status: .completed)]

        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: kept,
            from: today, through: today, now: now
        )
        let score = report.perRule[0]
        #expect(score.hasAnythingDue, "it must be in the report the moment it is kept")
        #expect(score.kept == 1)
        #expect(report.overall == 1.0)
    }

    @Test("an all-day rule not yet acted on today is not a miss")
    func allDayPendingIsNotMissed() {
        let (rule, activation) = dailyRule("Jesus prayer")
        let today = CalendarDate(now, in: zone)

        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: [],
            from: today, through: today, now: now
        )
        #expect(report.perRule[0].missed == 0, "the day is not over")
        #expect(report.overall == nil, "and there is nothing to score yet")
    }

    @Test("a timed rule kept before its hour counts straight away")
    func timedKeptEarlyCounts() {
        let (rule, activation) = dailyRule("Evening prayers", at: TimeOfDay(hour: 21, minute: 30))
        let today = CalendarDate(now, in: zone)
        // now is 10:00; the rule is due at 21:30 and has been kept already.
        let kept = [Occurrence(ruleID: rule.id, date: today, status: .completed)]

        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: kept,
            from: today, through: today, now: now
        )
        #expect(report.perRule[0].kept == 1, "done early is still done")
    }

    @Test("standing today down still removes it from the ratio")
    func stoodDownTodayIsNeutral() {
        let (rule, activation) = dailyRule("Jesus prayer")
        let today = CalendarDate(now, in: zone)
        let stood = [Occurrence(ruleID: rule.id, date: today, status: .skipped)]

        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: stood,
            from: today, through: today, now: now
        )
        #expect(report.perRule[0].stoodDown == 1)
        #expect(report.perRule[0].scoreable == 0)
    }

    // A day that has not happened cannot end a streak — otherwise every streak
    // would read as zero from midnight until the rule's hour.
    @Test("today being still ahead does not end a streak")
    func pendingTodayDoesNotBreakStreak() {
        let (rule, activation) = dailyRule("Evening prayers", at: TimeOfDay(hour: 21, minute: 30))
        let today = CalendarDate(now, in: zone)
        let kept = (1...19).map {
            Occurrence(ruleID: rule.id, date: d(2026, 8, $0), status: .completed)
        }
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: kept,
            from: d(2026, 8, 1), through: today, now: now
        )
        #expect(report.perRule[0].streak == 19, "the 20th has not come round yet")
    }

    @Test("an all-day rule missed yesterday is still a miss")
    func yesterdayStillCounts() {
        let (rule, activation) = dailyRule("Jesus prayer")
        let report = engine().report(
            rules: [rule], activations: [activation], occurrences: [],
            from: d(2026, 8, 18), through: CalendarDate(now, in: zone), now: now
        )
        #expect(report.perRule[0].missed == 2, "the 18th and 19th are over; the 20th is not")
    }
}
