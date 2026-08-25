package org.chotki.core.sound

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.sin

/**
 * One component of a struck tone.
 *
 * A bell is not a sine wave. Its partials are *inharmonic* — they sit at ratios
 * that are not whole multiples of the fundamental — and each one decays at its
 * own rate, the high ones fastest. That combination is what makes a struck bell
 * sound like metal rather than a beep.
 */
data class Partial(
    /** Multiple of the fundamental frequency. */
    val ratio: Double,
    val amplitude: Double,
    /** Seconds for this partial to fall to about a third of its level. */
    val decay: Double,
)

data class ToneSpec(
    val fundamental: Double,
    val partials: List<Partial>,
    val duration: Double,
    /** A short fade in, because a waveform that starts at full amplitude clicks. */
    val attack: Double = 0.004,
    val gain: Double = 1.0,
) {
    companion object {
        /**
         * The chime when a knot is complete.
         *
         * Ratios follow the classical bell partials — hum, prime, tierce, quint,
         * nominal — with a couple of bright upper ones that fade quickly. The
         * tierce at 1.19 is the minor third that gives a bell its characteristic
         * slightly mournful colour.
         */
        val BELL = ToneSpec(
            fundamental = 587.33, // D5
            partials = listOf(
                Partial(0.50, 0.32, 2.60), // hum
                Partial(1.00, 1.00, 1.90), // prime
                Partial(1.19, 0.52, 1.40), // tierce
                Partial(1.50, 0.28, 1.00), // quint
                Partial(2.00, 0.44, 0.90), // nominal
                Partial(2.55, 0.16, 0.45),
                Partial(3.42, 0.09, 0.28),
            ),
            duration = 2.6,
            gain = 0.55,
        )

        /**
         * The soft click as a knot passes: quiet, brief, and pitched well above
         * the bell so the two never sound like the same event.
         */
        val TICK = ToneSpec(
            fundamental = 1_620.0,
            partials = listOf(
                Partial(1.00, 1.00, 0.018),
                Partial(2.10, 0.40, 0.010),
                Partial(3.70, 0.18, 0.006),
            ),
            duration = 0.05,
            attack = 0.001,
            gain = 0.16,
        )
    }
}

/**
 * Renders a struck tone to samples.
 *
 * Pure arithmetic — no audio framework, no files, nothing platform-specific — so
 * it sounds the same wherever the app runs and can be tested without a sound
 * card. The platform's only job is to play the numbers.
 */
object ToneRenderer {

    fun render(spec: ToneSpec, sampleRate: Double = 44_100.0): FloatArray {
        val count = max(1, (spec.duration * sampleRate).toInt())
        val samples = FloatArray(count)

        for (index in 0 until count) {
            val t = index / sampleRate
            var value = 0.0
            for (partial in spec.partials) {
                val frequency = spec.fundamental * partial.ratio
                val envelope = exp(-t / partial.decay)
                value += partial.amplitude * envelope * sin(2 * PI * frequency * t)
            }

            // Fade in over the attack, and out over the last stretch, so the
            // sample neither clicks on nor is cut off mid-swing.
            if (t < spec.attack) value *= t / spec.attack
            val fadeOut = 0.06
            val remaining = spec.duration - t
            if (remaining < fadeOut) value *= max(0.0, remaining / fadeOut)

            samples[index] = (value * spec.gain).toFloat()
        }

        return normalised(samples, spec.gain.toFloat())
    }

    /**
     * Scales down if the partials happened to sum past the ceiling. Clipping
     * turns a bell into a buzz.
     */
    private fun normalised(samples: FloatArray, ceiling: Float): FloatArray {
        var peak = 0f
        for (sample in samples) peak = max(peak, abs(sample))
        if (peak <= ceiling || peak <= 0f) return samples
        val scale = ceiling / peak
        return FloatArray(samples.size) { samples[it] * scale }
    }
}
