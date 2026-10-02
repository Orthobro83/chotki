import SwiftUI
import UIKit

/// Completion requires a deliberate scroll and the end marker entering the viewport.
/// Opening a section, or the list moving on its own, does not count as reading it.
struct ReadingEnd: UIViewRepresentable {
    let identity: String
    let completed: () -> Void

    func makeUIView(context: Context) -> Marker { Marker() }
    static func dismantleUIView(_ view: Marker, coordinator: ()) { view.detach() }
    func updateUIView(_ view: Marker, context: Context) {
        if view.identity != identity {
            view.identity = identity
            view.hasScrolled = false
            view.hasCompleted = false
        }
        view.completed = completed
    }

    final class Marker: UIView {
        var identity = ""
        var completed: (() -> Void)?
        var hasScrolled = false
        var hasCompleted = false
        private weak var scroll: UIScrollView?
        private var observation: NSKeyValueObservation?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) { return nil }

        override var intrinsicContentSize: CGSize { CGSize(width: 1, height: 1) }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }

        func detach() {
            observation?.invalidate()
            observation = nil
            scroll = nil
        }

        private func attach() {
            guard scroll == nil, let found = enclosingScrollView() else { return }
            scroll = found
            observation = found.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.onOffset() }
            }
        }

        private func enclosingScrollView() -> UIScrollView? {
            var view: UIView? = superview
            while let current = view {
                if let scroll = current as? UIScrollView { return scroll }
                view = current.superview
            }
            return nil
        }

        private func onOffset() {
            guard let scroll else { return }
            if scroll.isTracking || scroll.isDragging || scroll.isDecelerating {
                hasScrolled = true
            }
            guard hasScrolled, !hasCompleted else { return }
            let rectangle = convert(bounds, to: scroll)
            if scroll.bounds.intersects(rectangle) {
                hasCompleted = true
                completed?()
            }
        }
    }
}
