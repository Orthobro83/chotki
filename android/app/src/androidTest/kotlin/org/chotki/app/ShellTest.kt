package org.chotki.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.Place
import org.chotki.app.ui.Shell
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * That every place in the app can actually be reached.
 *
 * On macOS a whole screen was dead — the navigation buttons set state the window
 * never read, so they worked in the popover and did nothing in the window. The
 * test that caught it asserted every screen routes somewhere, and it went on to
 * catch two more added later. This is that test.
 */
@RunWith(AndroidJUnit4::class)
class ShellTest {

    @get:Rule val compose = createComposeRule()

    private fun state(): AppState = AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }

    private fun show() {
        val state = state()
        compose.setContent { ChotkiTheme { Shell(state) } }
    }

    @Test
    fun everyPlaceIsReachable() {
        show()
        for (place in Place.entries) {
            compose.onNodeWithContentDescription("Go to ${place.title}").performClick()
            compose.waitForIdle()
        }
    }

    @Test
    fun theRuleShowsTheDayAndTheMonth() {
        show()
        compose.onNodeWithContentDescription("Go to Rule").performClick()
        compose.onNodeWithContentDescription("The day").assertIsDisplayed()
        compose.onNodeWithContentDescription("The month before").assertIsDisplayed()
    }

    // Going back is not an edge case: someone who kept their prayers and forgot
    // to say so must be able to put it right.
    @Test
    fun anEarlierDayCanBeSelected() {
        val state = state()
        state.take("morning-prayers")
        compose.setContent { ChotkiTheme { Shell(state) } }

        val today = state.today
        val earlier = if (today.day > 1) today.day - 1 else today.day
        compose.onNodeWithContentDescription("Day $earlier").performClick()
        compose.waitForIdle()

        assertEquals(earlier, state.selectedDate.day)
    }

    @Test
    fun theMonthCanBeTurned() {
        val state = state()
        compose.setContent { ChotkiTheme { Shell(state) } }
        val before = state.visibleMonth.month

        compose.onNodeWithContentDescription("The month before").performClick()
        compose.waitForIdle()
        assertTrue("the month did not change", state.visibleMonth.month != before)
    }

    @Test
    fun progressLeadsWithWordsRatherThanAFigure() {
        show()
        compose.onNodeWithContentDescription("Go to Progress").performClick()
        compose.onNodeWithContentDescription("Progress heading").assertIsDisplayed()
        // Nothing is due yet on a fresh install, and that is said plainly rather
        // than reported as nought per cent.
        compose.onNodeWithText("Nothing has come due yet. This fills in as the days pass.")
            .assertIsDisplayed()
    }

    @Test
    fun aPrayerCanBeOpenedAndItsSourceIsShown() {
        show()
        compose.onNodeWithContentDescription("Go to Prayers").performClick()
        // A LazyColumn composes only what is on screen, so the list is scrolled
        // the way a person would scroll it.
        compose.onNode(hasScrollAction())
            .performScrollToNode(hasContentDescription("Open The Jesus Prayer"))
        compose.onNodeWithContentDescription("Open The Jesus Prayer").performClick()
        compose.waitForIdle()

        compose.onNodeWithText(
            "Lord Jesus Christ, Son of God, have mercy on me, a sinner.",
        ).assertIsDisplayed()
        compose.onNodeWithContentDescription("Back to the prayers").assertIsDisplayed()
    }

    @Test
    fun theGlossarySearchesAndOpensATerm() {
        show()
        compose.onNodeWithContentDescription("Go to Glossary").performClick()
        compose.onNodeWithContentDescription("Search terms").performTextInput("theotokos")
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Open Theotokos").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Back to all terms").assertIsDisplayed()
    }

    @Test
    fun theReadingIsThere() {
        show()
        compose.onNodeWithContentDescription("Go to Reading").performClick()
        compose.onNodeWithContentDescription("The reading").assertIsDisplayed()
    }

    // The app reporting on itself, not on the person.
    @Test
    fun settingsSaysWhetherRemindersWillArrive() {
        show()
        compose.onNodeWithContentDescription("Go to Settings").performClick()
        compose.onNodeWithContentDescription("Notifications readiness").assertIsDisplayed()
        compose.onNodeWithContentDescription("Exact alarms readiness").assertIsDisplayed()
        compose.onNodeWithContentDescription(
            "Allowed to run in the background readiness",
        ).assertIsDisplayed()
    }

    @Test
    fun theLibraryIsReachedFromTheDayAndComesBack() {
        show()
        compose.onNodeWithContentDescription("Go to Rule").performClick()
        compose.onNodeWithContentDescription("Open the library").performClick()
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Back to the day").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Open the library").assertIsDisplayed()
    }
}
