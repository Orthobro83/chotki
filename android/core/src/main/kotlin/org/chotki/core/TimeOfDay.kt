package org.chotki.core

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

/**
 * A wall-clock time with no date and no time zone.
 *
 * Deliberately not an instant. A rule set for 06:30 means 06:30 on whatever day
 * it falls, in whatever zone the user is in — storing that as an instant is how
 * tasks silently shift by an hour across a DST boundary.
 */
@Serializable(with = TimeOfDaySerializer::class)
class TimeOfDay private constructor(
    val hour: Int,
    val minute: Int,
) : Comparable<TimeOfDay> {

    companion object {
        /** Returns null rather than throwing: values often arrive from storage. */
        fun of(hour: Int, minute: Int): TimeOfDay? {
            if (hour !in 0..23 || minute !in 0..59) return null
            return TimeOfDay(hour, minute)
        }
    }

    val minutesSinceMidnight: Int get() = hour * 60 + minute

    override fun compareTo(other: TimeOfDay): Int =
        minutesSinceMidnight.compareTo(other.minutesSinceMidnight)

    override fun equals(other: Any?): Boolean =
        other is TimeOfDay && hour == other.hour && minute == other.minute

    override fun hashCode(): Int = minutesSinceMidnight

    override fun toString(): String = "%02d:%02d".format(hour, minute)
}

/** Written as "HH:mm", on a 24-hour clock and never a localised one. */
object TimeOfDaySerializer : KSerializer<TimeOfDay> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("TimeOfDay", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: TimeOfDay) =
        encoder.encodeString("%02d:%02d".format(value.hour, value.minute))

    override fun deserialize(decoder: Decoder): TimeOfDay {
        val text = decoder.decodeString()
        val parts = text.split(':')
        val time = if (parts.size == 2) {
            TimeOfDay.of(parts[0].toInt(), parts[1].toInt())
        } else {
            null
        }
        return time ?: error("not a time: $text")
    }
}
