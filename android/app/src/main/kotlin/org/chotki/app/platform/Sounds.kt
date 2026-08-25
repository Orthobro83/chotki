package org.chotki.app.platform

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import org.chotki.core.sound.ToneRenderer
import org.chotki.core.sound.ToneSpec

/**
 * Plays what `:core` renders. It synthesises nothing itself.
 *
 * Both tones are rendered once and kept: a tick has to land the instant the knot
 * is counted, and rendering two thousand samples on the way to the speaker would
 * put a wobble exactly where steadiness matters.
 *
 * Marked as a *sonification* rather than media, so it does not duck music or
 * take audio focus — someone praying with a recording on should not have it
 * interrupted by a chime.
 */
object Sounds {

    private const val SAMPLE_RATE = 44_100

    private val tick by lazy { pcm(ToneSpec.TICK) }
    private val bell by lazy { pcm(ToneSpec.BELL) }

    fun playTick() = play(tick)
    fun playBell() = play(bell)

    private fun pcm(spec: ToneSpec): ShortArray {
        val samples = ToneRenderer.render(spec, SAMPLE_RATE.toDouble())
        return ShortArray(samples.size) { (samples[it] * Short.MAX_VALUE).toInt().toShort() }
    }

    private fun play(samples: ShortArray) {
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                // USAGE_MEDIA, not USAGE_ASSISTANCE_SONIFICATION. Sonification
                // follows the ringer, so on a phone with the switch on vibrate
                // the tick and the bell are silent — which is most phones, most
                // of the time, and it is why this worked on an emulator and not
                // on a real device. The rope is something a person has chosen
                // to listen to, so it belongs on the media volume they can
                // actually reach.
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(samples.size * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        track.write(samples, 0, samples.size)
        track.setNotificationMarkerPosition(samples.size)
        track.setPlaybackPositionUpdateListener(
            object : AudioTrack.OnPlaybackPositionUpdateListener {
                override fun onMarkerReached(played: AudioTrack?) = played?.release() ?: Unit
                override fun onPeriodicNotification(played: AudioTrack?) = Unit
            },
        )
        track.play()
    }
}
