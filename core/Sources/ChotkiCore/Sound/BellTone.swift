import Foundation

/// One component of a struck tone.
///
/// A bell is not a sine wave. Its partials are *inharmonic* — they sit at
/// ratios that are not whole multiples of the fundamental — and each one decays
/// at its own rate, the high ones fastest. That combination is what makes a
/// struck bell sound like metal rather than a beep.
public struct Partial: Sendable, Hashable {
    /// Multiple of the fundamental frequency.
    public let ratio: Double
    public let amplitude: Double
    /// Seconds for this partial to fall to about a third of its level.
    public let decay: Double

    public init(ratio: Double, amplitude: Double, decay: Double) {
        self.ratio = ratio
        self.amplitude = amplitude
        self.decay = decay
    }
}

public struct ToneSpec: Sendable, Hashable {
    public let fundamental: Double
    public let partials: [Partial]
    public let duration: Double
    /// A short fade in, because a waveform that starts at full amplitude clicks.
    public let attack: Double
    public let gain: Double

    public init(
        fundamental: Double, partials: [Partial], duration: Double,
        attack: Double = 0.004, gain: Double = 1.0
    ) {
        self.fundamental = fundamental
        self.partials = partials
        self.duration = duration
        self.attack = attack
        self.gain = gain
    }

    /// The chime when a knot is complete.
    ///
    /// Ratios follow the classical bell partials — hum, prime, tierce, quint,
    /// nominal — with a couple of bright upper ones that fade quickly. The
    /// tierce at 1.2 is the minor third that gives a bell its characteristic
    /// slightly mournful colour.
    public static let bell = ToneSpec(
        fundamental: 587.33,                              // D5
        partials: [
            Partial(ratio: 0.50, amplitude: 0.32, decay: 2.60),   // hum
            Partial(ratio: 1.00, amplitude: 1.00, decay: 1.90),   // prime
            Partial(ratio: 1.19, amplitude: 0.52, decay: 1.40),   // tierce
            Partial(ratio: 1.50, amplitude: 0.28, decay: 1.00),   // quint
            Partial(ratio: 2.00, amplitude: 0.44, decay: 0.90),   // nominal
            Partial(ratio: 2.55, amplitude: 0.16, decay: 0.45),
            Partial(ratio: 3.42, amplitude: 0.09, decay: 0.28)
        ],
        duration: 2.6,
        gain: 0.55
    )

    /// The soft click as a knot passes: quiet, brief, and pitched well above
    /// the bell so the two never sound like the same event.
    public static let tick = ToneSpec(
        fundamental: 1_620,
        partials: [
            Partial(ratio: 1.00, amplitude: 1.00, decay: 0.018),
            Partial(ratio: 2.10, amplitude: 0.40, decay: 0.010),
            Partial(ratio: 3.70, amplitude: 0.18, decay: 0.006)
        ],
        duration: 0.05,
        attack: 0.001,
        gain: 0.16
    )
}

/// Renders a struck tone to samples. Pure arithmetic — no audio framework, no
/// files, nothing platform-specific, so it works the same wherever the app runs
/// and can be tested without a sound card.
public enum ToneRenderer {

    public static func render(_ spec: ToneSpec, sampleRate: Double = 44_100) -> [Float] {
        let count = max(1, Int(spec.duration * sampleRate))
        var samples = [Float](repeating: 0, count: count)

        for index in 0..<count {
            let t = Double(index) / sampleRate
            var value = 0.0
            for partial in spec.partials {
                let frequency = spec.fundamental * partial.ratio
                let envelope = exp(-t / partial.decay)
                value += partial.amplitude * envelope * sin(2 * .pi * frequency * t)
            }

            // Fade in over the attack, and out over the last stretch, so the
            // sample neither clicks on nor is cut off mid-swing.
            if t < spec.attack {
                value *= t / spec.attack
            }
            let fadeOut = 0.06
            let remaining = spec.duration - t
            if remaining < fadeOut {
                value *= max(0, remaining / fadeOut)
            }

            samples[index] = Float(value * spec.gain)
        }

        return normalised(samples, ceiling: Float(spec.gain))
    }

    /// Scales down if the partials happened to sum past the ceiling. Clipping
    /// turns a bell into a buzz.
    private static func normalised(_ samples: [Float], ceiling: Float) -> [Float] {
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        guard peak > ceiling, peak > 0 else { return samples }
        let scale = ceiling / peak
        return samples.map { $0 * scale }
    }
}
