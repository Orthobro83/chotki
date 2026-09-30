package org.chotki.app

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.Shell
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The welcome, which Android never had.
 *
 * `hasCompletedFirstRun` has been in the shared settings since the beginning
 * and nothing on this platform read it, so every install opened straight onto
 * an empty day with no explanation of what the app was for.
 */
@RunWith(AndroidJUnit4::class)
class WelcomeTest {

    @get:Rule val compose = createComposeRule()

    private fun freshState(): AppState =
        AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }

    /**
     * The mark plays before the welcome, unless the device has turned
     * animations off — in which case it is skipped and the welcome is already up.
     */
    private fun showFresh(state: AppState = freshState()): AppState {
        compose.mainClock.autoAdvance = false
        compose.setContent { ChotkiTheme { Shell(state) } }
        compose.waitForIdle()
        val opening = compose.onAllNodesWithContentDescription("The opening")
            .fetchSemanticsNodes().isNotEmpty()
        if (opening) {
            compose.mainClock.advanceTimeBy(4_000)
        }
        compose.mainClock.autoAdvance = true
        compose.waitForIdle()
        return state
    }

    @Test fun itIsTheFirstThingShown() {
        val state = freshState()
        compose.mainClock.autoAdvance = false
        compose.setContent { ChotkiTheme { Shell(state) } }
        compose.waitForIdle()

        val opening = compose.onAllNodesWithContentDescription("The opening")
            .fetchSemanticsNodes().isNotEmpty()
        if (opening) {
            compose.onNodeWithContentDescription("Go to Settings").assertDoesNotExist()
            compose.mainClock.advanceTimeBy(4_000)
        }
        compose.mainClock.autoAdvance = true
        compose.waitForIdle()

        compose.onNodeWithContentDescription("The welcome").assertIsDisplayed()
        // And nothing else is reachable behind it.
        compose.onNodeWithContentDescription("Go to Settings").assertDoesNotExist()
    }

    @Test fun beginningPutsItAwayForGood() {
        val state = showFresh()

        compose.onNodeWithContentDescription(org.chotki.core.content.Welcome.beginLabel)
            .performScrollTo()
            .performClick()
        compose.waitForIdle()

        assertTrue("the flag was not written", state.settings.hasCompletedFirstRun)
        compose.onNodeWithContentDescription("The welcome").assertDoesNotExist()
        compose.onNodeWithContentDescription("Go to Settings").assertIsDisplayed()
    }

    @Test fun someoneWhoHasBegunNeverSeesItAgain() {
        val state = freshState()
        state.updateSettings { it.copy(hasCompletedFirstRun = true) }
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithContentDescription("The welcome").assertDoesNotExist()
    }

    /** The words are the ones in core, not a copy typed in here. */
    @Test fun itSaysWhatCoreSays() {
        showFresh()

        compose.onNodeWithText(org.chotki.core.content.Welcome.title).assertIsDisplayed()
        assertEquals("Welcome", org.chotki.core.content.Welcome.title)
        assertEquals("Continue", org.chotki.core.content.Welcome.beginLabel)

        val urls = org.chotki.core.content.Welcome.paragraphs
            .flatMap { it.spans }.mapNotNull { it.url }
        assertTrue("the welcome no longer sends anyone elsewhere", urls.isEmpty())
        compose.onNodeWithText(
            "Chotki is best used in cooperation with a spiritual father, and we encourage you to find one as soon as possible.",
        ).performScrollTo().assertIsDisplayed()
    }
}
