import Foundation

/// What became of one rule over a window.
public struct RuleScore: Sendable, Hashable, Identifiable {
    public let ruleID: UUID
    public let title: String
    public let kept: Int
    public let keptLate: Int
    public let missed: Int
    /// Deliberately excluded from the ratio, on both sides.
    public let stoodDown: Int
    /// Consecutive due days most recently kept. Days stood down are stepped
    /// over rather than breaking it.
    public let streak: Int
    /// Weighted toward the recent, in 0...1. Nil when nothing has come due yet.
    public let ratio: Double?
    /// Kept so the summary can notice a pattern — the same weekday recurring,
    /// say — which is more useful to a person than the count alone.
    public let missedDates: [CalendarDate]

    public var id: UUID { ruleID }
    public var scoreable: Int { kept + keptLate + missed }
    public var hasAnythingDue: Bool { scoreable > 0 }
}

public struct ProgressReport: Sendable {
    public let from: CalendarDate
    public let through: CalendarDate
    /// Nil when nothing has come due yet — no figure is better than a zero.
    public let overall: Double?
    public let perRule: [RuleScore]
    /// Leads the report. The figure is secondary and can be hidden entirely.
    public let summary: [String]

    public var hasAnythingDue: Bool { perRule.contains { $0.hasAnythingDue } }
}

/// Works out what was kept, and says so in words.
///
/// Three rules govern everything here, and they are enforced by tests:
/// only elapsed days inside an activation are counted; standing something down
/// removes it from both sides of the ratio rather than counting against anyone;
/// and nothing is ever phrased as a failure or compared against a better past.
public struct ScoringEngine: Sendable {

    private let engine: RecurrenceEngine
    private let timeZone: TimeZone

    /// Days inside this window carry full weight.
    private let fullWeightDays: Int
    /// Beyond the window, weight halves every this many days. Never reaches zero:
    /// what someone kept months ago still happened.
    private let halfLifeDays: Double

    public init(
        engine: RecurrenceEngine = RecurrenceEngine(),
        timeZone: TimeZone = .current,
        fullWeightDays: Int = 30,
        halfLifeDays: Double = 60
    ) {
        self.engine = engine
        self.timeZone = timeZone
        self.fullWeightDays = fullWeightDays
        self.halfLifeDays = halfLifeDays
    }

    /// Completing after the day is out earns partial credit rather than nothing.
    /// It was still done.
    private static let lateCredit = 0.5

    public func report(
        rules: [Rule],
        activations: [Activation],
        occurrences: [Occurrence],
        from: CalendarDate,
        through: CalendarDate,
        now: Date = Date()
    ) -> ProgressReport {
        let today = CalendarDate(now, in: timeZone)
        var scores: [RuleScore] = []

        for rule in rules {
            let due = engine.dueDates(
                rule: rule, activations: activations, from: from, through: through
            )

            guard !due.isEmpty else {
                scores.append(RuleScore(
                    ruleID: rule.id, title: rule.title, kept: 0, keptLate: 0,
                    missed: 0, stoodDown: 0, streak: 0, ratio: nil, missedDates: []
                ))
                continue
            }

            let byDate = Dictionary(
                occurrences.filter { $0.ruleID == rule.id }.map { ($0.date, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            var kept = 0, keptLate = 0, missed = 0, stoodDown = 0
            var missedDates: [CalendarDate] = []
            var weighted = 0.0, weight = 0.0

            for date in due {
                let status = byDate[date]?.status

                // Elapsing decides whether an *absent* record is a miss. It has
                // nothing to do with a day that was actually kept: marking an
                // all-day rule complete this morning is a fact, not a pending
                // judgement, and it must count today rather than tomorrow.
                if status == nil, !hasElapsed(date, rule: rule, now: now, today: today) {
                    continue
                }

                switch status {
                case .skipped, .cancelled, .moved:
                    stoodDown += 1
                    continue          // out of both numerator and denominator
                case .completed:
                    kept += 1
                    let w = weightFor(date, today: today)
                    weighted += w; weight += w
                case .completedLate:
                    keptLate += 1
                    let w = weightFor(date, today: today)
                    weighted += w * ScoringEngine.lateCredit; weight += w
                case .none:
                    missed += 1
                    missedDates.append(date)
                    weight += weightFor(date, today: today)
                }
            }

            scores.append(RuleScore(
                ruleID: rule.id, title: rule.title,
                kept: kept, keptLate: keptLate, missed: missed, stoodDown: stoodDown,
                streak: streak(due: due, byDate: byDate, rule: rule, now: now, today: today),
                ratio: weight > 0 ? weighted / weight : nil,
                missedDates: missedDates
            ))
        }

        let scoreable = scores.filter(\.hasAnythingDue)
        let overall: Double? = scoreable.isEmpty
            ? nil
            : scoreable.compactMap(\.ratio).reduce(0, +) / Double(scoreable.count)

        return ProgressReport(
            from: from, through: through, overall: overall,
            perRule: scores.sorted { $0.title < $1.title },
            summary: Prose.summary(for: scores)
        )
    }

    /// A day counts only once its moment has passed. Anything still ahead is not
    /// missed — it simply has not happened.
    private func hasElapsed(
        _ date: CalendarDate, rule: Rule, now: Date, today: CalendarDate
    ) -> Bool {
        if let time = rule.timeOfDay {
            guard let due = date.dueInstant(at: time, in: timeZone) else { return date < today }
            return due <= now
        }
        // Without a time, the whole day is the window.
        return date < today
    }

    private func weightFor(_ date: CalendarDate, today: CalendarDate) -> Double {
        let age = max(0, date.days(until: today))
        guard age > fullWeightDays else { return 1.0 }
        let beyond = Double(age - fullWeightDays)
        return pow(0.5, beyond / halfLifeDays)
    }

    /// Consecutive due days kept, counting back from the most recent.
    ///
    /// Days stood down are stepped over rather than ending it: pausing is a
    /// legitimate act and must not read as a break.
    private func streak(
        due: [CalendarDate], byDate: [CalendarDate: Occurrence],
        rule: Rule, now: Date, today: CalendarDate
    ) -> Int {
        var count = 0
        for date in due.sorted(by: >) {
            // A day still ahead cannot end a streak.
            if byDate[date] == nil, !hasElapsed(date, rule: rule, now: now, today: today) {
                continue
            }
            switch byDate[date]?.status {
            case .completed, .completedLate:
                count += 1
            case .skipped, .cancelled, .moved:
                continue
            case .none:
                return count
            }
        }
        return count
    }
}
