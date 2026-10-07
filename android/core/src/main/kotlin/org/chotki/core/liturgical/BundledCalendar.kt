package org.chotki.core.liturgical

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.chotki.core.CalendarDate
import org.chotki.core.LiturgicalDay
import org.chotki.core.PassageRun
import org.chotki.core.Reading
import org.chotki.core.Reckoning
import org.chotki.core.ScriptureText
import java.time.Instant

/**
 * The church calendar that ships with the app, read-only. Ported from `BundledCalendar.swift`;
 * the files are byte-for-byte the Swift core's, and a Swift test fails if they drift.
 *
 * Generated once from Orthocal's own open-source code (`core/Tools/calendar-bundle.py`), audited
 * so that every word of scripture is public-domain KJV, and stored as one file per
 * reckoning-year. Days are decoded when first asked for and kept; nothing is written to the
 * person's record, so there is no schema change and no migration.
 *
 * A day answers from here before the cache or the network is consulted. The network is a refill
 * for dates past [last], and nothing more.
 */
class BundledCalendar private constructor(
    val manifest: Manifest,
    val first: CalendarDate,
    val last: CalendarDate,
    private val strings: List<String>,
    private val fetchedAt: Instant,
    private val load: (String) -> ByteArray?,
) {
    @Serializable
    data class Manifest(
        val schema: Int,
        val tradition: String,
        val first: String,
        val last: String,
        val generatedAt: String,
        val orthocalCommit: String,
        val textDigest: String,
        /** A digest of every field of every day except reading text, built from the audited source. */
        val fieldsDigest: String,
        val files: List<String>,
    )

    private val years = mutableMapOf<String, List<LiturgicalDay>>()

    fun covers(date: CalendarDate): Boolean = date >= first && date <= last

    fun day(civil: CalendarDate, reckoning: Reckoning): LiturgicalDay? {
        if (!covers(civil)) return null
        val days = year(civil.year, reckoning)
        val start = CalendarDate.of(civil.year, 1, 1) ?: return null
        return days.getOrNull(start.daysUntil(civil))
    }

    private fun stem(reckoning: Reckoning) = when (reckoning) {
        Reckoning.JULIAN -> "julian"
        Reckoning.REVISED_JULIAN -> "revisedJulian"
    }

    @Synchronized
    private fun year(year: Int, reckoning: Reckoning): List<LiturgicalDay> {
        val name = "${stem(reckoning)}-$year"
        years[name]?.let { return it }
        val data = load("$name.json")
        val start = CalendarDate.of(year, 1, 1)
        if (data == null || start == null) { years[name] = emptyList(); return emptyList() }
        val file = json.parseToJsonElement(data.toString(Charsets.UTF_8)).jsonObject
        val decoded = file.getValue("days").jsonArray.mapIndexedNotNull { offset, element ->
            record(element.jsonObject, start.plusDays(offset), reckoning)
        }
        years[name] = decoded
        return decoded
    }

    private fun record(r: JsonObject, civil: CalendarDate, reckoning: Reckoning): LiturgicalDay? {
        val o = r.getValue("o").jsonArray
        if (o.size != 3) return null
        val observed = CalendarDate.of(o[0].jsonPrimitive.int, o[1].jsonPrimitive.int, o[2].jsonPrimitive.int) ?: return null
        fun str(key: String) = strings[r.getValue(key).jsonPrimitive.int]
        fun optStr(key: String) = r[key]?.takeIf { it !is JsonNull }?.let { strings[it.jsonPrimitive.int] }
        fun list(key: String) = r.getValue(key).jsonArray.map { strings[it.jsonPrimitive.int] }
        fun optInt(key: String) = r[key]?.takeIf { it !is JsonNull }?.jsonPrimitive?.intOrNull
        return LiturgicalDay(
            civilDate = civil, reckoning = reckoning, observedDate = observed,
            tone = optInt("t"), title = optStr("ti"), summaryTitle = str("su"),
            saints = list("sa"), feasts = list("fe"),
            fastLevel = r.getValue("fl").jsonPrimitive.int, fastLevelDescription = str("fd"),
            fastException = r.getValue("fx").jsonPrimitive.int, fastExceptionDescription = optStr("fxd"),
            abstentions = list("ab"),
            feastLevel = r.getValue("el").jsonPrimitive.int, feastLevelDescription = str("ed"),
            readings = r.getValue("r").jsonArray.map { e ->
                val entry = e.jsonObject
                val runs = entry.getValue("r").jsonArray.map(PassageRun::from)
                Reading(
                    source = strings[entry.getValue("s").jsonPrimitive.int],
                    display = strings[entry.getValue("d").jsonPrimitive.int],
                    shortDisplay = strings[entry.getValue("h").jsonPrimitive.int],
                    text = ScriptureText.text(runs) ?: "",
                )
            },
            paschaDistance = r.getValue("pd").jsonPrimitive.int,
            fetchedAt = fetchedAt,
        )
    }

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        /** The calendar in the core resources. Null only if the bundle is damaged. */
        val standard: BundledCalendar? by lazy {
            create { name -> BundledCalendar::class.java.getResourceAsStream("/calendar/$name")?.use { it.readBytes() } }
        }

        /** `load` returns the bytes of a named file ("manifest.json", "julian-2027.json", ...). */
        fun create(load: (String) -> ByteArray?): BundledCalendar? {
            val manifest = runCatching {
                json.decodeFromString<Manifest>(load("manifest.json")!!.toString(Charsets.UTF_8))
            }.getOrNull() ?: return null
            if (manifest.schema != 1) return null
            val first = CalendarDate.parse(manifest.first) ?: return null
            val last = CalendarDate.parse(manifest.last) ?: return null
            val stamp = CalendarDate.parse(manifest.generatedAt) ?: return null
            val strings = runCatching {
                json.parseToJsonElement(load("strings.json")!!.toString(Charsets.UTF_8)).jsonArray.map { it.jsonPrimitive.content }
            }.getOrNull() ?: return null
            val fetchedAt = java.time.LocalDate.of(stamp.year, stamp.month, stamp.day)
                .atStartOfDay(java.time.ZoneOffset.UTC).toInstant()
            return BundledCalendar(manifest, first, last, strings, fetchedAt, load)
        }
    }
}
