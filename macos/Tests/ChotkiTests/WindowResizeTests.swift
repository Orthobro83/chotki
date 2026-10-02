import AppKit
import SwiftUI
import Testing
@testable import Chotki
@testable import ChotkiCore

@Suite("Window resizing")
@MainActor
struct WindowResizeTests {
    private struct QuietNotifier: Notifier {
        let supportsActions = false
        func requestAuthorization() async throws -> Bool { false }
        func show(_ request: NotificationRequest) async throws {}
        func cancel(ids: [String]) async {}
        var actionEvents: AsyncStream<NotificationActionEvent> { AsyncStream { $0.finish() } }
    }
    private struct QuietLogin: LaunchAtLogin {
        let isEnabled = false
        func setEnabled(_ enabled: Bool) throws {}
    }

    private func model() -> AppModel {
        let model = AppModel(
            store: InMemoryStore(), notifier: QuietNotifier(), launchAtLogin: QuietLogin(),
            storage: .none(), startsReminders: false, writesBackups: false, loadsCalendar: false
        )
        model.update { $0.hasCompletedFirstRun = true; $0.displayName = "Ryan" }
        return model
    }

    @Test("the window will not shrink below the sidebar")
    func floor() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 860),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        let controller = MainWindowController()
        window.delegate = controller
        window.contentMinSize = MainWindowController.minimumContentSize
        let proposed = controller.windowWillResize(window, to: NSSize(width: 200, height: 180))
        let minimum = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: MainWindowController.minimumContentSize)
        ).size
        #expect(proposed.width >= minimum.width - 0.5)
        #expect(proposed.height >= minimum.height - 0.5)
        let generous = controller.windowWillResize(window, to: NSSize(width: 1400, height: 900))
        #expect(abs(generous.width - 1400) < 0.5)
        #expect(abs(generous.height - 900) < 0.5)
    }

    @Test("resizing keeps the sidebar inside the window, expanded and collapsed")
    func sidebarStaysPut() {
        let app = model()
        draw(MainWindowView(model: app), size: NSSize(width: 900, height: 700), labelColumn: 36..<170)
        draw(MainWindowView(model: app), size: MainWindowController.minimumContentSize, labelColumn: 36..<170)
        draw(
            MainWindowView(model: app, initiallyCollapsed: true),
            size: MainWindowController.minimumContentSize,
            labelColumn: 14..<50
        )
    }

    private func draw<V: View>(_ root: V, size: NSSize, labelColumn: Range<Int>) {
        let host = WindowHostingView(rootView: root.frame(maxWidth: .infinity, maxHeight: .infinity))
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentMinSize = MainWindowController.minimumContentSize
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -30_000, y: -30_000))
        window.setContentSize(NSSize(width: 1200, height: 860))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        // What the screenshots were: a window dragged down from the size it
        // opened at. The content used to keep the old width and slide the
        // sidebar off the leading edge.
        window.setContentSize(size)
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        host.layoutSubtreeIfNeeded()

        #expect(host.frame.minX >= -0.5, "the sidebar's column starts past the left edge")
        #expect(host.frame.width <= window.frame.width + 1)
        #expect(host.bounds.width <= size.width + 2)

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            Issue.record("the window did not draw")
            return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        let height = rep.pixelsHigh
        let edge = brightest(rep, x: 0..<12, y: 60..<max(61, height - 40))
        let labels = brightest(rep, x: labelColumn, y: 60..<max(61, height - 40))
        #expect(edge < 90, "sidebar text is cut off at the left edge (brightness \(edge))")
        #expect(labels > 110, "the sidebar did not draw inside the window (brightness \(labels))")
    }

    private func brightest(_ rep: NSBitmapImageRep, x xs: Range<Int>, y ys: Range<Int>) -> Int {
        var maxL = 0
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        for y in ys where y >= 0 && y < height {
            for x in xs where x >= 0 && x < width {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let lum = Int((color.redComponent + color.greenComponent + color.blueComponent) / 3 * 255)
                if lum > maxL { maxL = lum }
            }
        }
        return maxL
    }
}
