package org.chotki.core.content

import org.chotki.core.Weekday
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The Psalter and its divisions, held to the Swift core.
 *
 * The tables are transcribed from a source rather than worked out, so these
 * check the arithmetic the Typikon itself guarantees — a slip in one row shows
 * up as a psalm read twice in a week or not at all — and that Kotlin says
 * exactly what Swift says.
 */
class KathismaTest {

    @Test fun `the twenty divisions cover psalms 1 to 150 exactly once`() {
        val covered = Kathisma.divisions.flatMap { (it.first..it.last).toList() }
        assertEquals(150, covered.size)
        assertEquals((1..150).toSet(), covered.toSet())
        assertEquals((1..20).toList(), Kathisma.divisions.map { it.kathisma })
    }

    @Test fun `psalm 151 belongs to no kathisma`() {
        assertTrue(Kathisma.divisions.all { it.last < 151 })
    }

    @Test fun `the ordinary week reads all twenty, once each`() {
        val read = Weekday.entries.flatMap { Kathisma.onTheDay(it, Kathisma.Season.ORDINARY) }
        assertEquals((1..20).toList(), read.sorted())
    }

    /**
     * Twice over, but for the Amomos — Psalm 118, read at Saturday Matins — and
     * the Songs of Ascents, read at Vespers every lenten weekday.
     */
    @Test fun `a lenten week reads the Psalter twice, but for the Amomos and the Ascents`() {
        val counts = Weekday.entries
            .flatMap { Kathisma.onTheDay(it, Kathisma.Season.GREAT_LENT) }
            .groupingBy { it }.eachCount()

        assertEquals((1..20).toSet(), counts.keys)
        assertEquals(1, counts[17])
        assertEquals(5, counts[18])
        for (kathisma in (1..20).filter { it != 17 && it != 18 }) {
            assertEquals(2, counts[kathisma], "the ${kathisma}th")
        }
    }

    @Test fun `nothing is read in Bright Week`() {
        assertTrue(Weekday.entries.all { Kathisma.onTheDay(it, Kathisma.Season.BRIGHT_WEEK).isEmpty() })
    }

    @Test fun `the seasons fall where they should around Pascha`() {
        assertEquals(Kathisma.Season.BRIGHT_WEEK, Kathisma.season(0))
        assertEquals(Kathisma.Season.BRIGHT_WEEK, Kathisma.season(6))
        assertEquals(Kathisma.Season.ORDINARY, Kathisma.season(7))
        assertEquals(Kathisma.Season.HOLY_WEEK, Kathisma.season(-1))
        assertEquals(Kathisma.Season.HOLY_WEEK, Kathisma.season(-6))
        assertEquals(Kathisma.Season.ORDINARY, Kathisma.season(-7))
        assertEquals(Kathisma.Season.ORDINARY, Kathisma.season(-8))
        assertEquals(Kathisma.Season.GREAT_LENT, Kathisma.season(-9))
        assertEquals(Kathisma.Season.FIFTH_WEEK_OF_LENT, Kathisma.season(-14))
        assertEquals(Kathisma.Season.FIFTH_WEEK_OF_LENT, Kathisma.season(-20))
        assertEquals(Kathisma.Season.GREAT_LENT, Kathisma.season(-21))
        assertEquals(Kathisma.Season.GREAT_LENT, Kathisma.season(-48))
        assertEquals(Kathisma.Season.ORDINARY, Kathisma.season(-49))
    }

    // MARK: the Psalter itself

    @Test fun `all hundred and fifty-one are there`() {
        assertEquals(151, Psalter.all.size)
        assertEquals((1..151).toList(), Psalter.all.map { it.number })
        assertTrue(Psalter.all.all { it.verses.isNotEmpty() })
    }

    @Test fun `no markup survived the move`() {
        for (psalm in Psalter.all) {
            for (verse in psalm.verses) {
                assertTrue("\\" !in verse.text, "psalm ${psalm.number}:${verse.number}")
                assertTrue("  " !in verse.text, "psalm ${psalm.number}:${verse.number}")
            }
        }
    }

    @Test fun `the superscriptions came off the body`() {
        val third = Psalter.psalm(3)!!
        assertEquals(
            "A Psalm of David, when he fled from the presence of his son Abessalom.",
            third.superscription,
        )
        assertEquals("2", third.verses.first().number)

        // Psalm 50's title runs to two verses, so its body begins at three.
        val fiftieth = Psalter.psalm(50)!!
        assertTrue(fiftieth.superscription!!.startsWith("For the end, a Psalm of David, when Nathan"))
        assertEquals("3", fiftieth.verses.first().number)
        assertTrue(fiftieth.verses.first().text.startsWith("Have mercy upon me, O God"))

        assertEquals(null, Psalter.psalm(1)!!.superscription)
    }

    @Test fun `the kathismata resolve to real psalms`() {
        for (number in 1..20) {
            val psalms = Psalter.kathisma(number)
            assertTrue(psalms.isNotEmpty(), "the ${number}th is empty")
            assertEquals(Kathisma.psalms(number)!!.count(), psalms.size, "the ${number}th")
        }
        assertEquals(listOf(118), Psalter.kathisma(17).map { it.number })
        assertEquals(175, Psalter.kathisma(17).first().verses.size)
    }

    @Test fun `the source is named, so the wording can be checked`() {
        assertTrue("Brenton" in Psalter.source)
        assertTrue("1851" in Psalter.source)
        assertTrue(Psalter.sourceUrl.startsWith("https://"))
    }
}
