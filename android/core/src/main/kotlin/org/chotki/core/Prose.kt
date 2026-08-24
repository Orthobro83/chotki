package org.chotki.core

/**
 * Turns a set of scores into sentences.
 *
 * This is the part of the report that leads, because "evening prayers slipped
 * twice, both Fridays" tells someone something they can act on, and a percentage
 * does not.
 *
 * The constraints are binding, and tested: nothing is phrased as failure;
 * nothing compares the reader against a target, against other people, or against
 * a better past self; a broken streak is never the subject of a sentence; and
 * standing something down is described neutrally, because it is a legitimate act
 * rather than a lapse.
 */
internal object Prose {

    fun summary(scores: List<RuleScore>): List<String> {
        val live = scores.filter { it.hasAnythingDue }
        if (live.isEmpty()) {
            return listOf("Nothing has come due yet. This fills in as the days pass.")
        }

        val lines = mutableListOf<String>()
        val slipped = live.filter { it.missed > 0 }.sortedByDescending { it.missed }
        val held = live.filter { it.missed == 0 }

        if (slipped.isEmpty()) {
            lines.add(everythingHeld(live))
        } else {
            slipped.take(3).forEach { lines.add(describe(it)) }
            if (slipped.size > 3) {
                lines.add("A few others slipped once or twice as well.")
            }
            if (held.isNotEmpty()) {
                lines.add(
                    if (held.size == 1) "${held[0].title} held throughout." else "Everything else held.",
                )
            }
        }

        lateNote(live)?.let { lines.add(it) }
        stoodDownNote(live)?.let { lines.add(it) }
        return lines
    }

    // MARK: pieces

    private fun everythingHeld(scores: List<RuleScore>): String =
        if (scores.size == 1) {
            "You kept ${lowerFirst(scores[0].title)} every time it came round."
        } else {
            "You kept everything you took on."
        }

    private fun describe(score: RuleScore): String {
        val times = frequency(score.missed)
        val pattern = weekdayPattern(score.missedDates)
        return if (pattern != null) {
            "${score.title} slipped $times, $pattern."
        } else {
            "${score.title} slipped $times."
        }
    }

    /**
     * Only reported when every slip fell on the same weekday and there is more
     * than one — otherwise it is noise dressed as insight.
     */
    private fun weekdayPattern(dates: List<CalendarDate>): String? {
        if (dates.size < 2) return null
        val weekdays = dates.map { it.weekday }.toSet()
        val day = weekdays.singleOrNull() ?: return null
        return "all on ${plural(day)}"
    }

    private fun lateNote(scores: List<RuleScore>): String? {
        val late = scores.sumOf { it.keptLate }
        if (late == 0) return null
        return if (late == 1) {
            "One was kept a little after the day was out, which still counts."
        } else {
            "${capitalisedFirst(count(late))} were kept after the day was out, which still counts."
        }
    }

    /**
     * Neutral by design. Standing a rule down is a legitimate act, so it is
     * reported as a fact about the record and never as something to explain.
     */
    private fun stoodDownNote(scores: List<RuleScore>): String? {
        val total = scores.sumOf { it.stoodDown }
        if (total == 0) return null
        return if (total == 1) {
            "One day was stood down and is not counted either way."
        } else {
            "${capitalisedFirst(count(total))} days were stood down and are not counted either way."
        }
    }

    // MARK: words

    /** "once", "twice", then "three times" and so on. */
    private fun frequency(n: Int): String = when (n) {
        1 -> "once"
        2 -> "twice"
        else -> "${count(n)} times"
    }

    private fun count(n: Int): String {
        val words = listOf(
            "zero", "one", "two", "three", "four", "five",
            "six", "seven", "eight", "nine", "ten",
        )
        return if (n < words.size) words[n] else "$n"
    }

    private fun plural(day: Weekday): String = listOf(
        "Sundays", "Mondays", "Tuesdays", "Wednesdays",
        "Thursdays", "Fridays", "Saturdays",
    )[day.number - 1]

    private fun lowerFirst(text: String): String =
        text.replaceFirstChar { it.lowercase() }

    private fun capitalisedFirst(text: String): String =
        text.replaceFirstChar { it.uppercase() }
}
