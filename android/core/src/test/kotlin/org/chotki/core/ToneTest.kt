package org.chotki.core

import org.chotki.core.sound.ToneRenderer
import org.chotki.core.sound.ToneSpec
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The chime, as arithmetic.
 *
 * Nothing here listens to anything. What can be checked without ears is that the
 * sample is the right length, starts and ends at silence so it neither clicks on
 * nor is cut off mid-swing, never clips, and actually decays — a bell that did
 * not decay would be a drone.
 */
class ToneTest {

    private val rate = 44_100.0

    @Test
    fun `the bell is as long as it says`() {
        val samples = ToneRenderer.render(ToneSpec.BELL, rate)
        assertEquals((ToneSpec.BELL.duration * rate).toInt(), samples.size)
    }

    // A waveform that begins at full amplitude clicks, and one cut off mid-swing
    // ends with a thud.
    @Test
    fun `it fades in and out rather than starting or stopping abruptly`() {
        val samples = ToneRenderer.render(ToneSpec.BELL, rate)
        assertTrue(abs(samples.first()) < 0.001f, "it starts at ${samples.first()}")
        assertTrue(abs(samples.last()) < 0.01f, "it ends at ${samples.last()}")
    }

    @Test
    fun `nothing clips`() {
        for (spec in listOf(ToneSpec.BELL, ToneSpec.TICK)) {
            val peak = ToneRenderer.render(spec, rate).maxOf { abs(it) }
            assertTrue(peak <= 1.0f, "peak $peak would clip")
            assertTrue(peak <= spec.gain.toFloat() + 1e-6f, "peak $peak exceeds its own ceiling")
        }
    }

    @Test
    fun `a struck tone decays`() {
        val samples = ToneRenderer.render(ToneSpec.BELL, rate)
        fun energy(from: Int, to: Int) = (from until to).sumOf { abs(samples[it]).toDouble() }
        val early = energy(1_000, 6_000)
        val late = energy(samples.size - 20_000, samples.size - 15_000)
        assertTrue(late < early / 2, "it does not decay: $early then $late")
    }

    // Quiet, brief, and pitched well above the bell, so the two are never heard
    // as the same event.
    @Test
    fun `the tick is much shorter and much quieter than the bell`() {
        val tick = ToneRenderer.render(ToneSpec.TICK, rate)
        val bell = ToneRenderer.render(ToneSpec.BELL, rate)
        assertTrue(tick.size * 20 < bell.size, "the tick is not brief")
        assertTrue(ToneSpec.TICK.gain < ToneSpec.BELL.gain / 3)
        assertTrue(ToneSpec.TICK.fundamental > ToneSpec.BELL.fundamental * 2)
    }

    @Test
    fun `a bell has inharmonic partials, which is what makes it metal`() {
        val ratios = ToneSpec.BELL.partials.map { it.ratio }
        assertTrue(ratios.any { it != Math.floor(it) }, "every partial is a whole multiple")
        assertTrue(ratios.contains(1.19), "the tierce is what gives a bell its colour")
    }

    @Test
    fun `higher partials fade faster than lower ones`() {
        val bell = ToneSpec.BELL.partials
        val hum = bell.first { it.ratio == 0.50 }
        val highest = bell.maxBy { it.ratio }
        assertTrue(highest.decay < hum.decay, "the top partial rings longer than the hum")
    }

    @Test
    fun `rendering is deterministic`() {
        assertTrue(
            ToneRenderer.render(ToneSpec.TICK, rate)
                .contentEquals(ToneRenderer.render(ToneSpec.TICK, rate)),
        )
    }

    @Test
    fun `a different sample rate gives proportionally more samples`() {
        val at44 = ToneRenderer.render(ToneSpec.TICK, 44_100.0).size
        val at48 = ToneRenderer.render(ToneSpec.TICK, 48_000.0).size
        assertTrue(at48 > at44)
    }
}
