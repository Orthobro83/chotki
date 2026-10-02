import SwiftUI
import AppKit

struct ChotkiBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.ground
                RadialGradient(colors: [Theme.parchment.opacity(0.14), .clear], center: .topLeading,
                               startRadius: 0, endRadius: proxy.size.width * 0.7)
                RadialGradient(colors: [Theme.gold.opacity(0.10), .clear], center: .bottomTrailing,
                               startRadius: 0, endRadius: proxy.size.width * 0.6)
            }
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}

struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ground).padding(.horizontal, 22).padding(.vertical, 11)
            .background(Theme.gold.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Keep the native overlay scrollbar behavior even when the host preference is Always.
struct OverlayScrollbars: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Probe() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view) }
    }
    private func configure(_ view: NSView) {
        guard let scroll = view.enclosingScrollView else { return }
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
    }
    private class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            enclosingScrollView?.scrollerStyle = .overlay
            enclosingScrollView?.autohidesScrollers = true
        }
    }
}

extension View {
    func chotkiScrollContent() -> some View { background(OverlayScrollbars().frame(width: 0, height: 0)) }
    func horizontalWheelScroll() -> some View { background(HorizontalWheelScroll().frame(width: 0, height: 0)) }
    func softVerticalScrollEdges() -> some View { modifier(SoftVerticalScrollEdges()) }
}

/// A vertical mouse wheel follows a horizontal strip while the pointer is over
/// it. At either end the event is left alone so the containing page can scroll.
private struct HorizontalWheelScroll: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) {
        DispatchQueue.main.async { view.install() }
    }

    final class Probe: NSView {
        private weak var scroll: NSScrollView?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { removeMonitor() }
            else { DispatchQueue.main.async { [weak self] in self?.install() } }
        }

        func install() {
            guard let window, let scroll = enclosingScrollView else { return }
            self.scroll = scroll
            scroll.hasHorizontalScroller = false
            scroll.autohidesScrollers = true
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak window] event in
                guard let self, let window, event.window === window,
                      let scroll = self.scroll, let document = scroll.documentView,
                      abs(event.scrollingDeltaY) > 0.1,
                      abs(event.scrollingDeltaX) < 0.1 else { return event }
                let point = scroll.convert(event.locationInWindow, from: nil)
                guard scroll.bounds.contains(point) else { return event }
                let visible = scroll.contentView.bounds
                let maximum = max(0, document.bounds.width - visible.width)
                guard maximum > 0 else { return event }
                let step = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 24
                let next = min(max(visible.origin.x - step, 0), maximum)
                guard abs(next - visible.origin.x) > 0.1 else { return event }
                scroll.contentView.scroll(to: NSPoint(x: next, y: visible.origin.y))
                scroll.reflectScrolledClipView(scroll.contentView)
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            scroll = nil
        }

    }
}

/// Text fades into and out of every vertically scrolled viewport.
private struct SoftVerticalScrollEdges: ViewModifier {
    func body(content: Content) -> some View {
        content.mask {
            GeometryReader { proxy in
                let edge = min(0.15, 20 / max(proxy.size.height, 1))
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: edge),
                    .init(color: .white, location: 1 - edge),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

struct NoticeLine: View {
    @ObservedObject var model: AppModel
    var body: some View {
        if let text = model.loadError ?? model.notice {
            HStack(alignment: .top, spacing: 12) {
                Text(text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if model.loadError == nil {
                    Button { model.notice = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss Notice")
                }
            }.foregroundStyle(Theme.parchmentDim).padding(12).background(Theme.panel)
        }
    }
}
