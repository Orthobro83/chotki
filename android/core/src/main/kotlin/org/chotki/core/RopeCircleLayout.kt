package org.chotki.core

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Where the prayer rope's knots and beads sit, evenly round a circle. Ported from
 * `RopeCircleLayout.swift`; the arithmetic is the same so every platform draws the same ring.
 *
 * A traditional rope has a bead between every ten knots, where one crosses oneself. A bead is an
 * extra mark on the ring, never a knot with a different face. The first bead is both where the
 * count starts and where it ends: it is already filled when the count begins, makes no sound as
 * the rope is begun, and the rope's chime sounds when the last knot brings the count back to it.
 * So a rope of 100 knots has ten beads, 50 has five, and 33 has four (the three after each ten,
 * and the one at the start, with three knots between the last of them and the start again).
 * The marks shrink as the count grows so a hundred knots and ten beads fit on the ring that holds
 * thirty-three.
 */
object RopeCircleLayout {
    /** The largest a knot is drawn, however few there are. */
    const val LARGEST_DOT = 11.0

    /** How much of the space between neighbours a knot may fill. Under 1, so marks never touch. */
    const val FILL = 0.62

    /** A bead after this many knots. */
    const val BEAD_EVERY = 10

    /** A bead is drawn this much larger than a knot. */
    const val BEAD_SCALE = 1.4

    data class Point(val x: Double, val y: Double)

    /** Everything to draw, in a square of the given side. Knots and beads are in rope order. */
    data class Layout(val knots: List<Point>, val beads: List<Point>, val dot: Double, val bead: Double) {
        /**
         * `beads[0]` is the start and end bead; `beads[n]` follows knot `BEAD_EVERY * n`. The first is
         * filled from the start; the rest are passed once that many knots are counted.
         */
        fun beadHasBeenPassed(index: Int, count: Int): Boolean = index == 0 || count >= index * BEAD_EVERY
    }

    /** The start-and-end bead, and one after every ten knots that is not the last knot. */
    fun beadCount(knots: Int): Int = if (knots > 0) 1 + (knots - 1) / BEAD_EVERY else 0

    fun dotDiameter(count: Int, diameter: Double): Double {
        if (count <= 0) return LARGEST_DOT
        val slots = count + beadCount(count)
        val spacing = PI * diameter / slots
        return min(spacing * FILL, LARGEST_DOT)
    }

    fun beadDiameter(count: Int, diameter: Double): Double = dotDiameter(count, diameter) * BEAD_SCALE

    fun layout(count: Int, diameter: Double): Layout {
        if (count <= 0) return Layout(emptyList(), emptyList(), LARGEST_DOT, LARGEST_DOT * BEAD_SCALE)
        val beads = beadCount(count)
        val slots = count + beads
        val dot = dotDiameter(count, diameter)
        val bead = dot * BEAD_SCALE
        val radius = diameter / 2 - (if (beads > 0) bead else dot) / 2 - 1
        val middle = diameter / 2
        fun point(slot: Int): Point {
            val angle = -PI / 2 + (slot + 0.5) * 2 * PI / slots
            return Point(middle + radius * cos(angle), middle + radius * sin(angle))
        }
        // Slot 0 is the start-and-end bead. Knot k (from 0) then sits at slot 1 + k + k / BEAD_EVERY,
        // and bead j (from 1) follows knot BEAD_EVERY * j, at slot (BEAD_EVERY + 1) * j.
        val knotPoints = (0 until count).map { point(1 + it + it / BEAD_EVERY) }
        val beadPoints = (0 until beads).map { point(it * (BEAD_EVERY + 1)) }
        return Layout(knotPoints, beadPoints, dot, bead)
    }

    /** Centres of the knots only, clockwise from the top. */
    fun centres(count: Int, diameter: Double): List<Point> = layout(count, diameter).knots
}
