package org.chotki.core.content

import org.chotki.core.CalendarDate

/**
 * Which passage belongs to a given day.
 *
 * Chosen by the day of the year, so it is stable for a given day and does not
 * change if the app is reopened — a reading that shuffled every time it was
 * looked at would be a different thing to read rather than the day's reading.
 */
object PatristicReadings {

    fun forDay(date: CalendarDate): PatristicReadingJson? {
        val readings = Content.patristicReadings
        if (readings.isEmpty()) return null
        return readings[dayOfYear(date) % readings.size]
    }

    private fun dayOfYear(date: CalendarDate): Int {
        var total = date.day
        for (month in 1 until date.month) {
            total += CalendarDate.daysInMonth(date.year, month)
        }
        return total
    }
}
