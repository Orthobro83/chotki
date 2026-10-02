import SwiftUI
import ChotkiCore

struct AttentionPulse: ViewModifier {
    let until: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var active = false

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) { context in
            let remaining = max(0, (until ?? .distantPast).timeIntervalSince(context.date))
            let alpha = active && remaining > 0 ? (reduceMotion ? 0.25 : 0.12 + 0.22 * (1 + sin((DueAttention.duration - remaining) * .pi * 2)) / 2) : 0
            content.background {
                RoundedRectangle(cornerRadius: 8).fill(Theme.parchment.opacity(alpha))
            }
        }
        .task(id: until) {
            let seconds = max(0, (until ?? .distantPast).timeIntervalSinceNow)
            active = seconds > 0
            guard active else { return }
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            active = false
        }
    }
}

extension View {
    func duePulse(until: Date?) -> some View { modifier(AttentionPulse(until: until)) }
}
