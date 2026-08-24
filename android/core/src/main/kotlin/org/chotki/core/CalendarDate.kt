package org.chotki.core

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * A day in the civil calendar. No time, no time zone, no instant.
 *
 * This is the single most important type in the model. A rule due "on 19 August"
 * is due on 19 August wherever the user is and whatever the clocks did overnight.
 * Storing that as an instant is how tasks silently shift by a day across a DST
 * boundary or a flight — a bug that surfaces months later and is miserable to
 * trace. Keeping the day and the wall-clock time as separate, zone-free values
 * makes the whole class of error unrepresentable rather than merely tested for.
 *
 * The one place a real instant is needed is scheduling a notification, and that
 * conversion is explicit: see [dueInstant].
 *
 * Ported from `CalendarDate.swift`, with one improvement the Swift version's own
 * comments ask for: [weekday] and [plusDays] are computed here rather than
 * handed to a calendar library. The Swift original reaches for `Foundation` for
 * both; doing the arithmetic directly means this type depends on nothing at all,
 * which is the property that makes it safe to port in the first place.
 */
@Serializable(with = CalendarDateSerializer::class)
class CalendarDate private constructor(
    val year: Int,
    val month: Int,
    val day: Int,
) : Comparable<CalendarDate> {

    companion object {
        /**
         * Returns null for dates that do not exist, such as 31 April or
         * 29 February in a common year. Values often arrive from stored data,
         * so this validates rather than throwing.
         */
        fun of(year: Int, month: Int, day: Int): CalendarDate? {
            if (month !in 1..12 || day < 1) return null
            if (day > daysInMonth(year, month)) return null
            return CalendarDate(year, month, day)
        }

        /**
         * Parses "YYYY-MM-DD". Storage writes this form because it sorts
         * lexicographically, so SQLite can order and range-scan dates without
         * any date handling of its own.
         */
        fun parse(iso: String): CalendarDate? {
            val parts = iso.split('-')
            if (parts.size != 3) return null
            val y = parts[0].toIntOrNull() ?: return null
            val m = parts[1].toIntOrNull() ?: return null
            val d = parts[2].toIntOrNull() ?: return null
            return of(y, m, d)
        }

        fun from(instant: Instant, zone: ZoneId): CalendarDate {
            val local = LocalDateTime.ofInstant(instant, zone)
            // Always a real date, so the null branch cannot be taken.
            return of(local.year, local.monthValue, local.dayOfMonth)!!
        }

        fun daysInMonth(year: Int, month: Int): Int = when (month) {
            1, 3, 5, 7, 8, 10, 12 -> 31
            4, 6, 9, 11 -> 30
            2 -> if (isLeapYear(year)) 29 else 28
            else -> 0
        }

        fun isLeapYear(year: Int): Boolean =
            (year % 4 == 0 && year % 100 != 0) || year % 400 == 0

        /**
         * The inverse of [daysSinceEpoch]: the civil date that many days after
         * 1 January 1970.
         *
         * The same shifted-year trick, run backwards. Together the two make day
         * arithmetic exact and constant-time without a calendar library — which
         * is what lets [plusDays] cross months, years and leap days without
         * touching `java.time`.
         */
        internal fun fromDaysSinceEpoch(days: Int): CalendarDate {
            val z = days + 719_468
            val era = (if (z >= 0) z else z - 146_096) / 146_097
            val doe = z - era * 146_097                                  // 0...146096
            val yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
            val y = yoe + era * 400
            val doy = doe - (365 * yoe + yoe / 4 - yoe / 100)            // 0...365
            val mp = (5 * doy + 2) / 153                                 // 0...11
            val d = doy - (153 * mp + 2) / 5 + 1                         // 1...31
            val m = if (mp < 10) mp + 3 else mp - 9                      // 1...12
            return CalendarDate(if (m <= 2) y + 1 else y, m, d)
        }
    }

    val lastDayOfMonth: Int get() = daysInMonth(year, month)

    /**
     * Days since 1 January 1970, by direct calculation.
     *
     * Constant time, exact for any year, and it builds no date object — which
     * matters because scoring asks for the distance between days once per due
     * day, and an earlier version of this stepped a day at a time and gave up
     * silently after four thousand of them.
     *
     * The standard civil-to-days algorithm: shift the year so that March is the
     * first month, which puts the leap day at the end of the year and removes it
     * from the arithmetic entirely.
     */
    val daysSinceEpoch: Int
        get() {
            var y = year
            if (month <= 2) y -= 1
            val era = (if (y >= 0) y else y - 399) / 400
            val yoe = y - era * 400                                       // 0...399
            val monthShift = if (month > 2) -3 else 9
            val doy = (153 * (month + monthShift) + 2) / 5 + day - 1      // 0...365
            val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy               // 0...146096
            return era * 146_097 + doe - 719_468
        }

    /**
     * 1 January 1970 was a Thursday, which anchors the whole cycle. Uses a
     * floored modulus so dates before the epoch are as correct as those after.
     */
    val weekday: Weekday
        get() = Weekday.of(Math.floorMod(daysSinceEpoch + 4, 7) + 1)

    fun plusDays(days: Int): CalendarDate = fromDaysSinceEpoch(daysSinceEpoch + days)

    /** Whole days from this date to [other]. Negative if [other] is earlier. */
    fun daysUntil(other: CalendarDate): Int = other.daysSinceEpoch - daysSinceEpoch

    /**
     * The one deliberate crossing into real time. Converting a day plus a
     * wall-clock time into an instant is exactly where DST lives, so it is a
     * single named function that takes the zone explicitly.
     *
     * Returns null for a time that does not exist on that day — 01:30 on a
     * spring-forward morning, for instance. Callers must decide what to do
     * rather than being handed a silently shifted instant.
     *
     * For an hour repeated by falling back, the earlier of the two is returned:
     * ambiguous is not the same as impossible, and one of them is enough.
     */
    fun dueInstant(time: TimeOfDay, zone: ZoneId): Instant? {
        val local = LocalDateTime.of(year, month, day, time.hour, time.minute)
        val zoned = local.atZone(zone)
        // A gap is not reported as an error: the time is moved forward instead.
        // Comparing it back is what catches that, exactly as the Swift version
        // re-reads the components it asked for.
        if (zoned.toLocalDateTime() != local) return null
        return zoned.toInstant()
    }

    val iso: String get() = toString()

    override fun compareTo(other: CalendarDate): Int =
        compareValuesBy(this, other, { it.year }, { it.month }, { it.day })

    override fun equals(other: Any?): Boolean =
        other is CalendarDate && year == other.year && month == other.month && day == other.day

    override fun hashCode(): Int = (year * 31 + month) * 31 + day

    override fun toString(): String =
        "%04d-%02d-%02d".format(year, month, day)
}

/**
 * Written as "YYYY-MM-DD", the same form the database columns use — it sorts
 * lexicographically, so SQLite can order and range-scan dates without any date
 * handling of its own.
 */
object CalendarDateSerializer : KSerializer<CalendarDate> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("CalendarDate", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: CalendarDate) =
        encoder.encodeString(value.iso)

    override fun deserialize(decoder: Decoder): CalendarDate {
        val text = decoder.decodeString()
        return CalendarDate.parse(text) ?: error("not a date: $text")
    }
}

@Serializable
enum class Weekday(val number: Int) {
    SUNDAY(1), MONDAY(2), TUESDAY(3), WEDNESDAY(4),
    THURSDAY(5), FRIDAY(6), SATURDAY(7);

    companion object {
        fun of(number: Int): Weekday =
            entries.firstOrNull { it.number == number }
                ?: error("no weekday numbered $number")
    }
}
