import Foundation

/// A person's rule, as it stands, and the questions worth asking of it.
///
/// Pure: it holds a snapshot and answers questions about it. No store, no
/// platform, no observation. Every decision here — what is due today, whether a
/// day is settled, whether a rule is paused, which repairs a loaded record
/// needs — is behaviour any version of this app must reproduce, so it lives
/// where it can be tested once and reused rather than rewritten per platform.
public struct Practice: Sendable {

    public let rules: [Rule]
    public let activations: [Activation]
    public let occurrences: [Occurrence]
    public let settings: AppSettings
    private let engine: RecurrenceEngine

    public init(
        rules: [Rule],
        activations: [Activation],
        occurrences: [Occurrence],
        settings: AppSettings,
        liturgical: any LiturgicalDayProvider = NoLiturgicalData()
    ) {
        self.rules = rules
        self.activations = activations
        self.occurrences = occurrences
        self.settings = settings
        self.engine = RecurrenceEngine(
            liturgical: liturgical, observances: settings.observances
        )
    }

    // MARK: what is on a day

    /// The rules that fall on a day, in the order they are shown: timed first,
    /// by hour; then those that run all day.
    ///
    /// A rule the Church has lifted is included rather than omitted — with the
    /// reason — because a rule that simply vanished would look like a fault and
    /// teach nothing.
    public func entries(on date: CalendarDate) -> [DayEntry] {
        let byRule = Dictionary(
            occurrences.filter { $0.date == date }.map { ($0.ruleID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return rules.compactMap { rule -> DayEntry? in
            let due = engine.dueDates(
                rule: rule, activations: activations, from: date, through: date
            )
            if !due.isEmpty {
                return DayEntry(
                    rule: rule, date: date, occurrence: byRule[rule.id], dispensation: nil
                )
            }
            if let lifted = engine.dispensations(
                rule: rule, activations: activations, from: date, through: date
            ).first {
                return DayEntry(
                    rule: rule, date: date, occurrence: nil, dispensation: lifted.reason
                )
            }
            return nil
        }
        .sorted { a, b in
            switch (a.rule.timeOfDay, b.rule.timeOfDay) {
            case let (x?, y?): return x < y
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return a.rule.title < b.rule.title
            }
        }
    }

    /// Every rule for the day accounted for, with at least one actually kept.
    ///
    /// A rule stood down counts as settled: standing down is a legitimate act,
    /// and treating it as unfinished would quietly punish pausing. Standing
    /// everything down settles nothing, because nothing was kept.
    public func isSettled(on date: CalendarDate) -> Bool {
        let items = entries(on: date)
        guard !items.isEmpty else { return false }
        guard items.contains(where: \.isKept) else { return false }
        return items.allSatisfy { $0.showsAsSatisfied || $0.isStoodDown }
    }

    public func isPaused(_ rule: Rule) -> Bool {
        !activations.contains { $0.ruleID == rule.id && $0.isOpen }
    }

    // MARK: repairs

    /// Observances that must be turned on because a rule depends on them.
    ///
    /// A rule tied to the church calendar can never come due while its
    /// observance is merely shown — it sits on the list and is invisible. That
    /// happens to a rule taken on before this was handled, or restored from an
    /// older backup, so it is repaired on load rather than only when taken on.
    public func observancesNeeded() -> [LiturgicalTrigger] {
        var wanted: [LiturgicalTrigger] = []
        for rule in rules where !rule.isArchived {
            guard case .liturgical(let trigger) = rule.recurrence else { continue }
            guard activations.contains(where: { $0.ruleID == rule.id && $0.isOpen }) else { continue }
            guard !settings.observances.setting(for: trigger).drivesRules else { continue }
            wanted.append(trigger)
        }
        return wanted
    }

    /// Someone who already has rules has plainly been here before, whatever the
    /// stored flag says. Showing them the first-run screen would be absurd.
    public var shouldMarkFirstRunComplete: Bool {
        !settings.hasCompletedFirstRun && !rules.isEmpty
    }

    // MARK: progress

    /// The last day progress speaks about: yesterday.
    ///
    /// Today is deliberately outside it. A day still in progress is not a
    /// verdict — a rule added this morning and not yet kept would otherwise
    /// count against someone before they had the chance.
    public static func progressThrough(today: CalendarDate) -> CalendarDate {
        today.adding(days: -1)
    }

    public func report(
        days: Int = 30, today: CalendarDate, timeZone: TimeZone = .current, now: Date = Date()
    ) -> ProgressReport {
        let through = Practice.progressThrough(today: today)
        return ScoringEngine(engine: engine, timeZone: timeZone).report(
            rules: rules, activations: activations, occurrences: occurrences,
            from: through.adding(days: -(days - 1)), through: through, now: now,
            liturgicalHistoryFrom: settings.reckoningChangedOn
        )
    }
}
