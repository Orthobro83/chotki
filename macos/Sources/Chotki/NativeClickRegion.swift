import AppKit
import SwiftUI

/// Delivers an ordinary mouse click to a control inside a SwiftUI scroll
/// document, whose document view can otherwise swallow the nested control's
/// mouse events. The existing SwiftUI control remains the accessibility target.
@MainActor
struct NativeClickRegion: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> Surface { Surface() }

    func updateNSView(_ view: Surface, context: Context) { view.action = action }

    final class Surface: NSView {
        var action: (() -> Void)?
        private var monitor: Any?
        private var pressedAt: CGPoint?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
                pressedAt = nil
            } else if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
                    guard let self, event.window === self.window,
                          !self.isHiddenOrHasHiddenAncestor else { return event }
                    let point = self.convert(event.locationInWindow, from: nil)
                    let inside = self.bounds.contains(point) && self.visibleRect.contains(point)
                    switch event.type {
                    case .leftMouseDown:
                        guard inside else { return event }
                        self.pressedAt = point
                        return nil
                    case .leftMouseUp:
                        guard let start = self.pressedAt else { return event }
                        self.pressedAt = nil
                        if inside && hypot(point.x - start.x, point.y - start.y) < 8 { self.action?() }
                        return nil
                    default:
                        return event
                    }
                }
            }
        }
    }
}
