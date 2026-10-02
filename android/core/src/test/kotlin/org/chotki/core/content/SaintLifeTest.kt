package org.chotki.core.content

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SaintLifeTest {
    @Test
    fun `every church day is stored, and the two calendars stay distinct`() {
        assertEquals(365, Content.saintLives.size)
        assertEquals(365, Content.saintLives.map { it.month * 100 + it.day }.toSet().size)
        assertEquals(null, Content.saintLife(2, 29))

        val boniface = Content.saintLife(12, 19)!!
        assertEquals("December 19 / January 1", boniface.dates)
        assertEquals(1, boniface.gregorianMonth)
        assertEquals(1, boniface.gregorianDay)
        assertEquals("https://app.ochrid.com/prologue?day=01-01", boniface.sourceURL)
        assertEquals("CC BY-SA 4.0", boniface.license)
        assertTrue(boniface.licenseNote.contains("The text is unchanged."))
        val opening = boniface.sections.first().blocks.first { it.kind == "prose" }.spans!!.first().text
        assertTrue(opening.startsWith("Martyrdom for Christ makes a saint out of a sinner."))

        val circumcision = Content.saintLife(1, 1)!!
        assertEquals("January 1 / January 14", circumcision.dates)
        assertEquals(14, circumcision.gregorianDay)
        assertTrue(circumcision.sections.first().heading == "Lives of the Saints")

    }
}
