package org.chotki.core.content

import org.chotki.core.FastingSeason
import org.chotki.core.LiturgicalTrigger
import org.chotki.core.Recurrence
import org.chotki.core.RuleCategory
import org.chotki.core.TimeOfDay
import org.chotki.core.Tradition
import org.chotki.core.Weekday
import org.chotki.core.scheduling.ReminderLead
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * The bundled content, as generated from the Swift core.
 *
 * These counts are the parity gate. If the Swift content changes and the export
 * is not regenerated, its own test fails there; if the export changes shape and
 * this side cannot read it, these fail here. Between them nothing can drift
 * quietly.
 */
class ContentTest {

    @Test
    fun `everything loads and nothing is empty`() {
        assertEquals(111, Content.glossary.size, "glossary entries")
        assertEquals(19, Content.prayers.size, "prayers")
        assertEquals(3, Content.prayerSequences.size, "prayer sequences")
        assertEquals(23, Content.ruleLibrary.size, "library templates")
        assertEquals(36, Content.patristicReadings.size, "patristic readings")
        assertEquals(24, Content.prayerSources.size, "further reading")
    }

    @Test
    fun `identifiers are unique everywhere`() {
        assertEquals(Content.glossary.size, Content.glossary.map { it.slug }.toSet().size)
        assertEquals(Content.prayers.size, Content.prayers.map { it.id }.toSet().size)
        assertEquals(Content.ruleLibrary.size, Content.ruleLibrary.map { it.id }.toSet().size)
        assertEquals(
            Content.patristicReadings.size,
            Content.patristicReadings.map { it.id }.toSet().size,
        )
    }

    // A term whose cross-reference does not resolve is a dead end in the app.
    @Test
    fun `every glossary cross-reference resolves`() {
        val slugs = Content.glossary.map { it.slug }.toSet()
        for (entry in Content.glossary) {
            for (related in entry.related) {
                assertTrue(related in slugs, "${entry.slug} points at $related, which is not there")
            }
        }
    }

    @Test
    fun `every glossary entry is complete`() {
        for (entry in Content.glossary) {
            assertTrue(entry.term.isNotEmpty(), entry.slug)
            assertTrue(entry.short.isNotEmpty(), entry.slug)
            assertTrue(entry.full.isNotEmpty(), entry.slug)
            assertTrue(entry.category.isNotEmpty(), entry.slug)
            entry.modelTraditions // must not throw on an unknown tradition
        }
    }

    @Test
    fun `every prayer has words and a source`() {
        for (prayer in Content.prayers) {
            assertTrue(prayer.title.isNotEmpty(), prayer.id)
            assertTrue(prayer.paragraphs.isNotEmpty(), "${prayer.id} has no words")
            assertTrue(prayer.paragraphs.all { it.isNotBlank() }, prayer.id)
            assertTrue(prayer.source.isNotEmpty(), "${prayer.id} has no attribution")
        }
    }

    // The correction made during the port: Saint Ioannikios closes the evening
    // rule and is said once, so it is not counted on a rope.
    @Test
    fun `the prayers counted on a rope are the short ones`() {
        val onTheRope = Content.prayers.filter { it.isForRope }
        assertEquals(5, onTheRope.size, "rope prayers: ${onTheRope.map { it.id }}")
        assertTrue(onTheRope.all { it.paragraphs.size == 1 }, "a rope prayer is one breath")
        assertTrue(onTheRope.none { it.id == "ioannikios" })
        assertTrue(onTheRope.any { it.id == "jesus-prayer" })
    }

    @Test
    fun `every sequence names prayers that exist, in order`() {
        val ids = Content.prayers.map { it.id }.toSet()
        for (sequence in Content.prayerSequences) {
            assertTrue(sequence.prayerIDs.isNotEmpty(), sequence.id)
            for (id in sequence.prayerIDs) {
                assertTrue(id in ids, "${sequence.id} names $id, which is not a prayer")
            }
        }
        assertTrue(Content.prayerSequences.any { it.id == "morning" })
        assertTrue(Content.prayerSequences.any { it.id == "evening" })
    }

    // MARK: the library, which is the part with structure in it

    @Test
    fun `every template turns into a model without throwing`() {
        for (template in Content.ruleLibrary) {
            template.recurrence.model
            template.modelCategory
            template.modelReminders
            template.modelTraditions
            template.modelTimeOfDay
        }
    }

    @Test
    fun `every recurrence shape survives the wire format`() {
        val shapes = Content.ruleLibrary.map { it.recurrence.model }
        assertTrue(shapes.any { it == Recurrence.Daily })
        assertTrue(shapes.any { it is Recurrence.Weekly })
        assertTrue(shapes.any { it is Recurrence.Monthly })
        assertTrue(shapes.any { it is Recurrence.Liturgical })
    }

    // The mistake this guards: the Wednesday and Friday fast was once written
    // as "any fast day", which put it on roughly 180 days a year.
    @Test
    fun `the Wednesday and Friday fast is a weekly rule, not every fast day`() {
        val fast = Content.ruleLibrary.first { it.id == "wednesday-friday-fast" }
        assertEquals(
            Recurrence.Weekly(setOf(Weekday.WEDNESDAY, Weekday.FRIDAY)),
            fast.recurrence.model,
        )
    }

    @Test
    fun `the fasting seasons keep which season they are`() {
        val expected = mapOf(
            "great-lent" to FastingSeason.GREAT_LENT,
            "nativity-fast" to FastingSeason.NATIVITY_FAST,
            "apostles-fast" to FastingSeason.APOSTLES_FAST,
            "dormition-fast" to FastingSeason.DORMITION_FAST,
        )
        for ((id, season) in expected) {
            val template = Content.ruleLibrary.first { it.id == id }
            assertEquals(
                Recurrence.Liturgical(LiturgicalTrigger.Season(season)),
                template.recurrence.model,
                id,
            )
            assertEquals(RuleCategory.FASTING, template.modelCategory)
        }
    }

    @Test
    fun `templates that carry prayers name prayers that exist`() {
        val ids = Content.prayers.map { it.id }.toSet()
        val withPrayers = Content.ruleLibrary.filter { it.prayerIDs.isNotEmpty() }
        assertTrue(withPrayers.isNotEmpty())
        for (template in withPrayers) {
            for (id in template.prayerIDs) {
                assertTrue(id in ids, "${template.id} names $id, which is not a prayer")
            }
        }
    }

    @Test
    fun `templates point only at glossary terms that exist`() {
        val slugs = Content.glossary.map { it.slug }.toSet()
        for (template in Content.ruleLibrary) {
            for (slug in template.glossarySlugs) {
                assertTrue(slug in slugs, "${template.id} points at $slug, which is not a term")
            }
        }
    }

    @Test
    fun `times of day survive as times`() {
        val timed = Content.ruleLibrary.filter { it.timeOfDay != null }
        assertTrue(timed.isNotEmpty())
        for (template in timed) {
            assertNotNull(template.modelTimeOfDay, "${template.id}: ${template.timeOfDay}")
        }
        val morning = Content.ruleLibrary.first { it.id == "morning-prayers" }
        assertEquals(TimeOfDay.of(6, 30), morning.modelTimeOfDay)
    }

    @Test
    fun `reminder leads survive as leads`() {
        val leads = Content.ruleLibrary.flatMap { it.modelReminders.leads }.toSet()
        assertTrue(leads.isNotEmpty())
        assertTrue(leads.all { it in ReminderLead.entries })
    }

    // MARK: what must never be true of the content

    @Test
    fun `every patristic reading is attributed`() {
        for (reading in Content.patristicReadings) {
            assertTrue(reading.text.isNotEmpty(), reading.id)
            assertTrue(reading.author.isNotEmpty(), "${reading.id} has no author")
            assertTrue(reading.source.isNotEmpty(), "${reading.id} cannot be looked up")
        }
    }

    @Test
    fun `every further-reading link is a real address`() {
        for (source in Content.prayerSources) {
            assertTrue(source.url.startsWith("http"), "${source.title}: ${source.url}")
            assertTrue(source.organisation.isNotEmpty(), source.title)
        }
    }

    @Test
    fun `traditions named in the content are ones the app knows`() {
        val known = Tradition.entries.map { it.name.lowercase() }.toSet()
        val named = (
            Content.glossary.flatMap { it.traditions } +
                Content.prayers.flatMap { it.traditions } +
                Content.ruleLibrary.flatMap { it.traditions }
            ).toSet()
        for (name in named) {
            assertTrue(name.lowercase() in known, "unknown tradition in the content: $name")
        }
    }
}

/** The passage for a day. */
class PatristicReadingsTest {

    private fun d(y: Int, m: Int, day: Int) = org.chotki.core.CalendarDate.of(y, m, day)!!

    @Test
    fun `every day of a year has a reading`() {
        var date = d(2026, 1, 1)
        repeat(365) {
            assertNotNull(PatristicReadings.forDay(date), "no reading for $date")
            date = date.plusDays(1)
        }
    }

    // A reading that shuffled every time it was looked at would be a different
    // thing to read rather than the day's reading.
    @Test
    fun `the same day always gives the same reading`() {
        val once = PatristicReadings.forDay(d(2026, 8, 24))
        val again = PatristicReadings.forDay(d(2026, 8, 24))
        assertEquals(once, again)
    }

    @Test
    fun `consecutive days give consecutive passages`() {
        val first = PatristicReadings.forDay(d(2026, 3, 1))
        val second = PatristicReadings.forDay(d(2026, 3, 2))
        assertTrue(first != second, "two days running gave the same passage")
    }

    // Counted through the months rather than from a fixed offset, so the leap
    // day does not shift the whole year.
    @Test
    fun `the day of the year is counted through the months`() {
        // 1 February is the 32nd day, whatever the year.
        assertEquals(
            PatristicReadings.forDay(d(2026, 2, 1)),
            PatristicReadings.forDay(d(2027, 2, 1)),
        )
    }
}
