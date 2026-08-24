package org.chotki.core

/**
 * A wall-clock time with no date and no time zone.
 *
 * Deliberately not an instant. A rule set for 06:30 means 06:30 on whatever day
 * it falls, in whatever zone the user is in — storing that as an instant is how
 * tasks silently shift by an hour across a DST boundary.
 */
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
