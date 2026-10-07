package org.chotki.app

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.RuleScreen
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** The way back to today appears once the calendar has been moved away from it, and only then. */
@RunWith(AndroidJUnit4::class)
class TodayLinkTest {

    @get:Rule val compose = createComposeRule()

    private fun show(): AppState {
        val state = AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }
        compose.setContent { ChotkiTheme { RuleScreen(state, Modifier.fillMaxSize()) } }
        return state
    }

    private fun links() = compose.onAllNodesWithContentDescription("Back to today").fetchSemanticsNodes().size

    @Test
    fun noLinkOnToday() {
        show()
        assertEquals(0, links())
    }

    @Test
    fun aLinkAppearsInTheFutureAndReturnsToToday() {
        val state = show()
        val today = state.today
        compose.onNodeWithContentDescription("The week after").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Back to today").assertIsDisplayed()
        compose.onNodeWithContentDescription("Back to today").performClick()
        compose.waitForIdle()
        assertEquals(today, state.selectedDate)
        assertEquals(0, links())
    }

    @Test
    fun aLinkAppearsInThePastToo() {
        show()
        compose.onNodeWithContentDescription("The week before").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Back to today").assertIsDisplayed()
    }
}
