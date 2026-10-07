import Foundation

/// Where the prayer rope's knots and beads sit, evenly round a circle.
///
/// A traditional rope has a bead between every ten knots, where one crosses oneself. A bead is an
/// extra mark on the ring, never a knot with a different face. The first bead is both where the
/// count starts and where it ends: it is already filled when the count begins, makes no sound as
/// the rope is begun, and the rope's chime sounds when the last knot brings the count back to it.
/// So a rope of 100 knots has ten beads, 50 has five, and 33 has four (the three after each ten,
/// and the one at the start, with three knots between the last of them and the start again).
/// The marks shrink as the count grows so a hundred knots and ten beads fit on the ring that holds
/// thirty-three. Pure arithmetic in plain `Double`s, so every platform draws the same ring and it
/// can be tested without drawing anything.
public enum RopeCircleLayout {
    /// The largest a knot is drawn, however few there are.
    public static let largestDot: Double = 11
    /// How much of the space between neighbours a knot may fill. Under 1, so marks never touch.
    public static let fill: Double = 0.62
    /// A bead after this many knots.
    public static let beadEvery = 10
    /// A bead is drawn this much larger than a knot.
    public static let beadScale: Double = 1.4

    public struct Point: Equatable, Sendable {
        public let x: Double
        public let y: Double
    }

    /// Everything to draw, in a square of the given side. Knots and beads are in rope order.
    public struct Layout: Sendable, Equatable {
        public let knots: [Point]
        public let beads: [Point]
        public let dot: Double
        public let bead: Double
        /// `beads[0]` is the start and end bead; `beads[n]` follows knot `beadEvery * n`. The first is filled
        /// from the start; the rest are passed once that many knots are counted.
        public func beadHasBeenPassed(_ index: Int, count: Int) -> Bool { index == 0 || count >= index * RopeCircleLayout.beadEvery }
    }

    /// The start-and-end bead, and one after every ten knots that is not the last knot.
    public static func beadCount(knots: Int) -> Int { knots > 0 ? 1 + (knots - 1) / beadEvery : 0 }

    public static func dotDiameter(count: Int, diameter: Double) -> Double {
        guard count > 0 else { return largestDot }
        let slots = count + beadCount(knots: count)
        let spacing = Double.pi * diameter / Double(slots)
        return min(spacing * fill, largestDot)
    }

    public static func beadDiameter(count: Int, diameter: Double) -> Double {
        dotDiameter(count: count, diameter: diameter) * beadScale
    }

    public static func layout(count: Int, diameter: Double) -> Layout {
        guard count > 0 else { return Layout(knots: [], beads: [], dot: largestDot, bead: largestDot * beadScale) }
        let beads = beadCount(knots: count)
        let slots = count + beads
        let dot = dotDiameter(count: count, diameter: diameter)
        let bead = dot * beadScale
        let radius = diameter / 2 - (beads > 0 ? bead : dot) / 2 - 1
        let middle = diameter / 2
        func point(_ slot: Int) -> Point {
            let angle = -Double.pi / 2 + (Double(slot) + 0.5) * 2 * .pi / Double(slots)
            return Point(x: middle + radius * cos(angle), y: middle + radius * sin(angle))
        }
        // Slot 0 is the start-and-end bead. Knot k (from 0) then sits at slot 1 + k + k / beadEvery,
        // and bead j (from 1) follows knot beadEvery * j, at slot (beadEvery + 1) * j.
        let knotPoints = (0..<count).map { point(1 + $0 + $0 / beadEvery) }
        let beadPoints = (0..<beads).map { point(($0) * (beadEvery + 1)) }
        return Layout(knots: knotPoints, beads: beadPoints, dot: dot, bead: bead)
    }

    /// Centres of the knots only, clockwise from the top.
    public static func centres(count: Int, diameter: Double) -> [Point] {
        layout(count: count, diameter: diameter).knots
    }
}
