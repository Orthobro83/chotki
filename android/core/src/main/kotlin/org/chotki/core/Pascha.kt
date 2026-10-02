package org.chotki.core

/**
 * Civil date of Orthodox Pascha, and a day's distance from it.
 *
 * Orthocal's pascha distance is what decides the Akathist Fridays. Reading it
 * only from a fetched day meant a Friday a year ahead had no hymn until the
 * network had been asked about that exact day. The distance follows Pascha, and
 * Pascha is the Julian computus, so it can be known without a request.
 *
 * The sign matches orthocal, not "days until the nearest Pascha". From the
 * Sunday of Zacchaeus (77 days before the upcoming Pascha) through Pascha
 * itself the distance is negative, and zero on Pascha. Before that Sunday it
 * is the number of days since the previous Pascha.
 */
object Pascha {

    /** Meeus's Julian computus, then the Julian-to-Gregorian shift for that year. */
    fun civil(year: Int): CalendarDate {
        val a = year % 4
        val b = year % 7
        val c = year % 19
        val d = (19 * c + 15) % 30
        val e = Math.floorMod(2 * a + 4 * b - d + 34, 7)
        val base = d + e + 114
        val month = base / 31
        val day = base % 31 + 1
        val julian = CalendarDate.of(year, month, day)!!
        val century = year / 100
        val shift = century - century / 4 - 2
        return julian.plusDays(shift)
    }

    fun distance(date: CalendarDate): Int {
        val thisYear = civil(date.year)
        val upcoming = if (date <= thisYear) thisYear else civil(date.year + 1)
        val previous = if (date <= thisYear) civil(date.year - 1) else thisYear
        val zacchaeus = upcoming.plusDays(-77)
        return if (date >= zacchaeus) {
            -date.daysUntil(upcoming)
        } else {
            previous.daysUntil(date)
        }
    }
}
