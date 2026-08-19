import Foundation

/// Decides what should be reminded, and when.
///
/// Pure: given rules, activations, occurrences and a day, it returns the
/// reminders for that day. It does not fire anything, does not sleep, and does
/// not know what platform it is on — the `Notifier` only shows what this
/// decides. That is what lets a simulated month run headlessly in CI.
public struct Scheduler: Sendable {

    private let engine: RecurrenceEngine
    private let policy: ReminderPolicy
    private let timeZone: TimeZone

    public init(
        engine: RecurrenceEngine = RecurrenceEngine(),
        policy: ReminderPolicy = .default,
        timeZone: TimeZone = .current
    ) {
        self.engine = engine
        self.policy = policy
        self.timeZone = timeZone
    }

    /// Statuses that end a day's reminders. Completing is the obvious one;
    /// skipping and cancelling must silence it too, or standing something down
    /// would keep buzzing about it.
    private static let settled: Set<OccurrenceStatus> = [
        .completed, .completedLate, .skipped, .cancelled, .moved
    ]

    /// Every reminder for one day, in fire order.
    public func plan(
        rules: [Rule],
        activations: [Activation],
        occurrences: [Occurrence],
        on date: CalendarDate
    ) -> [PlannedNotification] {
        let settledRuleIDs = Set(
            occurrences
                .filter { $0.date == date && Scheduler.settled.contains($0.status) }
                .map(\.ruleID)
        )

        // The master switch silences everything and changes nothing else:
        // rules stay due, and scoring never sees this.
        guard policy.notificationsEnabled else { return [] }

        var planned: [PlannedNotification] = []
        for rule in rules where !rule.isArchived && !settledRuleIDs.contains(rule.id) {
            guard rule.effectiveReminders.enabled else { continue }
            let due = engine.dueDates(
                rule: rule, activations: activations, from: date, through: date
            )
            guard !due.isEmpty else { continue }
            planned += reminders(for: rule, on: date)
        }
        return planned.sorted { $0.fireAt < $1.fireAt }
    }

    /// Reminders still ahead of `now` — what a driver would actually arm.
    public func pending(
        rules: [Rule],
        activations: [Activation],
        occurrences: [Occurrence],
        on date: CalendarDate,
        after now: Date
    ) -> [PlannedNotification] {
        plan(rules: rules, activations: activations, occurrences: occurrences, on: date)
            .filter { $0.fireAt > now }
    }

    /// The ids to cancel when a rule is completed, paused or archived. Callers
    /// need not know how many reminders were armed.
    public func cancellationIDs(
        ruleID: UUID, date: CalendarDate, rules: [Rule], activations: [Activation]
    ) -> [String] {
        guard let rule = rules.first(where: { $0.id == ruleID }) else { return [] }
        return reminders(for: rule, on: date).map(\.id)
    }

    // MARK: building reminders

    private func reminders(for rule: Rule, on date: CalendarDate) -> [PlannedNotification] {
        if let time = rule.timeOfDay {
            return timedReminders(rule: rule, date: date, time: time)
        }
        return untimedReminders(rule: rule, date: date)
    }

    /// One reminder per configured lead. More than one is allowed — an hour
    /// before to get ready, ten minutes before to actually leave.
    private func timedReminders(
        rule: Rule, date: CalendarDate, time: TimeOfDay
    ) -> [PlannedNotification] {
        // A wall-clock time the day does not have — 02:30 on a spring-forward
        // morning — yields no instant, so no reminder rather than a wrong one.
        guard let dueAt = date.dueInstant(at: time, in: timeZone) else { return [] }

        let configured = rule.effectiveReminders.leads
        let leads = configured.isEmpty ? [policy.defaultLead] : configured
        let key = PlannedNotification.occurrenceKey(ruleID: rule.id, date: date)

        return leads.sorted().compactMap { lead -> PlannedNotification? in
            let fireAt: Date
            switch lead {
            case .theEveningBefore:
                // A fixed, predictable hour the evening before, so something you
                // travel to can be prepared for the night before.
                guard let evening = date.adding(days: -1)
                    .dueInstant(at: TimeOfDay(hour: 20, minute: 0)!, in: timeZone)
                else { return nil }
                fireAt = evening
            default:
                fireAt = dueAt.addingTimeInterval(-lead.interval)
            }

            // Quiet hours deliberately do NOT apply to a rule the user gave a
            // time to. They exist to stop unsolicited repetition, not to silence
            // a reminder that was asked for: with the default window ending
            // 06:30, a 06:30 rule warns at 06:20 and must still arrive.
            let id = "\(key):lead\(lead.rawValue)"
            return PlannedNotification(
                id: id, ruleID: rule.id, date: date, fireAt: fireAt,
                request: NotificationRequest(
                    id: id,
                    title: rule.title,
                    // Neutral by construction: what is due and when, never how
                    // long it has been outstanding.
                    body: body(for: lead, at: time),
                    actions: [.markComplete, .snooze]
                )
            )
        }
    }

    private func body(for lead: ReminderLead, at time: TimeOfDay) -> String {
        switch lead {
        case .atTheTime: return "At \(format(time))"
        case .theEveningBefore: return "Tomorrow at \(format(time))"
        default: return "At \(format(time))"
        }
    }

    private func untimedReminders(rule: Rule, date: CalendarDate) -> [PlannedNotification] {
        let cap = policy.untimedCap > 0 ? policy.untimedCap : Int.max

        // Every slot the quiet window leaves open, in order.
        let stepMinutes = max(Int(policy.untimedInterval / 60), 1)
        var waking: [TimeOfDay] = []
        var minute = 0
        while minute < 24 * 60 {
            defer { minute += stepMinutes }
            guard let time = TimeOfDay(hour: minute / 60, minute: minute % 60) else { continue }
            if !policy.quietHours.contains(time) { waking.append(time) }
        }
        guard !waking.isEmpty else { return [] }

        let chosen: [TimeOfDay]
        switch policy.spacing {
        case .hourly:
            chosen = Array(waking.prefix(cap))
        case .spreadAcrossDay:
            let wanted = min(cap, waking.count)
            if wanted <= 1 {
                chosen = Array(waking.prefix(wanted))
            } else {
                // Evenly spaced across the waking window, first and last included.
                let stride = Double(waking.count - 1) / Double(wanted - 1)
                chosen = (0..<wanted).map { waking[Int((Double($0) * stride).rounded())] }
            }
        }

        var result: [PlannedNotification] = []
        for time in chosen {
            guard let fireAt = date.dueInstant(at: time, in: timeZone) else { continue }
            let index = result.count
            let id = "\(PlannedNotification.occurrenceKey(ruleID: rule.id, date: date)):\(index)"
            result.append(
                PlannedNotification(
                    id: id, ruleID: rule.id, date: date, fireAt: fireAt,
                    request: NotificationRequest(
                        id: id,
                        title: rule.title,
                        body: "Today",
                        actions: [.markComplete, .snooze]
                    )
                )
            )
        }
        return result
    }

    private func format(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}
