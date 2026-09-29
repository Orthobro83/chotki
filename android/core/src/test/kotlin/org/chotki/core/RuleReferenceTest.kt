package org.chotki.core

import org.chotki.core.content.Content
import org.chotki.core.content.model
import org.chotki.core.content.modelCategory
import org.chotki.core.content.modelTimeOfDay
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The Kotlin half of `RuleReferenceTests` in the Swift core.
 *
 * Both sides decide this in core precisely so the two cannot disagree, and a
 * rule decided in two places is a rule decided twice. These tests exist to
 * fail on the day one side drifts.
 */
class RuleReferenceTest {

    private val library: List<Rule> = Content.ruleLibrary.map { template ->
        Rule(
            title = template.title,
            recurrence = template.recurrence.model,
            timeOfDay = template.modelTimeOfDay,
            category = template.modelCategory,
            prayerIDs = template.prayerIDs.ifEmpty { null },
        )
    }

    @Test
    fun `a rule whose whole text is one counted prayer leads to the rope`() {
        val jesus = library.first { it.title == "The Jesus Prayer" }
        assertEquals(RuleReference.ROPE, jesus.reference)
        assertEquals("jesus-prayer", jesus.ropePrayerId)
    }

    @Test
    fun `a rule read straight through leads to its prayers, not the rope`() {
        val morning = library.first { it.title == "Morning prayers" }
        assertEquals(RuleReference.PRAYERS, morning.reference)
        assertNull(morning.ropePrayerId, "eleven prayers are read, not counted")
    }

    @Test
    fun `every rope rule names a prayer the rope can actually count`() {
        val onTheRope = library.filter { it.reference == RuleReference.ROPE }
        assertTrue(onTheRope.isNotEmpty(), "no rope rules, so this proves nothing")
        for (rule in onTheRope) {
            val id = rule.ropePrayerId
            assertNotNull(id, "${rule.title} leads to the rope with no prayer")
            val prayer = Content.prayers.firstOrNull { it.id == id }
            assertNotNull(prayer, "${rule.title} names a prayer that is not in the book")
            assertTrue(prayer.isForRope, "${rule.title} sends a read-through prayer to the rope")
        }
    }

    @Test
    fun `every rule taken from the library can be looked up`() {
        val mute = library.filter { it.glossarySlug == null }.map { it.title }
        assertTrue(mute.isEmpty(), "nothing to open: ${mute.joinToString()}")
    }

    @Test
    fun `the curated entry wins over anything the title happens to contain`() {
        assertEquals("great-lent", library.first { it.title == "Great Lent" }.glossarySlug)
    }

    @Test
    fun `a renamed rule is still recognised by what its name contains`() {
        val renamed = Rule(title = "The Jesus Prayer, 33 repetitions", recurrence = Recurrence.Daily)
        assertEquals("jesus-prayer", renamed.glossarySlug)
        val own = Rule(title = "Cold plunge", recurrence = Recurrence.Daily)
        assertNull(own.glossarySlug, "a rule of one's own stays the person's own")
    }
}
