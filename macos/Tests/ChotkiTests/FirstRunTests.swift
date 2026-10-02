import Testing
@testable import Chotki

@Suite("The opening")
struct FirstRunTests {
    @Test("the mark keeps Android's clock")
    func clock() {
        #expect(abs(OpeningTiming.total - 3.7) < 0.001)
        let start = OpeningTiming.frame(at: 0)
        #expect(abs(start.scale - 0.85) < 0.001)
        #expect(start.opacity == 1)
        #expect(OpeningTiming.knotAlpha(ms: 0, index: 1) == 0)
        #expect(OpeningTiming.knotAlpha(ms: 160, index: 1) == 1)
        // The last knot starts as the cross is about to appear.
        #expect(OpeningTiming.knotAlpha(ms: 1454, index: 11) < 0.01)
        #expect(OpeningTiming.crossAlpha(ms: 1640) == 0)
        #expect(OpeningTiming.crossAlpha(ms: 1800) == 1)
        let held = OpeningTiming.frame(at: 1.8)
        #expect(abs(held.scale - 1) < 0.001)
        #expect(held.opacity == 1)
        let leaving = OpeningTiming.frame(at: 3.5)
        #expect(leaving.opacity < 1)
        #expect(leaving.opacity > 0)
        #expect(OpeningTiming.frame(at: 3.7).opacity == 0)
    }
}
