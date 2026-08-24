package org.chotki.core

import kotlinx.serialization.Serializable
import java.time.Instant

@Serializable
data class Reading(
    val source: String,
    val display: String,
    val shortDisplay: String,
    val text: String,
)

/**
 * One day of the church calendar, cached.
 *
 * Keyed by **civil** date and reckoning. The API takes a civil date in the URL
 * but reports the date in the requested reckoning in the body — asking for 13
 * January 2027 on the Julian endpoint answers with 31 December 2026. Keying the
 * cache on the reported date would misfile every Old Calendar day by thirteen
 * days, so [civilDate] is the key and [observedDate] is data.
 */
@Serializable
data class LiturgicalDay(
    val civilDate: CalendarDate,
    val reckoning: Reckoning,
    val observedDate: CalendarDate,

    val tone: Int? = null,
    val title: String? = null,
    val summaryTitle: String = "",
    val saints: List<String> = emptyList(),
    val feasts: List<String> = emptyList(),

    val fastLevel: Int,
    val fastLevelDescription: String,
    val fastException: Int,
    val fastExceptionDescription: String? = null,
    val abstentions: List<String> = emptyList(),

    val feastLevel: Int,
    val feastLevelDescription: String,

    val readings: List<Reading> = emptyList(),
    val paschaDistance: Int,
    @Serializable(with = InstantSerializer::class)
    val fetchedAt: Instant,
) {
    /**
     * orthocal fast levels: 0 none, 1 Wednesday/Friday, 2 Great Lent,
     * 3 Apostles, 4 Dormition, 5 Nativity.
     */
    val isFast: Boolean get() = fastLevel > 0

    /**
     * Exception 11 is "Fast Free". Other exceptions relax a fast rather than
     * lifting it — a feast falling on a fast day may allow fish, wine and oil.
     */
    val isFastFree: Boolean get() = fastException == 11

    /**
     * Feast levels 7 and 8 are the Major Feasts of the Theotokos and of the
     * Lord — the Twelve Great Feasts and Pascha. Lower levels are ranked days
     * rather than Great Feasts.
     */
    val isGreatFeast: Boolean get() = feastLevel >= 7

    val season: FastingSeason?
        get() = when (fastLevel) {
            2 -> FastingSeason.GREAT_LENT
            3 -> FastingSeason.APOSTLES_FAST
            4 -> FastingSeason.DORMITION_FAST
            5 -> FastingSeason.NATIVITY_FAST
            else -> null
        }

    /**
     * Why a fast that would otherwise fall today is not kept.
     *
     * The Church lifts the Wednesday and Friday fast in four stretches of the
     * year. A rule that simply vanished on those days would look broken and
     * teach nothing, so the day is still shown — kept, with the reason.
     *
     * Identified from the calendar's own data rather than by computing dates:
     * Bright Week names itself, and the others sit at fixed distances from
     * Pascha or on fixed old-style dates.
     */
    val fastFreeReason: String?
        get() {
            if (isFast && !isFastFree) return null
            if (!isFastFree && fastLevel != 0) return null

            if (title.orEmpty().startsWith("Bright") || summaryTitle.startsWith("Bright")) {
                return "Bright Week"
            }
            if (paschaDistance in 50..56) return "the week after Pentecost"
            if (paschaDistance in -70..-64) return "the week of the Publican and the Pharisee"
            // Old-style 25 December to 5 January: the days between the feasts.
            if ((observedDate.month == 12 && observedDate.day >= 25) ||
                (observedDate.month == 1 && observedDate.day <= 5)
            ) {
                return "the days between the Nativity and Theophany"
            }
            return "a fast-free day"
        }

    /**
     * Wording matters: this describes what the church calendar marks, it does
     * not instruct anyone what to eat.
     */
    val fastDescription: String
        get() {
            if (!isFast) return fastExceptionDescription ?: fastLevelDescription
            val exception = fastExceptionDescription
            return if (!exception.isNullOrEmpty()) {
                "$fastLevelDescription — $exception"
            } else {
                fastLevelDescription
            }
        }

    fun isStale(asOf: Instant, maxAgeSeconds: Long = 60L * 60 * 24 * 30): Boolean =
        asOf.epochSecond - fetchedAt.epochSecond > maxAgeSeconds
}
