package org.chotki.core

import kotlinx.serialization.Serializable

/**
 * How a time of day is written.
 *
 * Not a formatting preference so much as a safety one. A rule set for the
 * evening and shown as "10:30" reads as the morning to anyone used to a
 * twelve-hour clock, and the mistake is invisible: the day's list is sorted by
 * time, so it sorts neatly into the wrong place and nothing looks amiss.
 */
@Serializable
enum class ClockStyle(val displayName: String) {
    /** 06:30, 21:00. */
    TWENTY_FOUR_HOUR("24-hour (06:30)"),

    /** 6:30 AM, 9:00 PM. */
    TWELVE_HOUR("12-hour (6:30 AM)"),
}

/** Turning values into the words shown on screen. */
object Format {

    private val weekdays = listOf(
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    )
    private val months = listOf(
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    )

    /** "Sunday" */
    fun weekdayName(weekday: Weekday): String = weekdays[weekday.number - 1]

    /**
     * "30 August 2026"
     *
     * The year is not optional here. A day list looking at this week does not
     * need it; a journal does, because two entries can share a date across years
     * and the whole point is comparing them.
     */
    fun dateWithYear(date: CalendarDate): String =
        "${date.day} ${months[date.month - 1]} ${date.year}"


    fun time(time: TimeOfDay, style: ClockStyle = ClockStyle.TWENTY_FOUR_HOUR): String =
        when (style) {
            ClockStyle.TWENTY_FOUR_HOUR -> "%02d:%02d".format(time.hour, time.minute)
            ClockStyle.TWELVE_HOUR -> {
                val hour = if (time.hour % 12 == 0) 12 else time.hour % 12
                "%d:%02d %s".format(hour, time.minute, if (time.hour < 12) "AM" else "PM")
            }
        }

    /**
     * One hour, for a picker that has to be unambiguous on its own.
     *
     * A list of bare numbers from 00 to 23 is what let an evening rule be set to
     * half past ten in the morning: 10 looks like the right answer to someone
     * thinking in twelve hours, and nothing afterwards says otherwise.
     */
    fun hourLabel(hour: Int, style: ClockStyle = ClockStyle.TWENTY_FOUR_HOUR): String =
        when (style) {
            ClockStyle.TWENTY_FOUR_HOUR -> "%02d".format(hour)
            ClockStyle.TWELVE_HOUR ->
                "${if (hour % 12 == 0) 12 else hour % 12} ${if (hour < 12) "AM" else "PM"}"
        }
}
