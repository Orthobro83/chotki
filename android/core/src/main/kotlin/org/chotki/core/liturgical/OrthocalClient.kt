package org.chotki.core.liturgical

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import org.chotki.core.CalendarDate
import org.chotki.core.LiturgicalDay
import org.chotki.core.Reading
import org.chotki.core.Reckoning
import org.chotki.core.ScriptureText
import java.time.Instant

/**
 * Wire format of orthocal.info. Field names are the API's, not ours — note
 * `fast_level_desc` alongside `feast_level_description`, which is why these are
 * spelled out one by one rather than left to a naming strategy.
 */
@Serializable
private data class OrthocalResponse(
    val year: Int,
    val month: Int,
    val day: Int,
    val tone: Int? = null,
    val titles: List<String>? = null,
    @SerialName("summary_title") val summaryTitle: String? = null,
    val saints: List<String>? = null,
    val feasts: List<String>? = null,
    @SerialName("feast_level") val feastLevel: Int,
    @SerialName("feast_level_description") val feastLevelDescription: String,
    @SerialName("fast_level") val fastLevel: Int,
    @SerialName("fast_level_desc") val fastLevelDesc: String,
    @SerialName("fast_exception") val fastException: Int,
    @SerialName("fast_exception_desc") val fastExceptionDesc: String? = null,
    @SerialName("fast_abstentions") val fastAbstentions: List<String>? = null,
    @SerialName("pascha_distance") val paschaDistance: Int,
    val readings: List<ResponseReading>? = null,
) {
    @Serializable
    data class ResponseReading(
        val source: String,
        val display: String,
        @SerialName("short_display") val shortDisplay: String,
        val passage: List<Verse>? = null,
    ) {
        /**
         * Orthocal's keyed verses carry numbers; its Composite readings carry strings, and an
         * empty book. Either is read as a number where it is one.
         */
        @Serializable
        data class Verse(
            val content: String? = null,
            val book: String? = null,
            val chapter: JsonPrimitive? = null,
            val verse: JsonPrimitive? = null,
            @SerialName("paragraph_start") val paragraphStart: Boolean? = null,
        )

        /**
         * What this reading says, as the app will show it.
         *
         * Orthocal's Composite readings are not the KJV: they carry a translation that is not ours
         * to show, so they are never read from the network. A known one is resolved from the verses
         * its title cites; an unknown one (a composite added upstream since) has no text rather
         * than text we have not audited. Every other reading is keyed KJV, joined into paragraphs
         * by the same rule as the bundle.
         */
        val text: String
            get() {
                ScriptureText.composite(display)?.let { return ScriptureText.text(it) ?: "" }
                if (display.startsWith("Composite")) return ""
                val verses = mutableListOf<ScriptureText.Verse>()
                for (verse in passage ?: emptyList()) {
                    val content = verse.content ?: return ""
                    val book = verse.book?.takeIf { it.isNotEmpty() } ?: return ""
                    val chapter = verse.chapter?.content?.toIntOrNull() ?: return ""
                    val number = verse.verse?.content?.toIntOrNull() ?: return ""
                    verses += ScriptureText.Verse(book, chapter, number, content, verse.paragraphStart ?: false)
                }
                return ScriptureText.join(verses)
            }
    }
}

class OrthocalClient(
    private val http: HttpFetching,
    private val host: String = DEFAULT_HOST,
) {
    companion object {
        const val DEFAULT_HOST = "https://orthocal.info"

        private val json = Json { ignoreUnknownKeys = true }

        internal fun decode(
            body: String,
            civilDate: CalendarDate,
            reckoning: Reckoning,
            now: Instant,
        ): LiturgicalDay {
            val raw = json.decodeFromString<OrthocalResponse>(body)

            // Falls back to the civil date if the payload is malformed rather
            // than failing the whole day — the reported date is data, not the
            // key.
            val observed = CalendarDate.of(raw.year, raw.month, raw.day) ?: civilDate

            return LiturgicalDay(
                civilDate = civilDate,
                reckoning = reckoning,
                observedDate = observed,
                tone = raw.tone,
                title = raw.titles?.firstOrNull(),
                summaryTitle = raw.summaryTitle ?: "",
                saints = raw.saints ?: emptyList(),
                feasts = raw.feasts ?: emptyList(),
                fastLevel = raw.fastLevel,
                fastLevelDescription = raw.fastLevelDesc,
                fastException = raw.fastException,
                fastExceptionDescription = raw.fastExceptionDesc?.ifEmpty { null },
                abstentions = raw.fastAbstentions ?: emptyList(),
                feastLevel = raw.feastLevel,
                feastLevelDescription = raw.feastLevelDescription,
                readings = (raw.readings ?: emptyList()).map {
                    Reading(it.source, it.display, it.shortDisplay, it.text)
                },
                paschaDistance = raw.paschaDistance,
                fetchedAt = now,
            )
        }
    }

    /**
     * The URL takes a **civil** date. The response reports the date in the
     * requested reckoning, which is why the caller keeps the civil date as the
     * key.
     */
    fun url(date: CalendarDate, reckoning: Reckoning): String =
        "$host/api/${reckoning.endpointPath}/${date.year}/${date.month}/${date.day}/"

    fun day(date: CalendarDate, reckoning: Reckoning, now: Instant = Instant.now()): LiturgicalDay =
        decode(http.data(url(date, reckoning)), date, reckoning, now)
}
