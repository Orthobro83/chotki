package org.chotki.core.reflections

import kotlinx.serialization.Serializable
import org.chotki.core.CalendarDate
import org.chotki.core.Weekday

/**
 * A slice of the record by year and month.
 *
 * The date list grows without limit — seven a week, and the point of the
 * feature is years — so it is scoped rather than paged. Null means "all", which
 * is why both fields are nullable rather than defaulted to the current year.
 */
@Serializable
data class ReflectionPeriod(
    /** Null means every year. */
    val year: Int? = null,
    /** Null means every month. 1–12. */
    val month: Int? = null,
) {
    fun contains(date: CalendarDate): Boolean {
        if (year != null && date.year != year) return false
        if (month != null && date.month != month) return false
        return true
    }

    val isAll: Boolean get() = year == null && month == null

    companion object {
        val ALL = ReflectionPeriod()
    }
}

/**
 * One weekday's answers, newest first, already scoped to a period.
 *
 * This exists so stepping is a decision in core with tests rather than
 * arithmetic in a view. The direction is the part that is easy to get backwards
 * — entries are newest first, so *older* means a **higher** index — and it was
 * in fact got backwards once on macOS before this type existed.
 */
data class ReflectionSeries(
    val weekday: Weekday,
    /** Newest first. */
    val entries: List<ReflectionEntry>,
    val period: ReflectionPeriod = ReflectionPeriod.ALL,
) {
    val count: Int get() = entries.size
    val isEmpty: Boolean get() = entries.isEmpty()

    fun entry(index: Int): ReflectionEntry? = entries.getOrNull(index)

    fun indexOf(date: CalendarDate): Int? =
        entries.indexOfFirst { it.date == date }.takeIf { it >= 0 }

    /**
     * One step back in time, or null at the far end.
     *
     * Returning null rather than wrapping is deliberate: the control disables
     * at the ends. Wrapping from the oldest entry to the newest would make a
     * journal feel like a carousel.
     */
    fun older(than: Int): Int? = (than + 1).takeIf { it in entries.indices }

    /** One step forward in time, or null at the near end. */
    fun newer(than: Int): Int? = (than - 1).takeIf { it in entries.indices }

    /** "2 of 3", one-based, for display. Null when empty. */
    fun position(index: Int): Position? =
        if (index in entries.indices) Position(index + 1, entries.size) else null

    data class Position(val ordinal: Int, val total: Int)
}

/**
 * What the record says. Every question the section asks of the data is answered
 * here rather than in a view.
 */
object ReflectionJournal {

    /** One weekday's entries, newest first, scoped to a period. */
    fun series(
        all: List<ReflectionEntry>,
        on: Weekday,
        period: ReflectionPeriod = ReflectionPeriod.ALL,
    ): ReflectionSeries = ReflectionSeries(
        weekday = on,
        entries = all
            .filter { it.weekday == on && period.contains(it.date) }
            .sortedByDescending { it.date },
        period = period,
    )

    /**
     * The most recent answer to a weekday, whenever it was written.
     *
     * Deliberately unscoped by period: this answers "when did I last write this
     * one", which a filter should not be able to change.
     */
    fun mostRecent(all: List<ReflectionEntry>, on: Weekday): ReflectionEntry? =
        series(all, on).entries.firstOrNull()

    /**
     * Whether a date already carries an answer. An answer locks on save, so
     * this is what stops a second being offered for the same day.
     */
    fun hasEntry(all: List<ReflectionEntry>, on: CalendarDate): Boolean =
        all.any { it.date == on && it.weekday == on.weekday }

    /**
     * Every year with an answer, newest first. Feeds the period control, so
     * years with nothing in them are never offered.
     */
    fun years(all: List<ReflectionEntry>, on: Weekday? = null): List<Int> =
        (if (on == null) all else all.filter { it.weekday == on })
            .map { it.date.year }.distinct().sortedDescending()

    /** Every month with an answer in a given year, in calendar order. */
    fun months(all: List<ReflectionEntry>, on: Weekday? = null, year: Int): List<Int> =
        (if (on == null) all else all.filter { it.weekday == on })
            .filter { it.date.year == year }
            .map { it.date.month }.distinct().sorted()

    /**
     * Merge on import. **Never discards.**
     *
     * Keyed by weekday and date, which is the same key the store makes unique.
     * What is already here wins on a collision: an import is additive, and a
     * file from a stale export must never be able to overwrite an answer
     * written since. This is the rule the web version learned first and it has
     * not changed.
     */
    fun merge(
        existing: List<ReflectionEntry>,
        incoming: List<ReflectionEntry>,
    ): List<ReflectionEntry> {
        val held = existing.map(::key).toMutableSet()
        val added = mutableListOf<ReflectionEntry>()
        for (entry in incoming) {
            if (!held.add(key(entry))) continue
            added += entry
        }
        return added.sortedBy { it.date }
    }

    private fun key(entry: ReflectionEntry): String = "${entry.weekday.number}:${entry.date.iso}"
}
