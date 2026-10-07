package org.chotki.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive

/**
 * A run of verses in one chapter of one book, [first] through [last].
 *
 * Books use the USFX three-letter codes Orthocal itself uses ("MAT", "1KI"). On disk a run is the
 * array `[book, chapter, first, last]`. Ported from `ScriptureText.swift`.
 */
data class PassageRun(val book: String, val chapter: Int, val first: Int, val last: Int) {
    companion object {
        fun from(element: JsonElement): PassageRun {
            val parts = element.jsonArray
            return PassageRun(
                parts[0].jsonPrimitive.content, parts[1].jsonPrimitive.int,
                parts[2].jsonPrimitive.int, parts[3].jsonPrimitive.int,
            )
        }
    }
}

/**
 * The words of scripture the app shows, and how verses become paragraphs.
 *
 * **Where the text comes from.** One King James Version (with the Apocrypha), public domain, from
 * eBible.org, shipped in `calendar/kjv.json`. A day in the bundled calendar stores only *which
 * verses* each reading is, and they are resolved here. So the licence audit is one file, and
 * nothing Orthocal serves as prose is trusted: its Composite readings carry a translation that is
 * not ours to show, and are resolved from the verses their titles cite instead.
 *
 * **Paragraphs.** The Bible marks which verses open a paragraph. A blank line is put before such a
 * verse, and before any verse that does not follow on from the one before it (separate passages
 * must not run together); otherwise verses are joined by a single space. The first verse never
 * gets one. The same rule as the Swift core and the bundle builder, held to each other by a digest.
 */
object ScriptureText {

    data class Verse(
        val book: String,
        val chapter: Int,
        val verse: Int,
        val text: String,
        val opensParagraph: Boolean,
    )

    /** The paragraph break, a blank line. */
    const val PARAGRAPH_BREAK = "\n\n"

    private fun follows(previous: Verse, next: Verse): Boolean {
        if (previous.book != next.book) return false
        if (previous.chapter == next.chapter) return next.verse == previous.verse + 1
        return next.chapter == previous.chapter + 1 && next.verse == 1
    }

    /** Verses to text, by the paragraph rule above. */
    fun join(verses: List<Verse>): String {
        val out = StringBuilder()
        var previous: Verse? = null
        for (verse in verses) {
            if (previous != null) {
                out.append(if (verse.opensParagraph || !follows(previous, verse)) PARAGRAPH_BREAK else " ")
            }
            out.append(verse.text)
            previous = verse
        }
        return out.toString()
    }

    /**
     * The text of the runs, resolved from the bundled Bible. Null when any verse is not in it:
     * better no text than the wrong text.
     */
    fun text(runs: List<PassageRun>): String? {
        val verses = mutableListOf<Verse>()
        for (run in runs) {
            if (run.first > run.last) continue
            for (number in run.first..run.last) {
                verses += Bible.verse(run.book, run.chapter, number) ?: return null
            }
        }
        return if (verses.isEmpty()) null else join(verses)
    }

    /** The runs a Composite reading's title cites, or null for any other reading. */
    fun composite(display: String): List<PassageRun>? = Bible.composites[display]

    /**
     * A day read back from the cache may carry Composite text from an older build of the app,
     * which fetched it from the network as served. Replace it.
     */
    fun sanitised(day: LiturgicalDay): LiturgicalDay {
        if (day.readings.none { composite(it.display) != null }) return day
        return day.copy(
            readings = day.readings.map { reading ->
                val runs = composite(reading.display) ?: return@map reading
                reading.copy(text = text(runs) ?: "")
            },
        )
    }

    // MARK: the bundled Bible

    @Serializable
    private class Chapter(val v: List<String?>, val p: List<Int>)

    object Bible {
        private val json = Json { ignoreUnknownKeys = true }

        private fun resource(name: String): String =
            ScriptureText::class.java.getResourceAsStream("/calendar/$name")
                ?.bufferedReader(Charsets.UTF_8)?.readText()
                // A missing resource is a build fault, not a runtime condition.
                ?: error("bundled calendar file missing: $name")

        /** book -> chapters, where index 0 is chapter 1. */
        private val books: Map<String, List<Chapter>> by lazy {
            json.decodeFromString<Map<String, List<Chapter>>>(resource("kjv.json"))
        }
        private val openers: Map<String, List<Set<Int>>> by lazy {
            books.mapValues { (_, chapters) -> chapters.map { it.p.toSet() } }
        }

        val composites: Map<String, List<PassageRun>> by lazy {
            val table = json.parseToJsonElement(resource("composites.json")) as JsonObject
            table.mapValues { (_, runs) -> runs.jsonArray.map(PassageRun::from) }
        }

        fun verse(book: String, chapter: Int, verse: Int): Verse? {
            val chapters = books[book] ?: return null
            if (chapter < 1 || chapter > chapters.size) return null
            val entry = chapters[chapter - 1]
            if (verse < 1 || verse > entry.v.size) return null
            val text = entry.v[verse - 1] ?: return null
            return Verse(book, chapter, verse, text, openers[book]?.get(chapter - 1)?.contains(verse) ?: false)
        }

        val verseCount: Int get() = books.values.sumOf { chapters -> chapters.sumOf { c -> c.v.count { it != null } } }
    }
}
