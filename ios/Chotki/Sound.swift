import AVFoundation
import ChotkiCore

/// The tick and the bell, rendered from core rather than shipped as files.
///
/// `ToneRenderer` builds the waveform and `WAV` encodes it, so all three
/// platforms sound the same because they are computing the same thing rather
/// than each carrying an audio file someone exported once.
@MainActor
final class Sound {
    static let shared = Sound()

    private var bell: AVAudioPlayer?
    private var ticks: [AVAudioPlayer] = []
    private var next = 0

    private init() {
        bell = Self.make(.bell)
        // Several, because a knot can be counted faster than a tick decays and
        // one player restarting cuts its own tail off.
        ticks = (0..<4).compactMap { _ in Self.make(.tick) }
        configureSession()
    }

    /// Ambient, and mixing with whatever else is playing.
    ///
    /// The category matters more than it looks. On Android the equivalent was
    /// USAGE_ASSISTANCE_SONIFICATION, which follows the ringer — so a phone on
    /// vibrate played nothing, which is most phones most of the time, and it
    /// worked on an emulator and not on a real device. `.ambient` follows the
    /// media volume and does not stop anyone's music to make a tick.
    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func make(_ spec: ToneSpec) -> AVAudioPlayer? {
        let data = WAV.encode(ToneRenderer.render(spec))
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.prepareToPlay()
        return player
    }

    func playBell() {
        bell?.currentTime = 0
        bell?.play()
    }

    func playTick() {
        guard !ticks.isEmpty else { return }
        let player = ticks[next % ticks.count]
        next += 1
        player.currentTime = 0
        player.play()
    }
}
