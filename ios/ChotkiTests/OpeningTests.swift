import Testing
@testable import Chotki

@Suite("The opening")
struct OpeningTests {
    @Test("the mark keeps the same clock as Mac and Android")
    func clock() {
        #expect(abs(OpeningTiming.total - 3.7) < 0.001)
        let start = OpeningTiming.frame(at: 0)
        #expect(abs(start.scale - 0.85) < 0.001)
        #expect(start.opacity == 1)
        #expect(OpeningTiming.knotAlpha(ms: 0, index: 1) == 0)
        #expect(OpeningTiming.knotAlpha(ms: 160, index: 1) == 1)
        #expect(OpeningTiming.crossAlpha(ms: 1640) == 0)
        #expect(OpeningTiming.crossAlpha(ms: 1800) == 1)
        #expect(OpeningTiming.frame(at: 3.7).opacity == 0)
    }
}
