import Testing
import UIKit
@testable import Chotki

@Suite("Reading completion")
@MainActor
struct ReadingEndTests {
    private final class Scroll: UIScrollView {
        var userIsDragging = false
        override var isDragging: Bool { userIsDragging }
    }

    @Test("only a deliberate scroll to the end completes, once")
    func deliberateScroll() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let scroll = Scroll(frame: window.bounds)
        scroll.contentSize = CGSize(width: 320, height: 1400)
        let marker = ReadingEnd.Marker(frame: CGRect(x: 0, y: 1200, width: 1, height: 1))
        var completions = 0
        marker.completed = { completions += 1 }
        scroll.addSubview(marker)
        window.addSubview(scroll)
        // The marker attaches to its enclosing UIKit scroll view on the next turn.
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(20))

        scroll.contentOffset = CGPoint(x: 0, y: 800)
        #expect(completions == 0, "programmatic scrolling counted as reading")
        scroll.contentOffset = .zero
        scroll.userIsDragging = true
        scroll.contentOffset = CGPoint(x: 0, y: 100)
        #expect(completions == 0, "scrolling before the end counted as reading")
        scroll.contentOffset = CGPoint(x: 0, y: 800)
        #expect(completions == 1)
        scroll.contentOffset = CGPoint(x: 0, y: 850)
        #expect(completions == 1, "the same reading completed twice")

        marker.detach()
        scroll.contentOffset = CGPoint(x: 0, y: 900)
        #expect(completions == 1)
    }
}
