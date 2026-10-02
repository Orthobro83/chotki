package org.chotki.core

import org.chotki.core.content.Content
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class AkathistTest {
    @Test
    fun `Pascha's distance matches the church calendar, including 16 April 2027`() {
        assertEquals(CalendarDate.of(2026, 4, 12), Pascha.civil(2026))
        assertEquals(CalendarDate.of(2027, 5, 2), Pascha.civil(2027))
        assertEquals(0, Pascha.distance(d(2026, 4, 12)))
        assertEquals(1, Pascha.distance(d(2026, 4, 13)))
        assertEquals(263, Pascha.distance(d(2026, 12, 31)))
        assertEquals(264, Pascha.distance(d(2027, 1, 1)))
        assertEquals(304, Pascha.distance(d(2027, 2, 10)))
        assertEquals(307, Pascha.distance(d(2027, 2, 13)))
        assertEquals(-77, Pascha.distance(d(2027, 2, 14)))
        assertEquals(-16, Pascha.distance(d(2027, 4, 16)))
        assertEquals(0, Pascha.distance(d(2027, 5, 2)))
        assertEquals(5, Akathist.week(Pascha.distance(d(2027, 4, 16)), Tradition.GEORGIAN))
    }

    private fun d(year: Int, month: Int, day: Int) = CalendarDate.of(year, month, day)!!

    @Test
    fun `the fifth Friday is the whole hymn for every tradition`() {
        for (tradition in Tradition.entries) {
            assertEquals(5, Akathist.week(-16, tradition))
        }
    }

    @Test
    fun `the first four Fridays are Greek and Antiochian only`() {
        for (distance in listOf(-44, -37, -30, -23)) {
            assertTrue(Akathist.week(distance, Tradition.GREEK) != null)
            assertTrue(Akathist.week(distance, Tradition.ANTIOCHIAN) != null)
            assertNull(Akathist.week(distance, Tradition.RUSSIAN))
            assertNull(Akathist.week(distance, Tradition.SERBIAN))
            assertNull(Akathist.week(distance, Tradition.BULGARIAN))
            assertNull(Akathist.week(distance, Tradition.ROMANIAN))
            assertNull(Akathist.week(distance, Tradition.GEORGIAN))
        }
        assertEquals(1, Akathist.week(-44, Tradition.GREEK))
        assertNull(Akathist.week(-15, Tradition.GREEK))
        assertNull(Akathist.week(-9, Tradition.GREEK))
    }

    @Test
    fun `a church without its own appointment is shown the OCA's and says so`() {
        val note = "This is how the Orthodox Church in America keeps it: the whole hymn, on Friday of the fifth week of Great Lent."
        val romanian = Akathist.fallbackNote(Tradition.ROMANIAN)
        val georgian = Akathist.fallbackNote(Tradition.GEORGIAN)
        assertTrue(romanian!!.contains(note))
        assertTrue(romanian.contains("Romanian Orthodox Church"))
        assertTrue(georgian!!.contains("Georgian Orthodox Church"))
        for (tradition in listOf(
            Tradition.GREEK, Tradition.ANTIOCHIAN, Tradition.RUSSIAN,
            Tradition.SERBIAN, Tradition.BULGARIAN,
        )) {
            assertTrue(Akathist.hasOwnAppointment(tradition))
            assertNull(Akathist.fallbackNote(tradition))
        }
        assertEquals(5, Akathist.week(-16, Tradition.ROMANIAN))
        assertNull(Akathist.week(-44, Tradition.GEORGIAN))
    }

    @Test
    fun `the hymn is the twenty-four stanzas, framed by the kontakion`() {
        assertEquals(24, Content.appointed.akathist.stanzas.size)
        val first = Akathist.paragraphs(1)
        assertEquals(8, first.size)
        assertEquals(Content.appointed.akathist.kontakion, first.first())
        assertEquals(Content.appointed.akathist.kontakion, first.last())
        assertTrue(first[1].startsWith("An Angel, and the chiefest"))
        val whole = Akathist.paragraphs(5)
        assertEquals(28, whole.size)
        assertTrue(Content.appointed.akathist.again in whole)
    }

    @Test
    fun `the departed prayer is kept, and spiritual reading is not a rule`() {
        assertTrue(Content.ruleLibrary.none { it.id == "spiritual-reading" })
        assertTrue(Content.glossary.any { it.slug == "spiritual-reading" })
        val meals = Content.ruleLibrary.first { it.id == "prayer-before-meals" }
        assertEquals(listOf("our-father", "table-blessing"), meals.prayerIDs)
        val blessing = Content.prayers.first { it.id == "table-blessing" }
        assertEquals(
            "Christ our God, bless this meat and drink to Thy servants.",
            blessing.paragraphs.last(),
        )
        val departed = Content.ruleLibrary.first { it.id == "prayer-for-the-departed" }
        assertEquals("daily", departed.recurrence.kind)
        assertEquals(3, Content.appointed.departed.paragraphs.size)
    }
}
