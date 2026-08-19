import Testing
import Foundation
@testable import ChotkiCore

@Suite("Struck tones")
struct ToneTests {

    @Test("length follows the duration")
    func length() {
        let samples = ToneRenderer.render(.bell, sampleRate: 44_100)
        #expect(samples.count == Int(ToneSpec.bell.duration * 44_100))
    }

    // Clipping turns a bell into a buzz, and it is the most likely way this
    // goes wrong: seven partials summed can easily exceed full scale.
    @Test("nothing clips", arguments: [ToneSpec.bell, .tick])
    func neverClips(spec: ToneSpec) {
        let samples = ToneRenderer.render(spec)
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        #expect(peak <= 1.0)
        #expect(Double(peak) <= spec.gain + 0.001, "the ceiling should hold")
        #expect(peak > 0.01, "and it should not be silent")
    }

    // A waveform that starts at full amplitude clicks, which on a prayer rope
    // would be worse than no sound at all.
    @Test("it fades in rather than clicking", arguments: [ToneSpec.bell, .tick])
    func fadesIn(spec: ToneSpec) {
        let samples = ToneRenderer.render(spec)
        #expect(abs(samples[0]) < 0.001)
    }

    @Test("it fades out rather than being cut off", arguments: [ToneSpec.bell, .tick])
    func fadesOut(spec: ToneSpec) {
        let samples = ToneRenderer.render(spec)
        #expect(abs(samples[samples.count - 1]) < 0.001)
    }

    @Test("it decays — the end is quieter than the beginning")
    func decays() {
        let samples = ToneRenderer.render(.bell)
        func peak(_ range: Range<Int>) -> Float {
            samples[range].reduce(Float(0)) { max($0, abs($1)) }
        }
        let early = peak(1_000..<10_000)
        let late = peak((samples.count - 10_000)..<(samples.count - 1_000))
        #expect(late < early / 4, "a struck tone rings out, it does not hold")
    }

    // The two sounds mark different events and must not be mistaken for each
    // other with your eyes closed.
    @Test("the tick is brief and much quieter than the bell")
    func tickIsSubordinate() {
        let bell = ToneRenderer.render(.bell)
        let tick = ToneRenderer.render(.tick)
        #expect(tick.count < bell.count / 20, "brief")

        let bellPeak = bell.reduce(Float(0)) { max($0, abs($1)) }
        let tickPeak = tick.reduce(Float(0)) { max($0, abs($1)) }
        #expect(tickPeak < bellPeak / 2, "quiet")
        #expect(ToneSpec.tick.fundamental > ToneSpec.bell.fundamental * 2, "and clearly higher")
    }

    @Test("a bell has inharmonic partials, which is what makes it metal")
    func partialsAreInharmonic() {
        let ratios = ToneSpec.bell.partials.map(\.ratio)
        #expect(ratios.contains { abs($0 - round($0)) > 0.1 },
                "whole-number ratios alone would sound like an organ, not a bell")
        #expect(ratios.contains { abs($0 - 1.19) < 0.05 }, "the minor-third tierce")
    }

    @Test("higher partials fade first, as they do in a real bell")
    func highPartialsDecayFaster() {
        let sorted = ToneSpec.bell.partials.sorted { $0.ratio < $1.ratio }
        #expect(sorted.first!.decay > sorted.last!.decay)
    }
}

@Suite("WAV encoding")
struct WAVTests {

    @Test("the header describes the data that follows")
    func header() {
        let samples = ToneRenderer.render(.tick)
        let data = WAV.encode(samples, sampleRate: 44_100)

        func text(_ range: Range<Int>) -> String {
            String(decoding: data[range], as: UTF8.self)
        }
        func int32(_ offset: Int) -> Int {
            data[offset..<(offset + 4)].reversed().reduce(0) { ($0 << 8) | Int($1) }
        }

        #expect(text(0..<4) == "RIFF")
        #expect(text(8..<12) == "WAVE")
        #expect(text(12..<16) == "fmt ")
        #expect(text(36..<40) == "data")
        #expect(int32(24) == 44_100, "sample rate")
        #expect(int32(40) == samples.count * 2, "16-bit mono")
        #expect(data.count == 44 + samples.count * 2)
    }

    @Test("samples out of range are clamped rather than wrapping")
    func clamping() {
        // Wrapping would turn a loud sample into a loud sample of the opposite
        // sign, which sounds like a tear.
        let data = WAV.encode([2.0, -2.0], sampleRate: 44_100)
        let first = Int16(littleEndian: data[44..<46].withUnsafeBytes { $0.load(as: Int16.self) })
        let second = Int16(littleEndian: data[46..<48].withUnsafeBytes { $0.load(as: Int16.self) })
        #expect(first == 32_767)
        #expect(second == -32_767)
    }
}
