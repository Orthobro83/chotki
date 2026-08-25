package org.chotki.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.Shell
import org.chotki.core.Recurrence
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Writing a rule of one's own, changing it, and setting it down.
 *
 * Core functionality rather than a nicety: the whole app is built on the idea
 * that a rule is taken on deliberately and can be adjusted, and a library of
 * somebody else's rules with no way to write your own is a different app.
 */
@RunWith(AndroidJUnit4::class)
class CustomRuleTest {

    @get:Rule val compose = createComposeRule()

    private fun state(): AppState = AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }

    private fun openLibrary(state: AppState) {
        compose.setContent { ChotkiTheme { Shell(state) } }
        compose.onNodeWithContentDescription("Open the library").performClick()
        compose.waitForIdle()
    }

    private fun scrollTo(description: String) {
        compose.onNode(hasScrollAction()).performScrollToNode(hasContentDescription(description))
    }

    @Test
    fun aRuleOfOnesOwnCanBeWritten() {
        val state = state()
        openLibrary(state)

        scrollTo("Write your own rule")
        compose.onNodeWithContentDescription("Write your own rule").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Rule editor").assertIsDisplayed()

        compose.onNodeWithContentDescription("Rule title").performTextInput("Cold plunge")
        compose.waitForIdle()
        compose.onNodeWithText("Cold plunge").assertIsDisplayed()
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertEquals(1, state.rules.size)
        assertEquals("Cold plunge", state.rules.single().title)
        assertTrue(
            "it was saved but is not due today",
            state.entries(state.today).any { it.rule.title == "Cold plunge" },
        )
    }

    @Test
    fun aWrittenRuleAppearsUnderCustomAndCanBeSetAside() {
        val state = state()
        state.save(org.chotki.core.Rule(title = "Cold plunge", recurrence = Recurrence.Daily))
        openLibrary(state)

        scrollTo("Set aside Cold plunge")
        compose.onNodeWithContentDescription("Set aside Cold plunge").performClick()
        compose.waitForIdle()

        assertTrue("it is still offered", state.customEntries.none { it.title == "Cold plunge" })
        // Set aside from the listing only — the rule itself is untouched.
        assertEquals(1, state.rules.size)
    }

    @Test
    fun aRuleSetDownCanBeTakenUpAgainWithoutWritingItTwice() {
        val state = state()
        val rule = org.chotki.core.Rule(title = "Cold plunge", recurrence = Recurrence.Daily)
        state.save(rule)
        state.remove(rule)
        assertTrue("removing it should stop it being due", state.entries(state.today).isEmpty())

        openLibrary(state)
        scrollTo("Take up Cold plunge")
        compose.onNodeWithContentDescription("Take up Cold plunge").performClick()
        compose.waitForIdle()

        assertTrue(
            "it was not taken up again",
            state.entries(state.today).any { it.rule.title == "Cold plunge" },
        )
        assertEquals("a second rule was made instead of resuming the first", 1, state.rules.size)
    }

    // The pencil on the day, which was missing entirely.
    @Test
    fun aRuleCanBeEditedFromTheDay() {
        val state = state()
        state.take("morning-prayers")
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithContentDescription("Edit Morning prayers").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Rule editor").assertIsDisplayed()

        // How often is a menu now, so it is opened before it is chosen from.
        // Matched on the field rather than its current value, which depends on
        // whatever the rule already says.
        compose.onNode(hasContentDescription("How often", substring = true))
            .performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Choose Every day").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertEquals("editing made a second rule", 1, state.rules.size)
        assertEquals(Recurrence.Daily, state.rules.single().recurrence)
    }

    @Test
    fun editingKeepsThePrayersTheRuleCarried() {
        val state = state()
        state.take("morning-prayers")
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithContentDescription("Edit Morning prayers").performClick()
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertTrue("the prayers were dropped by the editor", state.rules.single().hasPrayers)
    }

    // The way to the words, which is the point of a prayer rule.
    @Test
    fun theRuleOnTheDayLeadsToItsPrayers() {
        val state = state()
        state.take("morning-prayers")
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithContentDescription("Read the prayers for Morning prayers").performClick()
        compose.waitForIdle()

        compose.onNodeWithText("O Heavenly King").assertIsDisplayed()
        compose.onNodeWithContentDescription("Back to the day").assertIsDisplayed()
    }

    @Test
    fun aRuleWithNoPrayersOffersNoWayToThem() {
        val state = state()
        state.save(org.chotki.core.Rule(title = "Cold plunge", recurrence = Recurrence.Daily))
        compose.setContent { ChotkiTheme { Shell(state) } }

        compose.onNodeWithContentDescription("Edit Cold plunge").assertIsDisplayed()
        assertEquals(
            0,
            compose.onAllNodesWithContentDescription("Read the prayers for Cold plunge")
                .fetchSemanticsNodes().size,
        )
    }

    // Nothing is ever destroyed, and the editor says so.
    @Test
    fun removingARuleKeepsWhatItKept() {
        val state = state()
        state.take("morning-prayers")
        val entry = state.entries(state.today).single()
        state.toggleKept(entry)
        assertEquals(1, state.occurrences.size)

        compose.setContent { ChotkiTheme { Shell(state) } }
        compose.onNodeWithContentDescription("Edit Morning prayers").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Remove the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertTrue("it is still due", state.entries(state.today).isEmpty())
        assertEquals("the record was destroyed with it", 1, state.occurrences.size)
    }
}
