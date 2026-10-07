package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** Translated from Swift's "The link back to today". */
class TodayLinkTest {
    private fun date(y: Int, m: Int, d: Int) = CalendarDate.of(y, m, d)!!
    private val today = date(2026, 10, 6)

    @Test
    fun `on today there is no link`() {
        assertNull(TodayLink.needed(today, today, today, monthOpen = false))
        assertNull(TodayLink.needed(today, today, today, monthOpen = true))
    }

    @Test
    fun `in the future the link is on the left and points back`() {
        val link = TodayLink.needed(today.plusDays(3), today, today, monthOpen = false)
        assertEquals(TodayLink.OnTheLeft, link)
        assertEquals("← Today", link?.text)
    }

    @Test
    fun `in the past the link is on the right and points forward`() {
        val link = TodayLink.needed(today.plusDays(-3), today, today, monthOpen = false)
        assertEquals(TodayLink.OnTheRight, link)
        assertEquals("Today →", link?.text)
    }

    @Test
    fun `browsing months with today still selected also offers the way back`() {
        val next = date(2026, 12, 1)
        val earlier = date(2026, 8, 1)
        assertEquals(TodayLink.OnTheLeft, TodayLink.needed(today, today, next, monthOpen = true))
        assertEquals(TodayLink.OnTheRight, TodayLink.needed(today, today, earlier, monthOpen = true))
        // The month is only looked at while it is open.
        assertNull(TodayLink.needed(today, today, next, monthOpen = false))
    }

    @Test
    fun `across a year boundary`() {
        val jan = date(2027, 1, 2)
        assertEquals(TodayLink.OnTheLeft, TodayLink.needed(jan, today, jan, monthOpen = false))
    }
}
