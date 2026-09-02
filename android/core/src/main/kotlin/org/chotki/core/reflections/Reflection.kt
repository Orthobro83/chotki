package org.chotki.core.reflections

import kotlinx.serialization.Serializable
import org.chotki.core.CalendarDate
import org.chotki.core.InstantSerializer
import org.chotki.core.UuidSerializer
import org.chotki.core.Weekday
import java.time.Instant
import java.util.UUID

/**
 * The wording of a reflection, held as one value so that "the question as it
 * stood" is a copy rather than a description of one.
 *
 * [Reflection] carries this, and so does every [ReflectionEntry]. That is the
 * snapshot rule made structural: an entry cannot accidentally point at the live
 * question, because it has no way to refer to one. Editing Sunday's wording
 * therefore cannot reach backwards into what was already written — which would
 * otherwise leave every past answer answering a question that was never asked.
 *
 * **Do not translate this as a foreign key to `reflection`.** It looks tidier
 * and it is wrong; the bug would not show until someone edited a question, and
 * then it would be silent and retroactive.
 */
@Serializable
data class ReflectionQuestion(
    val title: String,
    /** What to attend to during the day. */
    val notice: String,
    /**
     * What to write at the end of it.
     *
     * Six of the seven begin "At the end of the day, write down…". The text is
     * the Brotherhood's and is not reworded, so an interface must not label
     * this with words that say the same thing again.
     */
    val task: String,
)

/**
 * One weekday's reflection.
 *
 * There is exactly one per weekday and there always will be: [weekday] is the
 * identity, not a field. Reflections are never added and never removed — only
 * rewritten — so there is no archived state and no ordering within a day.
 */
@Serializable
data class Reflection(
    val weekday: Weekday,
    val question: ReflectionQuestion,
    /**
     * Set the first time the wording is changed from what it shipped with.
     * Null means untouched since installation.
     */
    @Serializable(with = InstantSerializer::class)
    val editedAt: Instant? = null,
) {
    val title: String get() = question.title
    val notice: String get() = question.notice
    val task: String get() = question.task

    val isEdited: Boolean get() = editedAt != null

    /**
     * A rewrite of this reflection, stamped.
     *
     * Answers already written are untouched by construction — they hold their
     * own copy of the question — so this needs no cascade and must not have one.
     */
    fun rewritten(question: ReflectionQuestion, at: Instant = Instant.now()): Reflection =
        copy(question = question, editedAt = at)

    /**
     * True when the wording has been returned to what it shipped with, whatever
     * [editedAt] says. A question about the words rather than about the history.
     */
    val matchesBundled: Boolean get() = question == bundled(weekday).question

    companion object
}

/**
 * One answer, on one date, to one weekday's reflection.
 *
 * Every field is a `val`. An answer locks on save — it cannot be edited or
 * deleted afterwards — and making the type immutable means the interface cannot
 * offer that by accident. Do not add a `var` for a builder's convenience.
 */
@Serializable
data class ReflectionEntry(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    val weekday: Weekday,
    val date: CalendarDate,
    val text: String,
    /** The question as it stood when this was written. See [ReflectionQuestion]. */
    val question: ReflectionQuestion,
    @Serializable(with = InstantSerializer::class)
    val writtenAt: Instant = Instant.now(),
) {
    companion object {
        /**
         * An answer to the reflection as it currently stands, on a given day.
         *
         * The weekday comes from the date rather than being passed in, so an
         * answer cannot be filed under a weekday its date does not fall on.
         */
        fun answering(
            reflection: Reflection,
            on: CalendarDate,
            text: String,
            id: UUID = UUID.randomUUID(),
            writtenAt: Instant = Instant.now(),
        ): ReflectionEntry = ReflectionEntry(
            id = id,
            weekday = on.weekday,
            date = on,
            text = text,
            question = reflection.question,
            writtenAt = writtenAt,
        )
    }
}
