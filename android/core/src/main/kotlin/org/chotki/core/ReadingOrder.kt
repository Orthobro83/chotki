package org.chotki.core

/**
 * How the day's readings are laid out.
 *
 * What the person has taken on comes first. Within each of those two bands the
 * order is Gospels, then Epistles, then Vespers, then everything else — Matins
 * included, so a Matins Gospel is not filed with the day's Gospel.
 */
object ReadingOrder {
    const val SAINT_LIFE_BAND = 4
    fun band(source: String): Int {
        val text = source.lowercase()
        if ("matins" in text) return 3
        if ("gospel" in text) return 0
        if ("epistle" in text) return 1
        if ("vespers" in text) return 2
        return 3
    }

    /** Which band a rule covers, or null when it is not a reading of one. */
    fun bandOfTitle(title: String): Int? {
        val text = title.lowercase()
        return when {
            "life of the day" in text && "saint" in text -> SAINT_LIFE_BAND
            "epistle" in text -> 1
            "vespers" in text -> 2
            "matins" in text -> 3
            "gospel" in text -> 0
            else -> null
        }
    }

    fun <T> sorted(readings: List<T>, source: (T) -> String, onRule: (T) -> Boolean): List<T> =
        readings.sortedWith(compareBy({ if (onRule(it)) 0 else 1 }, { band(source(it)) }))
}
