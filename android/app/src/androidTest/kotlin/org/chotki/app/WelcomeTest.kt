package org.chotki.app

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
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

    @Test fun itIsTheFirstThingShown() {
        val state = freshState()
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithContentDescription("The welcome").assertIsDisplayed()
        // And nothing else is reachable behind it.
        compose.onNodeWithContentDescription("Go to Settings").assertDoesNotExist()
    }

    @Test fun beginningPutsItAwayForGood() {
        val state = freshState()
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithContentDescription("Begin").performScrollTo().performClick()
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
        val state = freshState()
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithText(org.chotki.core.content.Welcome.title).assertIsDisplayed()
        assertEquals("Begin", org.chotki.core.content.Welcome.beginLabel)

        val urls = org.chotki.core.content.Welcome.paragraphs
            .flatMap { it.spans }.mapNotNull { it.url }
        assertEquals(
            listOf(
                "https://www.skool.com/fathermoses/",
                "https://orthodoxaustin.org/our-clergy/",
            ),
            urls,
        )
    }
}
