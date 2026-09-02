package org.chotki.core.reflections

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.chotki.core.CalendarDate
import org.chotki.core.InstantSerializer
import org.chotki.core.Weekday
import java.time.Instant

/**
 * The journal as a file of its own.
 *
 * The whole record already travels in a backup; this exists because a journal
 * is the part someone most wants to hold as a file they own, separately from
 * the machinery around it. Plain JSON, for the same reason the backup is: what
 * someone wrote should outlive this application.
 *
 * The shape matches the Swift `ReflectionArchive` exactly, so a journal written
 * on a Mac or a phone opens on the other.
 */
@Serializable
data class ReflectionArchive(
    val version: Int = 1,
    @Serializable(with = InstantSerializer::class)
    val exportedAt: Instant = Instant.now(),
    /**
     * The questions as they currently stand. Restored on import only where a
     * weekday has no record yet — an import must not silently rewrite a
     * question the user has since edited.
     */
    val reflections: List<Reflection> = emptyList(),
    val entries: List<ReflectionEntry> = emptyList(),
)

/** What an import did, so the interface can say so rather than going quiet. */
data class ReflectionImportResult(
    /** Written. */
    val added: List<ReflectionEntry>,
    /** Already held, under the same weekday and date. Left alone. */
    val alreadyPresent: Int,
    /**
     * Dropped because two incoming entries claimed the same weekday and date.
     * Only reachable from a `nepsis:v1` file, where two cycle days could be
     * answered on one calendar day.
     */
    val collided: Int,
) {
    val addedCount: Int get() = added.size
}

/** Neither shape could be read. The file is left alone and so is the record. */
class ReflectionImportException : Exception("that file could not be read as a journal")

/**
 * Reading a journal file.
 *
 * Two shapes are accepted: this app's own [ReflectionArchive], and the web
 * artifact's `nepsis:v1`, so that anything already written on the web comes
 * across rather than being retyped.
 */
object ReflectionImport {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    /**
     * The artifact's storage shape. Its `days` are keyed "1"…"7" by position in
     * the cycle, and its entries carry no question, because on the web the
     * seven were fixed and could not be edited.
     */
    @Serializable
    private data class NepsisV1(
        val days: Map<String, List<LegacyEntry>>? = null,
    )

    @Serializable
    private data class LegacyEntry(val date: String, val text: String)

    fun read(text: String, now: Instant = Instant.now()): ReflectionArchive {
        runCatching { json.decodeFromString<ReflectionArchive>(text) }
            .getOrNull()
            ?.let { if (it.entries.isNotEmpty() || it.reflections.isNotEmpty()) return it }

        val legacy = runCatching { json.decodeFromString<NepsisV1>(text) }.getOrNull()
        if (legacy?.days != null) {
            return ReflectionArchive(exportedAt = now, entries = entries(legacy, now))
        }
        throw ReflectionImportException()
    }

    fun write(archive: ReflectionArchive): String = json.encodeToString(archive)

    /**
     * Converts the artifact's shape.
     *
     * **The weekday comes from the date, not from the cycle number.** On the web
     * the seven were a cycle rather than a week — "day 3" was the third prompt,
     * whatever day it was answered on — so an entry's date may fall on any
     * weekday. It is filed under the weekday it was actually written on and
     * keeps the question it actually answered, which is precisely what the
     * snapshot rule is for. Nothing has to be guessed and nothing is lost.
     */
    private fun entries(legacy: NepsisV1, now: Instant): List<ReflectionEntry> {
        val out = mutableListOf<ReflectionEntry>()
        for ((key, written) in legacy.days.orEmpty()) {
            val number = key.toIntOrNull() ?: continue
            if (number !in 1..7) continue
            val question = Reflection.bundled(Weekday.of(number)).question
            for (entry in written) {
                val date = CalendarDate.parse(entry.date) ?: continue
                val text = entry.text.trim()
                if (text.isEmpty()) continue
                out += ReflectionEntry(
                    weekday = date.weekday,
                    date = date,
                    text = text,
                    question = question,
                    writtenAt = now,
                )
            }
        }
        return out.sortedBy { it.date }
    }

    /**
     * What merging an archive into an existing record would do. Never discards
     * — see [ReflectionJournal.merge].
     */
    fun plan(
        archive: ReflectionArchive,
        into: List<ReflectionEntry>,
    ): ReflectionImportResult {
        val seen = into.map { "${it.weekday.number}:${it.date.iso}" }.toMutableSet()
        val added = mutableListOf<ReflectionEntry>()
        var alreadyPresent = 0
        var collided = 0
        for (entry in archive.entries.sortedBy { it.date }) {
            val key = "${entry.weekday.number}:${entry.date.iso}"
            if (!seen.add(key)) {
                if (into.any { it.weekday == entry.weekday && it.date == entry.date }) {
                    alreadyPresent++
                } else {
                    collided++
                }
                continue
            }
            added += entry
        }
        return ReflectionImportResult(added, alreadyPresent, collided)
    }
}
