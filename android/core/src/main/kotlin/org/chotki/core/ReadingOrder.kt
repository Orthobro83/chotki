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
    /** The daily commemoration of the departed, for the traditions that keep it. */
    const val DEPARTED_BAND = 5
    /** The Akathist, present only on a Friday the Church appoints it. */
    const val AKATHIST_BAND = 6
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
            "akathist" in text -> AKATHIST_BAND
            "departed" in text -> DEPARTED_BAND
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

    /** The heading of a collapsible section on the Reading tab. */
    fun sectionTitle(band: Int, sources: List<String> = emptyList()): String = when (band) {
        0 -> "The day's Gospel"
        1 -> "The day's Epistle"
        2 -> "Vespers"
        SAINT_LIFE_BAND -> "The life of the day's saint"
        DEPARTED_BAND -> "Prayer for the departed"
        AKATHIST_BAND -> "The Akathist to the Theotokos"
        else -> if (sources.isNotEmpty() && sources.all { "matins" in it.lowercase() }) "Matins"
        else "The other readings"
    }

    /**
     * Where a section's header sits in the reading list.
     *
     * Item 0 is the day's heading. Each scripture band is then a header, and,
     * when that band is expanded, its readings plus the marker at the end of
     * them. The saint's life is the header after those bands. Returns -1 when
     * the band is not on the page.
     */
    /**
     * [trailing] are the sections after the scripture, in order. Each is one
     * header, and, when expanded, a body and the marker at the end of it.
     */
    fun headerIndex(
        band: Int,
        scripture: List<Pair<Int, Int>>,
        expanded: Set<Int>,
        trailing: List<Int> = listOf(SAINT_LIFE_BAND),
    ): Int {
        var index = 1
        for ((key, count) in scripture) {
            if (key == band) return index
            index += 1
            if (key in expanded) index += count + 1
        }
        for (key in trailing) {
            if (key == band) return index
            index += 1
            if (key in expanded) index += 2
        }
        return -1
    }
}
