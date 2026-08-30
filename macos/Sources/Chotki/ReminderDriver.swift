import Foundation
import ChotkiCore

/// Drives the reminder tick and obeys its decisions.
///
/// Everything that decides *what* happens lives in `ReminderTicker` in core:
/// not repeating a reminder, not firing a burst of stale ones, crossing
/// midnight, taking back one that is no longer due. This holds only the timer
/// and the notifier — the two things that are genuinely platform-specific.
///
/// The app is tray-resident and always running, so scheduling happens in
/// process rather than being handed to the operating system. That is what lets
/// the same decisions serve any platform.
@MainActor
final class ReminderDriver {

    private let notifier: any Notifier
    private let plan: () -> [PlannedNotification]
    private let clock: any Clock
    private var ticker = ReminderTicker()
    private var timer: Timer?

    /// Raised on every tick, before the reminders are dealt with.
    ///
    /// The app is resident and this is the only thing already waking the
    /// processor on a schedule, so anything else that has to notice the passing
    /// of time rides along with it rather than starting a second timer. The
    /// driver still knows nothing about what that is — it raises the tick and
    /// the model decides what a tick means.
    var onTick: (() -> Void)?

    init(
        notifier: any Notifier,
        clock: any Clock = SystemClock(),
        plan: @escaping () -> [PlannedNotification]
    ) {
        self.notifier = notifier
        self.clock = clock
        self.plan = plan
    }

    func start() {
        timer?.invalidate()
        // Half a minute is enough: reminders are minute-grained, and a resident
        // menu bar app should not wake the processor more often than it must.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called when rules change, so a rule just kept stops reminding at once.
    func refresh() { tick() }

    func snooze(ruleID: UUID, date: CalendarDate, by interval: TimeInterval) {
        ticker.snooze(
            ruleID: ruleID, date: date, until: clock.now.addingTimeInterval(interval)
        )
    }

    func tick() {
        // Before the reminders: whatever else the passing of time means is the
        // model's business, and it may change what `plan()` is about to return.
        onTick?()

        let decision = ticker.tick(planned: plan(), now: clock.now)
        guard !decision.isEmpty else { return }

        if !decision.withdraw.isEmpty {
            let ids = decision.withdraw
            Task { await notifier.cancel(ids: ids) }
        }
        for notification in decision.show {
            let request = notification.request
            Task { try? await notifier.show(request) }
        }
    }
}
