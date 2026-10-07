import Foundation
import Testing
@testable import ChotkiCore

@Suite("The rope as a circle")
struct RopeCircleTests {
    @Test("Every offered count is drawn with exactly that many knots", arguments: PrayerScreen.targets)
    func oneDotPerKnot(target: Int) {
        for diameter: Double in [190, 240] {
            #expect(RopeCircleLayout.centres(count: target, diameter: diameter).count == target)
        }
    }

    @Test("Ten knots between each bead, and a start-and-end bead: 33 has four beads, 50 five, 100 ten",
          arguments: [(33, 4), (50, 5), (100, 10)])
    func beads(target: Int, expected: Int) {
        let layout = RopeCircleLayout.layout(count: target, diameter: 240)
        #expect(layout.knots.count == target, "beads are added, never swapped for knots")
        #expect(layout.beads.count == expected)
        #expect(layout.bead > layout.dot)
    }

    /// The marks in rope order: the start bead, ten knots, a bead, ten knots ...
    private func inRopeOrder(_ layout: RopeCircleLayout.Layout) -> [(RopeCircleLayout.Point, Double, isBead: Bool)] {
        var ordered: [(RopeCircleLayout.Point, Double, isBead: Bool)] = [(layout.beads[0], layout.bead, true)]
        for (k, knot) in layout.knots.enumerated() {
            ordered.append((knot, layout.dot, false))
            let counted = k + 1
            if counted % 10 == 0, counted / 10 < layout.beads.count { ordered.append((layout.beads[counted / 10], layout.bead, true)) }
        }
        return ordered
    }

    @Test("Marks stay inside the square and never touch", arguments: PrayerScreen.targets)
    func marksFitAndSeparate(target: Int) {
        for diameter: Double in [140, 190, 240, 260] {
            let ordered = inRopeOrder(RopeCircleLayout.layout(count: target, diameter: diameter))
            for (c, size, _) in ordered {
                #expect(c.x - size / 2 >= 0 && c.x + size / 2 <= diameter)
                #expect(c.y - size / 2 >= 0 && c.y + size / 2 <= diameter)
            }
            for (a, b) in zip(ordered, ordered.dropFirst() + [ordered[0]]) {
                let distance = (((a.0.x - b.0.x) * (a.0.x - b.0.x)) + ((a.0.y - b.0.y) * (a.0.y - b.0.y))).squareRoot()
                #expect(distance > (a.1 + b.1) / 2, "neighbouring marks do not touch")
            }
        }
    }

    @Test("Going round the ring: exactly ten knots between one bead and the next", arguments: [33, 50, 100])
    func tenBetween(target: Int) {
        let ordered = inRopeOrder(RopeCircleLayout.layout(count: target, diameter: 240))
        var knotsSinceBead = 0
        for mark in ordered.dropFirst() {
            if mark.isBead { #expect(knotsSinceBead == 10); knotsSinceBead = 0 } else { knotsSinceBead += 1 }
        }
        // What is left after the last bead runs on to the start bead: ten at 50 and 100, three at 33.
        #expect(knotsSinceBead == (target % 10 == 0 ? 10 : target % 10))
    }

    @Test("The start bead is filled from the beginning; the others once their tenth knot is counted")
    func passed() {
        let layout = RopeCircleLayout.layout(count: 33, diameter: 240)
        #expect(layout.beadHasBeenPassed(0, count: 0))
        #expect(!layout.beadHasBeenPassed(1, count: 9))
        #expect(layout.beadHasBeenPassed(1, count: 10))
        #expect(!layout.beadHasBeenPassed(2, count: 19))
        #expect(layout.beadHasBeenPassed(3, count: 30))
    }

    @Test("The sound for a counted knot: tick, tock at each bead, bell at the end")
    func cues() {
        #expect(PrayerScreen.cue(afterCounting: 1, of: 33) == .tick)
        #expect(PrayerScreen.cue(afterCounting: 9, of: 33) == .tick)
        #expect(PrayerScreen.cue(afterCounting: 10, of: 33) == .tock)
        #expect(PrayerScreen.cue(afterCounting: 30, of: 33) == .tock)
        #expect(PrayerScreen.cue(afterCounting: 33, of: 33) == .bell)
        // At 50 and 100 the last knot is also a bead; the bell takes it.
        #expect(PrayerScreen.cue(afterCounting: 50, of: 50) == .bell)
        #expect(PrayerScreen.cue(afterCounting: 0, of: 33) == .tick, "the start bead makes no sound")
        #expect(PrayerScreen.cue(afterCounting: 40, of: 50) == .tock)
        #expect(PrayerScreen.cue(afterCounting: 100, of: 100) == .bell)
    }

    @Test("More knots mean smaller knots, on the same ring")
    func dotsShrink() {
        let few = RopeCircleLayout.dotDiameter(count: 33, diameter: 190)
        let many = RopeCircleLayout.dotDiameter(count: 100, diameter: 190)
        #expect(many < few)
    }

    @Test("The first knot sits at the top, just right of centre")
    func startsAtTheTop() {
        let first = RopeCircleLayout.centres(count: 33, diameter: 200)[0]
        #expect(first.y < 20 && first.x > 100)
    }
}
