package org.chotki.core.content

import org.chotki.core.Weekday

/**
 * The Psalter's twenty divisions, and which are appointed on a given day.
 *
 * A direct translation of the Swift `Kathisma`, and held to it by
 * `KathismaParityTest`. Septuagint numbering, which is what the Orthodox
 * Psalter uses. Psalm 151 belongs to no kathisma.
 *
 * **Divisions:** Metropolitan Cantor Institute, *The Kathismata of the
 * Psalter*, https://mci.archpitt.org/liturgy/Kathismata.html
 *
 * **The daily order:** Fr John Whiteford, *Order of Reading the Kathismata of
 * the Psalter*, St Jonah Orthodox Church,
 * https://www.saintjonah.org/rub/kathismata.htm — Russian usage.
 */
object Kathisma {

    data class Division(val kathisma: Int, val first: Int, val last: Int)

    val divisions: List<Division> = listOf(
        Division(1, 1, 8), Division(2, 9, 16), Division(3, 17, 23),
        Division(4, 24, 31), Division(5, 32, 36), Division(6, 37, 45),
        Division(7, 46, 54), Division(8, 55, 63), Division(9, 64, 69),
        Division(10, 70, 76), Division(11, 77, 84), Division(12, 85, 90),
        Division(13, 91, 100), Division(14, 101, 104), Division(15, 105, 108),
        Division(16, 109, 117), Division(17, 118, 118), Division(18, 119, 133),
        Division(19, 134, 142), Division(20, 143, 150),
    )

    fun psalms(kathisma: Int): IntRange? =
        divisions.firstOrNull { it.kathisma == kathisma }?.let { it.first..it.last }

    enum class Service(val displayName: String) {
        MATINS("Matins"),
        FIRST_HOUR("First Hour"),
        THIRD_HOUR("Third Hour"),
        SIXTH_HOUR("Sixth Hour"),
        NINTH_HOUR("Ninth Hour"),
        VESPERS("Vespers"),
    }

    enum class Season { ORDINARY, GREAT_LENT, FIFTH_WEEK_OF_LENT, HOLY_WEEK, BRIGHT_WEEK }

    data class Appointed(val service: Service, val kathismata: List<Int>)

    /** Sunday first, matching `Weekday.number - 1`. */
    private val ordinary: List<Map<Service, List<Int>>> = listOf(
        mapOf(Service.MATINS to listOf(2, 3)),
        mapOf(Service.MATINS to listOf(4, 5), Service.VESPERS to listOf(6)),
        mapOf(Service.MATINS to listOf(7, 8), Service.VESPERS to listOf(9)),
        mapOf(Service.MATINS to listOf(10, 11), Service.VESPERS to listOf(12)),
        mapOf(Service.MATINS to listOf(13, 14), Service.VESPERS to listOf(15)),
        mapOf(Service.MATINS to listOf(19, 20), Service.VESPERS to listOf(18)),
        mapOf(Service.MATINS to listOf(16, 17), Service.VESPERS to listOf(1)),
    )

    private val lent: List<Map<Service, List<Int>>> = listOf(
        mapOf(Service.MATINS to listOf(2, 3)),
        mapOf(
            Service.MATINS to listOf(4, 5, 6), Service.FIRST_HOUR to listOf(7),
            Service.THIRD_HOUR to listOf(8), Service.SIXTH_HOUR to listOf(9),
            Service.VESPERS to listOf(18),
        ),
        mapOf(
            Service.MATINS to listOf(10, 11, 12), Service.FIRST_HOUR to listOf(13),
            Service.THIRD_HOUR to listOf(14), Service.SIXTH_HOUR to listOf(15),
            Service.NINTH_HOUR to listOf(16), Service.VESPERS to listOf(18),
        ),
        mapOf(
            Service.MATINS to listOf(19, 20, 1), Service.FIRST_HOUR to listOf(2),
            Service.THIRD_HOUR to listOf(3), Service.SIXTH_HOUR to listOf(4),
            Service.NINTH_HOUR to listOf(5), Service.VESPERS to listOf(18),
        ),
        mapOf(
            Service.MATINS to listOf(6, 7, 8), Service.FIRST_HOUR to listOf(9),
            Service.THIRD_HOUR to listOf(10), Service.SIXTH_HOUR to listOf(11),
            Service.NINTH_HOUR to listOf(12), Service.VESPERS to listOf(18),
        ),
        mapOf(
            Service.MATINS to listOf(13, 14, 15), Service.THIRD_HOUR to listOf(19),
            Service.SIXTH_HOUR to listOf(20), Service.VESPERS to listOf(18),
        ),
        mapOf(Service.MATINS to listOf(16, 17), Service.VESPERS to listOf(1)),
    )

    private val fifthWeek: List<Map<Service, List<Int>>> = listOf(
        mapOf(Service.MATINS to listOf(2, 3)),
        mapOf(
            Service.MATINS to listOf(4, 5, 6), Service.FIRST_HOUR to listOf(7),
            Service.THIRD_HOUR to listOf(8), Service.SIXTH_HOUR to listOf(9),
            Service.NINTH_HOUR to listOf(10),
        ),
        mapOf(
            Service.MATINS to listOf(11, 12, 13), Service.FIRST_HOUR to listOf(14),
            Service.THIRD_HOUR to listOf(15), Service.SIXTH_HOUR to listOf(16),
            Service.NINTH_HOUR to listOf(18), Service.VESPERS to listOf(19),
        ),
        mapOf(
            Service.MATINS to listOf(20, 1, 2), Service.FIRST_HOUR to listOf(3),
            Service.THIRD_HOUR to listOf(4), Service.SIXTH_HOUR to listOf(5),
            Service.NINTH_HOUR to listOf(6), Service.VESPERS to listOf(7),
        ),
        mapOf(
            Service.MATINS to listOf(8), Service.THIRD_HOUR to listOf(9),
            Service.SIXTH_HOUR to listOf(10), Service.NINTH_HOUR to listOf(11),
            Service.VESPERS to listOf(12),
        ),
        mapOf(
            Service.MATINS to listOf(13, 14, 15), Service.THIRD_HOUR to listOf(19),
            Service.SIXTH_HOUR to listOf(20), Service.VESPERS to listOf(18),
        ),
        mapOf(Service.MATINS to listOf(16, 17), Service.VESPERS to listOf(1)),
    )

    private val holyWeek: List<Map<Service, List<Int>>> = listOf(
        mapOf(Service.MATINS to listOf(2, 3)),
        mapOf(
            Service.MATINS to listOf(4, 5, 6), Service.THIRD_HOUR to listOf(7),
            Service.SIXTH_HOUR to listOf(8), Service.VESPERS to listOf(18),
        ),
        mapOf(
            Service.MATINS to listOf(9, 10, 11), Service.THIRD_HOUR to listOf(12),
            Service.SIXTH_HOUR to listOf(13), Service.VESPERS to listOf(18),
        ),
        mapOf(
            Service.MATINS to listOf(14, 15, 16), Service.THIRD_HOUR to listOf(19),
            Service.SIXTH_HOUR to listOf(20), Service.VESPERS to listOf(18),
        ),
        emptyMap(),
        emptyMap(),
        mapOf(Service.MATINS to listOf(17)),
    )

    /**
     * Clean Monday is 48 days before Pascha and Great Lent runs to the Friday
     * before Lazarus Saturday. Lazarus Saturday and Palm Sunday sit between
     * Lent and Holy Week and keep the ordinary order.
     */
    fun season(paschaDistance: Int): Season = when (paschaDistance) {
        in 0..6 -> Season.BRIGHT_WEEK
        in -6..-1 -> Season.HOLY_WEEK
        in -20..-14 -> Season.FIFTH_WEEK_OF_LENT
        in -48..-9 -> Season.GREAT_LENT
        else -> Season.ORDINARY
    }

    fun appointed(weekday: Weekday, season: Season): List<Appointed> {
        val table = when (season) {
            Season.BRIGHT_WEEK -> return emptyList()
            Season.ORDINARY -> ordinary
            Season.GREAT_LENT -> lent
            Season.FIFTH_WEEK_OF_LENT -> fifthWeek
            Season.HOLY_WEEK -> holyWeek
        }
        val row = table[weekday.number - 1]
        return Service.entries.mapNotNull { service ->
            row[service]?.takeIf { it.isNotEmpty() }?.let { Appointed(service, it) }
        }
    }

    /** Every kathisma appointed on a day, in order and without repeats. */
    fun onTheDay(weekday: Weekday, season: Season): List<Int> =
        appointed(weekday, season).flatMap { it.kathismata }.distinct()
}
