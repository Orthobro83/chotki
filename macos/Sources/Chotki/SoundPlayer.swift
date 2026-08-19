import Foundation
import AVFoundation
import ChotkiCore

/// Plays the tones core synthesises.
///
/// The sounds are generated once at startup and held in memory, not read from
/// disk — there is no audio file anywhere in the project. Only this playback
/// layer is platform-specific; the tones themselves are portable arithmetic.
@MainActor
final class SoundPlayer {

    private var bell: AVAudioPlayer?
    /// Several tick players in rotation. One player restarted mid-sound cuts
    /// itself off, which on quick presses would swallow clicks — and a click
    /// that does not arrive is worse than none, because you are listening for it.
    private var ticks: [AVAudioPlayer] = []
    private var nextTick = 0

    init() {
        bell = Self.make(.bell)
        ticks = (0..<4).compactMap { _ in Self.make(.tick) }
    }

    private static func make(_ spec: ToneSpec) -> AVAudioPlayer? {
        let data = WAV.encode(ToneRenderer.render(spec))
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.prepareToPlay()
        return player
    }

    func playBell() {
        guard let bell else { return }
        bell.currentTime = 0
        bell.play()
    }

    func playTick() {
        guard !ticks.isEmpty else { return }
        let player = ticks[nextTick % ticks.count]
        nextTick += 1
        player.currentTime = 0
        player.play()
    }
}
