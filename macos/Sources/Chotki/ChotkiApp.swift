import SwiftUI
import ChotkiCore

@main
struct ChotkiApp: App {
    @StateObject private var spike = SpikeModel()

    var body: some Scene {
        MenuBarExtra {
            SpikeView(model: spike)
        } label: {
            Image(nsImage: CrossIcon.menuBarImage())
        }
        .menuBarExtraStyle(.window)
    }
}

/// Phase 1 only. Exists to retire the two risks the plan is built on, and is
/// replaced wholesale by the real interface in Phase 5.
@MainActor
final class SpikeModel: ObservableObject {
    @Published var authorized: Bool?
    @Published var log: [String] = []

    private let notifier = MacNotifier()
    private let launchAtLogin = MacLaunchAtLogin()

    /// Phase 1 writes here as well as to the popover, so the spike can be
    /// verified without driving the UI.
    static let logURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Logs/chotki-spike.log")

    init() {
        Task { [weak self] in
            guard let self else { return }
            for await event in self.notifier.actionEvents {
                self.note("ACTION \"\(event.actionID)\" on \(event.requestID)")
            }
        }
        note("launched, bundle=\(Bundle.main.bundleIdentifier ?? "none")")
        // Ask on launch so the permission prompt appears without a click, then
        // send one notification so delivery is proven end to end.
        Task {
            let granted = (try? await notifier.requestAuthorization()) ?? false
            authorized = granted
            note(granted ? "authorization granted" : "authorization declined")
            guard granted else { return }
            try? await Task.sleep(for: .seconds(2))
            fireTestNotification()
        }
    }

    var launchAtLoginEnabled: Bool { launchAtLogin.isEnabled }

    func note(_ line: String) {
        let stamp = Date().formatted(date: .omitted, time: .standard)
        let entry = "\(stamp)  \(line)"
        log.insert(entry, at: 0)
        FileHandle.standardError.write(Data((entry + "\n").utf8))
        if let data = (entry + "\n").data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: Self.logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: Self.logURL)
            }
        }
    }

    func authorize() {
        Task {
            do {
                let granted = try await notifier.requestAuthorization()
                authorized = granted
                note(granted ? "authorization granted" : "authorization declined")
            } catch {
                authorized = false
                note("authorization failed — \(error.localizedDescription)")
            }
        }
    }

    func fireTestNotification() {
        Task {
            let request = NotificationRequest(
                id: "spike:\(UUID().uuidString.prefix(8))",
                title: "Evening prayers",
                body: "Due at 21:30",
                actions: [.markComplete, .snooze]
            )
            do {
                try await notifier.show(request)
                note("sent \(request.id)")
            } catch {
                note("send failed — \(error.localizedDescription)")
            }
        }
    }

    func toggleLaunchAtLogin() {
        do {
            try launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
            note("launch at login → \(launchAtLogin.isEnabled ? "on" : "off")")
        } catch {
            note("launch at login failed — \(error.localizedDescription)")
        }
    }
}

struct SpikeView: View {
    @ObservedObject var model: SpikeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phase 1 spike")
                .font(.system(size: 13, weight: .semibold))
            Text("Proving notifications and actions work from an ad-hoc-signed bundle.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 8) {
                Button("Request permission") { model.authorize() }
                Button("Send notification") { model.fireTestNotification() }
            }
            Button(model.launchAtLoginEnabled ? "Disable launch at login" : "Enable launch at login") {
                model.toggleLaunchAtLogin()
            }

            if let authorized = model.authorized {
                Text(authorized ? "Notifications authorized" : "Notifications not authorized")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Divider()

            if model.log.isEmpty {
                Text("No events yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(model.log, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 110)
            }

            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 300)
    }
}
