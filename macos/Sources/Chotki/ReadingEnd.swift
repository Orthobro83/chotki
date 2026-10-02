import SwiftUI
import AppKit

/// Completion requires a deliberate scroll and the end marker entering the viewport.
/// Automatic navigation to a reading never counts as reading it.
struct ReadingEnd: NSViewRepresentable {
    let identity: String
    let completed: () -> Void
    func makeNSView(context: Context) -> Marker { Marker() }
    static func dismantleNSView(_ view: Marker, coordinator: ()) { view.detach() }
    func updateNSView(_ view: Marker, context: Context) {
        if view.identity != identity {
            view.identity = identity
            view.hasScrolled = false
            view.hasCompleted = false
        }
        view.completed = completed
    }
    @MainActor final class Marker: NSView {
        var identity = ""
        var completed: (() -> Void)?
        var hasScrolled = false
        var hasCompleted = false
        private var monitor: Any?
        private weak var scroll: NSScrollView?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            detach()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }
        func detach() {
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            NotificationCenter.default.removeObserver(self)
            scroll = nil
        }
        private func attach() {
            guard let scroll = enclosingScrollView else { return }
            self.scroll = scroll
            scroll.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(check), name: NSView.boundsDidChangeNotification, object: scroll.contentView)
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self, let scroll = self.scroll, event.window === self.window else { return }
                    let inside = scroll.bounds.contains(scroll.convert(event.locationInWindow, from: nil))
                    let responder = self.window?.firstResponder as? NSView
                    let focused = responder === scroll || responder?.isDescendant(of: scroll) == true
                    let scrollKey = event.type == .keyDown && focused && [UInt16(116), 121, 125, 126].contains(event.keyCode)
                    if (event.type == .scrollWheel && inside && abs(event.scrollingDeltaY) > 0.1) || scrollKey {
                        self.hasScrolled = true
                        DispatchQueue.main.async { [weak self] in self?.check() }
                    }
                }
                return event
            }
        }
        @objc private func check() {
            guard hasScrolled, !hasCompleted, let scroll, let document = scroll.documentView else { return }
            let rectangle = convert(bounds, to: document)
            if scroll.documentVisibleRect.intersects(rectangle) {
                hasCompleted = true
                completed?()
            }
        }
    }
}
