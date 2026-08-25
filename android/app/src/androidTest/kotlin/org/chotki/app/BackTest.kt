package org.chotki.app

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.Shell
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Where the back button goes.
 *
 * Reported in use: it took you to the wrong place, or straight out of the app.
 * Both had the same cause — the screens were separate flags with nowhere for
 * "the place before this one" to live, so every press fell through to Android's
 * default, which is to finish the activity. Three fields into the editor, back
 * closed Chotki.
 */
@RunWith(AndroidJUnit4::class)
class BackTest {

    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()

    private fun show() {
        val state = AppState(SqliteStore(AndroidDb.inMemory())).also {
            it.load()
            // Past the welcome; back-navigation is what these are about.
            it.updateSettings { settings -> settings.copy(hasCompletedFirstRun = true) }
        }
        compose.setContent { ChotkiTheme { Shell(state) } }
    }

    private fun withState(configure: (AppState) -> Unit) {
        val state = AppState(SqliteStore(AndroidDb.inMemory())).also {
            it.load()
            // Past the welcome; back-navigation is what these are about.
            it.updateSettings { settings -> settings.copy(hasCompletedFirstRun = true) }
        }
        configure(state)
        compose.setContent { ChotkiTheme { Shell(state) } }
    }

    private fun pressBack() {
        // Settle *before* dispatching. BackHandler registers itself with an
        // `enabled` flag taken from the current composition, so pressing back in
        // the same breath as the click that changed the screen finds the handler
        // still disabled — and the press falls through to Android's default,
        // which closes the app. That is the very failure these tests exist for,
        // reproduced by the test rather than by the app.
        compose.waitForIdle()
        compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
    }

    private val stillOpen: Boolean get() = !compose.activity.isFinishing

    @Test
    fun backFromASecondaryPlaceReturnsToTheDay() {
        show()
        compose.onNodeWithContentDescription("Go to Progress").performClick()
        pressBack()

        compose.onNodeWithContentDescription("Open the library").assertIsDisplayed()
        assertTrue("it left the app instead of going back", stillOpen)
    }

    @Test
    fun backFromTheLibraryReturnsToTheDay() {
        show()
        compose.onNodeWithContentDescription("Open the library").performClick()
        pressBack()

        compose.onNodeWithContentDescription("Open the library").assertIsDisplayed()
        assertTrue(stillOpen)
    }

    // The one that closed the app: two levels deep, from the day into the
    // library into the editor.
    @Test
    fun backFromTheEditorReturnsToTheLibrary() {
        show()
        compose.onNodeWithContentDescription("Open the library").performClick()
        compose.onNode(hasScrollAction())
            .performScrollToNode(hasContentDescription("Write your own rule"))
        compose.onNodeWithContentDescription("Write your own rule").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Rule editor").assertIsDisplayed()

        pressBack()
        // Asserted on the library's own header rather than on an entry near the
        // bottom of it: coming back composes the list afresh at the top, so the
        // entry is not there to scroll to, and the assertion would fail for a
        // reason that has nothing to do with where back went.
        compose.onNodeWithContentDescription("Back to the day").assertIsDisplayed()
        assertTrue("it left the app from two screens deep", stillOpen)

        pressBack()
        compose.onNodeWithContentDescription("Open the library").assertIsDisplayed()
        assertTrue(stillOpen)
    }

    @Test
    fun backFromARulesPrayersReturnsToTheDay() {
        withState { it.take("morning-prayers") }
        compose.onNodeWithContentDescription("Read the prayers for Morning prayers").performClick()
        compose.waitForIdle()

        pressBack()
        compose.onNodeWithContentDescription("Edit Morning prayers").assertIsDisplayed()
        assertTrue(stillOpen)
    }

    @Test
    fun backFromEditingARuleReturnsToTheDay() {
        withState { it.take("morning-prayers") }
        compose.onNodeWithContentDescription("Edit Morning prayers").performClick()
        compose.waitForIdle()

        pressBack()
        compose.onNodeWithContentDescription("Edit Morning prayers").assertIsDisplayed()
        assertTrue(stillOpen)
    }

    // A term opened from the glossary is a step of its own, so back returns to
    // the list rather than jumping out of the glossary altogether.
    @Test
    fun backFromATermReturnsToTheTerms() {
        show()
        compose.onNodeWithContentDescription("Go to Glossary").performClick()
        compose.onNode(hasScrollAction())
            .performScrollToNode(hasContentDescription("Open Amen"))
        compose.onNodeWithContentDescription("Open Amen").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Back to all terms").assertIsDisplayed()

        pressBack()
        compose.onNodeWithContentDescription("Search terms").assertIsDisplayed()
        assertTrue(stillOpen)
    }

    // Browsing the bar must not build a stack: three presses to leave after
    // glancing at three places is its own kind of wrong.
    @Test
    fun theBarReplacesRatherThanPilingUp() {
        show()
        compose.onNodeWithContentDescription("Go to Reading").performClick()
        compose.onNodeWithContentDescription("Go to Progress").performClick()
        compose.onNodeWithContentDescription("Go to Glossary").performClick()

        pressBack()
        compose.onNodeWithContentDescription("Open the library").assertIsDisplayed()
        assertTrue(stillOpen)
    }

    // Back from the day should leave the app, and that is asserted in
    // JourneyTest instead. Finishing the activity here crashed the
    // instrumentation runner for every test that ran after it.
}
