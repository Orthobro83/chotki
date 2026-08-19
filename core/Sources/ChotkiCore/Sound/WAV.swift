import Foundation

/// Wraps samples in a WAV container.
///
/// Written by hand rather than through an audio framework so the tone can be
/// produced anywhere — including in a test, and on a platform with no audio
/// stack at all.
public enum WAV {

    public static func encode(_ samples: [Float], sampleRate: Int = 44_100) -> Data {
        var data = Data()
        let channels = 1
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataBytes = samples.count * bitsPerSample / 8

        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: Int) {
            var little = UInt32(truncatingIfNeeded: value).littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func append16(_ value: Int) {
            var little = UInt16(truncatingIfNeeded: value).littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        append("RIFF")
        append32(36 + dataBytes)
        append("WAVE")
        append("fmt ")
        append32(16)            // PCM header size
        append16(1)             // PCM
        append16(channels)
        append32(sampleRate)
        append32(byteRate)
        append16(blockAlign)
        append16(bitsPerSample)
        append("data")
        append32(dataBytes)

        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append16(Int(clamped * 32_767))
        }
        return data
    }
}
