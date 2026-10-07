package org.chotki.core

import kotlin.math.sqrt
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Translated from Swift's "The rope as a circle". */
class RopeCircleTest {
    private fun distance(a: RopeCircleLayout.Point, b: RopeCircleLayout.Point) =
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))

    private data class Mark(val at: RopeCircleLayout.Point, val size: Double, val isBead: Boolean)

    /** The marks in rope order: the start bead, ten knots, a bead, ten knots ... */
    private fun inRopeOrder(layout: RopeCircleLayout.Layout): List<Mark> {
        val ordered = mutableListOf(Mark(layout.beads[0], layout.bead, true))
        layout.knots.forEachIndexed { k, knot ->
            ordered += Mark(knot, layout.dot, false)
            val counted = k + 1
            if (counted % 10 == 0 && counted / 10 < layout.beads.size) {
                ordered += Mark(layout.beads[counted / 10], layout.bead, true)
            }
        }
        return ordered
    }

    @Test
    fun `every offered count is drawn with exactly that many knots`() {
        for (target in PrayerScreen.targets) for (diameter in listOf(190.0, 240.0)) {
            assertEquals(target, RopeCircleLayout.centres(target, diameter).size)
        }
    }

    @Test
    fun `ten knots between each bead and a start-and-end bead`() {
        for ((target, expected) in listOf(33 to 4, 50 to 5, 100 to 10)) {
            val layout = RopeCircleLayout.layout(target, 240.0)
            assertEquals(target, layout.knots.size, "beads are added, never swapped for knots")
            assertEquals(expected, layout.beads.size)
            assertTrue(layout.bead > layout.dot)
        }
    }

    @Test
    fun `marks stay inside the square and never touch`() {
        for (target in PrayerScreen.targets) for (diameter in listOf(140.0, 190.0, 240.0, 260.0)) {
            val ordered = inRopeOrder(RopeCircleLayout.layout(target, diameter))
            for (m in ordered) {
                assertTrue(m.at.x - m.size / 2 >= 0 && m.at.x + m.size / 2 <= diameter)
                assertTrue(m.at.y - m.size / 2 >= 0 && m.at.y + m.size / 2 <= diameter)
            }
            for ((a, b) in ordered.zip(ordered.drop(1) + ordered[0])) {
                assertTrue(distance(a.at, b.at) > (a.size + b.size) / 2, "neighbouring marks do not touch")
            }
        }
    }

    @Test
    fun `going round the ring there are exactly ten knots between one bead and the next`() {
        for (target in listOf(33, 50, 100)) {
            var since = 0
            for (mark in inRopeOrder(RopeCircleLayout.layout(target, 240.0)).drop(1)) {
                if (mark.isBead) { assertEquals(10, since); since = 0 } else since += 1
            }
            // What is left after the last bead runs on to the start bead: ten at 50 and 100, three at 33.
            assertEquals(if (target % 10 == 0) 10 else target % 10, since)
        }
    }

    @Test
    fun `more knots mean smaller knots, on the same ring`() {
        assertTrue(RopeCircleLayout.dotDiameter(100, 190.0) < RopeCircleLayout.dotDiameter(33, 190.0))
    }

    @Test
    fun `the start bead is filled from the beginning and the others once their tenth knot is counted`() {
        val layout = RopeCircleLayout.layout(33, 240.0)
        assertTrue(layout.beadHasBeenPassed(0, 0))
        assertFalse(layout.beadHasBeenPassed(1, 9))
        assertTrue(layout.beadHasBeenPassed(1, 10))
        assertFalse(layout.beadHasBeenPassed(2, 19))
        assertTrue(layout.beadHasBeenPassed(3, 30))
    }

    @Test
    fun `the first knot sits at the top, just right of centre`() {
        val first = RopeCircleLayout.centres(33, 200.0)[0]
        assertTrue(first.y < 20 && first.x > 100)
    }

    @Test
    fun `the sound for a counted knot is a tick, a tock at each bead, and a bell at the end`() {
        assertEquals(RopeCue.TICK, PrayerScreen.cue(1, 33))
        assertEquals(RopeCue.TICK, PrayerScreen.cue(9, 33))
        assertEquals(RopeCue.TOCK, PrayerScreen.cue(10, 33))
        assertEquals(RopeCue.TOCK, PrayerScreen.cue(30, 33))
        assertEquals(RopeCue.BELL, PrayerScreen.cue(33, 33))
        // At 50 and 100 the last knot is also the start bead; the bell takes it.
        assertEquals(RopeCue.BELL, PrayerScreen.cue(50, 50))
        assertEquals(RopeCue.TICK, PrayerScreen.cue(0, 33), "the start bead makes no sound")
        assertEquals(RopeCue.TOCK, PrayerScreen.cue(40, 50))
        assertEquals(RopeCue.BELL, PrayerScreen.cue(100, 100))
    }
}
