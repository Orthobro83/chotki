import Foundation

/// Expands rules into the days they fall on.
///
/// Pure, deterministic, and entirely free of storage and platform. Everything
/// the scoring and scheduling layers rely on is decided here, which is why this
/// is the most heavily tested type in the project.
public struct RecurrenceEngine: Sendable {

    private let liturgical: any LiturgicalDayProvider
    private let observances: ObservanceSettings

    public init(
        liturgical: any LiturgicalDayProvider = NoLiturgicalData(),
        observances: ObservanceSettings = .default
    ) {
        self.liturgical = liturgical
        self.observances = observances
    }

    /// Days the recurrence pattern alone would produce, ignoring activations.
    public func patternDates(
        for recurrence: Recurrence,
        from start: CalendarDate,
        through end: CalendarDate
    ) -> [CalendarDate] {
        guard start <= end else { return [] }
        var result: [CalendarDate] = []
        var day = start
        while day <= end {
            if matches(recurrence, day) { result.append(day) }
            day = day.adding(days: 1)
        }
        return result
    }

    /// The days a rule is actually due: the pattern, intersected with the
    /// stretches during which the rule was in force.
    ///
    /// This intersection is the whole mechanism. A rule enabled in March
    /// produces nothing in February; a rule paused in May produces nothing that
    /// month; neither leaves a gap that scoring could read as a failure.
    public func dueDates(
        rule: Rule,
        activations: [Activation],
        from start: CalendarDate,
        through end: CalendarDate
    ) -> [CalendarDate] {
        inForce(rule: rule, activations: activations, from: start, through: end)
            .filter { dispensation(rule: rule, on: $0) == nil }
    }

    /// Days the rule would fall on, but which the Church has lifted — with the
    /// reason. These are deliberately **not** due: they cannot be missed and
    /// they raise no reminder. They are returned separately so the day can
    /// still be shown, kept, with an explanation, rather than silently
    /// vanishing from the list as though the rule had broken.
    public func dispensations(
        rule: Rule,
        activations: [Activation],
        from start: CalendarDate,
        through end: CalendarDate
    ) -> [(date: CalendarDate, reason: String)] {
        inForce(rule: rule, activations: activations, from: start, through: end)
            .compactMap { date in
                dispensation(rule: rule, on: date).map { (date, $0) }
            }
    }

    private func inForce(
        rule: Rule, activations: [Activation], from start: CalendarDate, through end: CalendarDate
    ) -> [CalendarDate] {
        let mine = activations.filter { $0.ruleID == rule.id }
        guard !mine.isEmpty else { return [] }
        return patternDates(for: rule.recurrence, from: start, through: end)
            .filter { date in mine.contains { $0.covers(date) } }
    }

    private func dispensation(rule: Rule, on date: CalendarDate) -> String? {
        guard rule.isFastingRule else { return nil }
        return liturgical.fastFreeReason(date)
    }

    private func matches(_ recurrence: Recurrence, _ date: CalendarDate) -> Bool {
        switch recurrence {
        case .once(let only):
            return date == only

        case .daily:
            return true

        case .weekly(let days):
            return days.contains(date.weekday)

        case .monthly(let day, let whenShort):
            if day <= date.lastDayOfMonth { return date.day == day }
            // The named day does not exist this month.
            switch whenShort {
            case .lastDay: return date.day == date.lastDayOfMonth
            case .skip: return false
            }

        case .liturgical(let trigger):
            // An observance that is merely shown, or hidden, never produces a
            // due day — so it can never be missed, and can never be scored.
            // Standing one down is therefore identical to pausing: the days
            // leave the record rather than counting against anyone.
            guard observances.setting(for: trigger).drivesRules else { return false }
            switch trigger {
            case .fastDay: return liturgical.isFastDay(date)
            case .greatFeast: return liturgical.isGreatFeast(date)
            case .season(let wanted): return liturgical.season(date) == wanted
            }
        }
    }
}
