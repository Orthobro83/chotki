package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ReadingOrderTest {
    @Test
    fun `gospels then epistles then vespers then matins, and a rule comes first`() {
        val readings = listOf(
            "Matins Gospel",
            "Vespers",
            "Epistle",
            "Gospel",
            "Vespers",
        )
        val ordered = ReadingOrder.sorted(readings, { it }, { it == "Gospel" })
        assertEquals(
            listOf("Gospel", "Epistle", "Vespers", "Vespers", "Matins Gospel"),
            ordered,
        )
    }

    @Test
    fun `a matins gospel is not the day's gospel`() {
        assertEquals(3, ReadingOrder.band("Matins Gospel"))
        assertEquals(0, ReadingOrder.band("Gospel"))
        assertEquals(0, ReadingOrder.bandOfTitle("The day's Gospel"))
        assertEquals(4, ReadingOrder.bandOfTitle("The life of the day's saint"))
        assertNull(ReadingOrder.bandOfTitle("Morning prayers"))
    }

    @Test
    fun `a section header sits after the heading and any open sections before it`() {
        val scripture = listOf(0 to 2, 1 to 1)
        assertEquals(1, ReadingOrder.headerIndex(0, scripture, emptySet()))
        assertEquals(2, ReadingOrder.headerIndex(1, scripture, emptySet()))
        assertEquals(3, ReadingOrder.headerIndex(ReadingOrder.SAINT_LIFE_BAND, scripture, emptySet()))
        // Gospel open: its header, two readings, and the end marker, then the Epistle.
        assertEquals(5, ReadingOrder.headerIndex(1, scripture, setOf(0)))
        assertEquals(-1, ReadingOrder.headerIndex(2, scripture, emptySet()))
    }
}

class SpiritualFatherPromptTest {
    @Test
    fun `the question waits thirty days, and a name or a deferral puts it off`() {
        val start = CalendarDate.of(2026, 8, 19)!!
        val settings = AppSettings(
            hasCompletedFirstRun = true,
            firstRunOn = start,
        )
        assertFalse(settings.shouldAskForSpiritualFather(start.plusDays(29)))
        assertTrue(settings.shouldAskForSpiritualFather(start.plusDays(30)))
        assertFalse(
            settings.copy(spiritualFatherName = "Fr. Peter")
                .shouldAskForSpiritualFather(start.plusDays(40)),
        )
        val deferred = settings.copy(spiritualFatherDeferredOn = start.plusDays(30))
        assertFalse(deferred.shouldAskForSpiritualFather(start.plusDays(30)))
        assertTrue(deferred.shouldAskForSpiritualFather(start.plusDays(60)))
        assertFalse(AppSettings().shouldAskForSpiritualFather(start))
    }
}
