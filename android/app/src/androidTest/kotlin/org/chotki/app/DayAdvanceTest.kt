package org.chotki.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.core.store.SqliteStore
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.assertEquals

/**
 * The day the view is showing, once the clock has moved on.
 *
 * `DayRolloverTest` in :core proves the rule. This proves the state obeys it —
 * that the selection actually moves, that the grid follows it to the right
 * month, and that a day chosen on purpose is not taken away. A rule nothing
 * calls is the failure this project keeps meeting.
 */
@RunWith(AndroidJUnit4::class)
class DayAdvanceTest {

    private fun state() = AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }

    @Test
    fun openingOnALaterDayMovesTheViewToIt() {
        val state = state()
        val opened = state.selectedDate

        state.advanceDayIfNeeded(opened.plusDays(1))
        assertEquals(opened.plusDays(1), state.selectedDate)
    }

    @Test
    fun theGridFollowsTheSelectionIntoTheNewMonth() {
        val state = state()
        // Far enough to land in a different month whatever today happens to be.
        val later = state.selectedDate.plusDays(40)

        state.advanceDayIfNeeded(later)
        assertEquals(later, state.selectedDate)
        assertEquals(later.month, state.visibleMonth.month)
        assertEquals(later.year, state.visibleMonth.year)
    }

    @Test
    fun aDayChosenOnPurposeIsLeftWhereItIs() {
        val state = state()
        val lastWeek = state.selectedDate.plusDays(-7)
        state.selectedDate = lastWeek

        state.advanceDayIfNeeded(state.today.plusDays(1))
        assertEquals("looking back at last week was interrupted", lastWeek, state.selectedDate)
    }

    @Test
    fun nothingMovesWhenTheDayHasNotChanged() {
        val state = state()
        val opened = state.selectedDate

        state.advanceDayIfNeeded(opened)
        state.advanceDayIfNeeded(opened)
        assertEquals(opened, state.selectedDate)
    }
}
