package org.chotki.core.reflections

import org.chotki.core.CalendarDate
import org.chotki.core.REFLECTION_RULE_TITLE
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.RuleReference
import org.chotki.core.Weekday
import org.chotki.core.content.Content
import org.chotki.core.content.model
import org.chotki.core.content.modelTimeOfDay
import org.chotki.core.reference
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int): CalendarDate = CalendarDate.of(y, m, day)!!

private fun q(title: String) = ReflectionQuestion(title, "notice $title", "task $title")

/**
 * September 2026 begins on a Tuesday, so its Sundays are the 6th, 13th, 20th
 * and 27th. The same dates the Swift suite uses, so a failure here and a
 * failure there are the same failure.
 */
private fun sundays(days: List<Int>, text: (Int) -> String = { "answer $it" }) =
    days.map { day ->
        val date = d(2026, 9, day)
        ReflectionEntry(
            weekday = date.weekday, date = date, text = text(day),
            question = q("Notice the Resistance"),
        )
    }

class ReflectionContentTest {

    @Test fun `there is exactly one for every weekday`() {
        assertEquals(7, Reflection.bundled.size)
        assertEquals(Weekday.entries.toSet(), Reflection.bundled.map { it.weekday }.toSet())
    }

    @Test fun `they are in weekday order, Sunday first`() {
        assertEquals(Weekday.entries.toList(), Reflection.bundled.map { it.weekday })
        assertEquals(Weekday.SUNDAY, Reflection.bundled.first().weekday)
        assertEquals(Weekday.SATURDAY, Reflection.bundled.last().weekday)
    }

    /**
     * The titles are the Brotherhood's; the mapping to weekdays was Ryan's
     * instruction — the first is Sunday, running through to Saturday.
     */
    @Test fun `the titles land on the weekdays they were given for`() {
        assertEquals("Notice the Resistance", Reflection.bundled(Weekday.SUNDAY).title)
        assertEquals("Notice the Quiet", Reflection.bundled(Weekday.MONDAY).title)
        assertEquals("Notice the Comfort", Reflection.bundled(Weekday.TUESDAY).title)
        assertEquals("Notice the Avoidance", Reflection.bundled(Weekday.WEDNESDAY).title)
        assertEquals("Notice the Pattern", Reflection.bundled(Weekday.THURSDAY).title)
        assertEquals("Notice the Cost", Reflection.bundled(Weekday.FRIDAY).title)
        assertEquals("Bring It Forward", Reflection.bundled(Weekday.SATURDAY).title)
    }

    @Test fun `every one carries both halves, and none is a placeholder`() {
        for (reflection in Reflection.bundled) {
            assertTrue(reflection.title.isNotEmpty())
            assertTrue(reflection.notice.length > 40, "${reflection.weekday} notice looks like a stub")
            assertTrue(reflection.task.length > 30, "${reflection.weekday} task looks like a stub")
            assertFalse(reflection.notice.lowercase().contains("placeholder"))
        }
    }

    /**
     * Saturday's directs the reader to liturgy and confession. If that is ever
     * lost the section quietly stops being what it was for.
     */
    @Test fun `Saturday still points to liturgy and confession`() {
        val saturday = Reflection.bundled(Weekday.SATURDAY).notice.lowercase()
        assertTrue(saturday.contains("confession"))
        assertTrue(saturday.contains("liturgy"))
    }

    @Test fun `nothing shipped is marked as edited`() {
        for (reflection in Reflection.bundled) {
            assertNull(reflection.editedAt)
            assertFalse(reflection.isEdited)
            assertTrue(reflection.matchesBundled)
        }
    }

    /**
     * The text crosses as generated JSON rather than being retyped. If the
     * resource is ever hand-edited this is what notices.
     */
    @Test fun `the fixed copy came across whole`() {
        assertEquals(2, Reflection.closingText.size)
        assertTrue(Reflection.closingText[0].startsWith("If this week showed you something"))
        assertTrue(Reflection.closingText[1].contains("Take what you noticed to your priest"))

        assertEquals(3, Reflection.explainer.size)
        val whole = Reflection.explainer.flatMap { it.spans }.joinToString("") { it.text }
        assertTrue(whole.contains("reflect on aspects of your spiritual life"))
        assertFalse(whole.contains("aspect of your"), "the singular was corrected")

        val linked = Reflection.explainer.flatMap { it.spans }.filter { it.url != null }
        assertEquals(1, linked.size)
        assertEquals("Brotherhood of the Narrow Path", linked.first().text)
        assertEquals(Content.welcome.let { "https://www.skool.com/fathermoses/" }, linked.first().url)

        assertEquals("Add this as a daily rule", Reflection.addAsRuleLabel)
        assertTrue(whole.contains("\"${Reflection.addAsRuleLabel}\""))
        assertTrue(Reflection.libraryNote.contains("Click on the Reflections tab to learn more."))
    }
}

class ReflectionRewriteTest {

    @Test fun `a rewrite is stamped and no longer matches what shipped`() {
        val now = Instant.now()
        val sunday = Reflection.bundled(Weekday.SUNDAY)
        val after = sunday.rewritten(q("Something of my own"), now)

        assertEquals(Weekday.SUNDAY, after.weekday)
        assertEquals("Something of my own", after.title)
        assertEquals(now, after.editedAt)
        assertTrue(after.isEdited)
        assertFalse(after.matchesBundled)
    }

    /**
     * The snapshot rule, and the one that matters most: it is what stops a past
     * answer from silently answering a question that was never asked.
     */
    @Test fun `rewriting the question cannot reach an answer already written`() {
        val sunday = Reflection.bundled(Weekday.SUNDAY)
        val entry = ReflectionEntry.answering(sunday, d(2026, 9, 6), "what I saw")

        sunday.rewritten(q("Rewritten"))

        assertEquals(sunday.question, entry.question)
        assertEquals("Notice the Resistance", entry.question.title)
    }

    @Test fun `returning the wording by hand matches what shipped again`() {
        val sunday = Reflection.bundled(Weekday.SUNDAY)
        val back = sunday.rewritten(q("elsewhere")).rewritten(sunday.question)

        assertTrue(back.matchesBundled)
        // The stamp survives even though the words match again: whether it was
        // touched is a different question from whether it differs.
        assertTrue(back.isEdited)
    }
}

class ReflectionEntryTest {

    @Test fun `it takes its weekday from its date, so it cannot be misfiled`() {
        val sunday = ReflectionEntry.answering(
            Reflection.bundled(Weekday.SUNDAY), d(2026, 9, 6), "x")
        assertEquals(Weekday.SUNDAY, sunday.weekday)

        // Answering Sunday's question on a Wednesday files it under Wednesday
        // and keeps Sunday's wording. That is the snapshot doing its job rather
        // than a bug: what was answered is recorded, and so is when.
        val strayed = ReflectionEntry.answering(
            Reflection.bundled(Weekday.SUNDAY), d(2026, 9, 9), "x")
        assertEquals(Weekday.WEDNESDAY, strayed.weekday)
        assertEquals("Notice the Resistance", strayed.question.title)
    }
}

class ReflectionPeriodTest {

    @Test fun `all of it contains everything`() {
        assertTrue(ReflectionPeriod.ALL.isAll)
        assertTrue(ReflectionPeriod.ALL.contains(d(1999, 1, 1)))
    }

    @Test fun `a year on its own takes every month in it`() {
        val period = ReflectionPeriod(year = 2026)
        assertTrue(period.contains(d(2026, 1, 1)))
        assertTrue(period.contains(d(2026, 12, 31)))
        assertFalse(period.contains(d(2025, 12, 31)))
        assertFalse(period.isAll)
    }

    @Test fun `a month on its own takes that month in every year`() {
        val period = ReflectionPeriod(month = 9)
        assertTrue(period.contains(d(2026, 9, 6)))
        assertTrue(period.contains(d(2019, 9, 30)))
        assertFalse(period.contains(d(2026, 8, 31)))
    }

    @Test fun `both together take one month of one year`() {
        val period = ReflectionPeriod(year = 2026, month = 9)
        assertTrue(period.contains(d(2026, 9, 1)))
        assertFalse(period.contains(d(2026, 8, 31)))
        assertFalse(period.contains(d(2025, 9, 1)))
    }
}

class ReflectionSeriesTest {

    private val series = ReflectionJournal.series(sundays(listOf(6, 13, 20)), Weekday.SUNDAY)

    @Test fun `newest first`() {
        assertEquals(listOf(20, 13, 6), series.entries.map { it.date.day })
        assertEquals(3, series.count)
    }

    /**
     * The direction is the part that is easy to get backwards, and was got
     * backwards once on macOS before this type existed. Entries are newest
     * first, so older means a **higher** index.
     */
    @Test fun `the older step walks back in time`() {
        assertEquals(1, series.older(0))
        assertEquals(13, series.entry(series.older(0)!!)?.date?.day)
        assertEquals(2, series.older(1))
        assertEquals(6, series.entry(series.older(1)!!)?.date?.day)
    }

    @Test fun `the newer step walks forward in time`() {
        assertEquals(1, series.newer(2))
        assertEquals(0, series.newer(1))
        assertEquals(20, series.entry(series.newer(1)!!)?.date?.day)
    }

    /** Wrapping would make a journal feel like a carousel. */
    @Test fun `it stops at both ends rather than wrapping`() {
        assertNull(series.newer(0))
        assertNull(series.older(2))
    }

    @Test fun `position reads one-based`() {
        assertEquals(1, series.position(0)?.ordinal)
        assertEquals(3, series.position(0)?.total)
        assertEquals(3, series.position(2)?.ordinal)
        assertNull(series.position(3))
    }

    @Test fun `an empty series has no position and no steps`() {
        val none = ReflectionJournal.series(emptyList(), Weekday.SUNDAY)
        assertTrue(none.isEmpty)
        assertNull(none.position(0))
        assertNull(none.older(0))
        assertNull(none.newer(0))
        assertNull(none.entry(0))
    }

    @Test fun `a date can be found in it`() {
        assertEquals(1, series.indexOf(d(2026, 9, 13)))
        assertNull(series.indexOf(d(2026, 9, 7)))
    }
}

class ReflectionJournalTest {

    @Test fun `a weekday's series holds only that weekday`() {
        val wednesday = d(2026, 9, 9)
        val all = sundays(listOf(6, 13)) + ReflectionEntry(
            weekday = wednesday.weekday, date = wednesday, text = "w",
            question = q("Notice the Avoidance"))

        assertEquals(2, ReflectionJournal.series(all, Weekday.SUNDAY).count)
        assertEquals(1, ReflectionJournal.series(all, Weekday.WEDNESDAY).count)
        assertTrue(ReflectionJournal.series(all, Weekday.FRIDAY).isEmpty)
    }

    @Test fun `a period scopes the series`() {
        val august = d(2026, 8, 30)
        val all = sundays(listOf(6, 13)) + ReflectionEntry(
            weekday = august.weekday, date = august, text = "august", question = q("t"))

        assertEquals(3, ReflectionJournal.series(all, Weekday.SUNDAY).count)
        assertEquals(2, ReflectionJournal.series(all, Weekday.SUNDAY, ReflectionPeriod(month = 9)).count)
        assertEquals(1, ReflectionJournal.series(all, Weekday.SUNDAY, ReflectionPeriod(month = 8)).count)
        assertTrue(ReflectionJournal.series(all, Weekday.SUNDAY, ReflectionPeriod(year = 2025)).isEmpty)
    }

    /**
     * "When did I last write this one" is a question about the record, not
     * about the filter, so a period must not be able to change the answer.
     */
    @Test fun `the most recent answer ignores the period entirely`() {
        val all = sundays(listOf(6, 13, 20))
        assertEquals(20, ReflectionJournal.mostRecent(all, Weekday.SUNDAY)?.date?.day)
        assertNull(ReflectionJournal.mostRecent(emptyList(), Weekday.SUNDAY))
    }

    @Test fun `a date already answered is known to be answered`() {
        val all = sundays(listOf(6, 13))
        assertTrue(ReflectionJournal.hasEntry(all, d(2026, 9, 6)))
        assertFalse(ReflectionJournal.hasEntry(all, d(2026, 9, 20)))
    }

    @Test fun `only years and months that hold something are offered`() {
        val extra = listOf(Triple(2025, 11, 16), Triple(2026, 7, 26)).map { (y, m, day) ->
            val date = d(y, m, day)
            ReflectionEntry(weekday = date.weekday, date = date, text = "x", question = q("t"))
        }
        val all = sundays(listOf(6, 13)) + extra

        assertEquals(listOf(2026, 2025), ReflectionJournal.years(all))
        assertEquals(listOf(7, 9), ReflectionJournal.months(all, year = 2026))
        assertEquals(listOf(11), ReflectionJournal.months(all, year = 2025))
        assertEquals(emptyList(), ReflectionJournal.months(all, year = 2024))
    }
}

class ReflectionMergeTest {

    /**
     * The rule the web version learned first: an import is additive. A file
     * from a stale export must never overwrite an answer written since.
     */
    @Test fun `what is already held always wins`() {
        val existing = sundays(listOf(6, 13)) { "mine $it" }
        val incoming = sundays(listOf(6, 20)) { "theirs $it" }

        val added = ReflectionJournal.merge(existing, incoming)
        assertEquals(1, added.size)
        assertEquals(20, added.first().date.day)
        assertEquals("theirs 20", added.first().text)
    }

    @Test fun `importing the same file twice adds nothing the second time`() {
        val existing = sundays(listOf(6))
        val incoming = sundays(listOf(6, 13))

        val first = ReflectionJournal.merge(existing, incoming)
        assertEquals(1, first.size)
        assertTrue(ReflectionJournal.merge(existing + first, incoming).isEmpty())
    }

    @Test fun `nothing incoming leaves the record alone`() {
        assertTrue(ReflectionJournal.merge(sundays(listOf(6)), emptyList()).isEmpty())
    }
}

class ReflectionRuleTest {

    private val template = Content.ruleLibrary.first { it.id == "reflection" }

    /** One entry, not seven. Seven near-identical rows was noise. */
    @Test fun `there is exactly one library entry, called Reflection`() {
        assertEquals("Reflection", template.title)
        assertEquals(REFLECTION_RULE_TITLE, template.title)
        assertTrue(Content.ruleLibrary.none { it.id.startsWith("reflection-") })
    }

    /** "All seven days, recurring" is one rule that recurs every day. */
    @Test fun `it recurs every day and does not ring`() {
        assertEquals(Recurrence.Daily, template.recurrence.model)
        assertNull(template.modelTimeOfDay)
    }

    @Test fun `its note is short and points at the section`() {
        assertEquals(Reflection.libraryNote, template.note)
        assertTrue(template.note!!.contains("Click on the Reflections tab to learn more."))
    }

    /**
     * The row has to offer a way through to the section, on every surface.
     * Deciding it in core is what stops one platform having the link and the
     * others not.
     */
    @Test fun `a rule of this title points at Reflections`() {
        val rule = Rule(title = REFLECTION_RULE_TITLE, recurrence = Recurrence.Daily)
        assertEquals(RuleReference.REFLECTIONS, rule.reference)
    }

    /** Rename it and it becomes an ordinary rule again. */
    @Test fun `a renamed copy is his rule, not this one`() {
        val renamed = Rule(title = "My own reflections", recurrence = Recurrence.Daily)
        assertEquals(RuleReference.NONE, renamed.reference)
    }
}
