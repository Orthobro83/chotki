package org.chotki.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.RopeScreen
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The rope: counting, and the rope appearing only where it belongs.
 *
 * The tone itself is arithmetic and tested in `:core` without a sound card.
 * What is checked here is that pressing Count actually counts, and that the rope
 * follows what is being prayed — a rule read straight through is not counted on
 * a rope, and offering knots beside it would teach the wrong thing.
 */
@RunWith(AndroidJUnit4::class)
class RopeTest {

    @get:Rule val compose = createComposeRule()

    private fun show() {
        val state = AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }
        compose.setContent { ChotkiTheme { RopeScreen(state) } }
    }

    @Test
    fun theRopeOpensOnTheJesusPrayerWithACount() {
        show()
        compose.onNodeWithContentDescription("The count").assertIsDisplayed()
        compose.onNodeWithText("0").assertIsDisplayed()
        compose.onNodeWithText("of 33").assertIsDisplayed()
    }

    @Test
    fun countingCounts() {
        show()
        repeat(3) {
            compose.onNodeWithContentDescription("Count a knot").performClick()
            compose.waitForIdle()
        }
        compose.onNodeWithText("3").assertIsDisplayed()
    }

    @Test
    fun theCountStopsAtTheKnot() {
        show()
        compose.onNodeWithContentDescription("Count to 33").performClick()
        repeat(35) {
            compose.onNodeWithContentDescription("Count a knot").performClick()
        }
        compose.waitForIdle()
        // Asserted through the count rather than by text: the target chip also
        // reads "33", and matching on that would pass without counting anything.
        compose.onNodeWithContentDescription("The count").assertTextEquals("33")
        compose.onNodeWithText("the knot is complete").assertIsDisplayed()
    }

    @Test
    fun aNewTargetStartsTheCountAgain() {
        show()
        repeat(4) { compose.onNodeWithContentDescription("Count a knot").performClick() }
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Count to 50").performClick()
        compose.waitForIdle()

        // 4 of 50 would be carried across otherwise, which is a count nobody made.
        compose.onNodeWithText("0").assertIsDisplayed()
        compose.onNodeWithText("of 50").assertIsDisplayed()
    }

    @Test
    fun startingAgainClearsTheCount() {
        show()
        repeat(5) { compose.onNodeWithContentDescription("Count a knot").performClick() }
        compose.onNodeWithContentDescription("Start again").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("0").assertIsDisplayed()
    }

    // A rule is read straight through, so the rope has no business beside it.
    @Test
    fun choosingARuleTakesTheRopeAway() {
        show()
        compose.onNodeWithContentDescription("Choose what to pray").performClick()
        compose.onNodeWithContentDescription("Pray Morning prayers").performScrollTo().performClick()
        compose.waitForIdle()

        assertEquals(
            0,
            compose.onAllNodesWithContentDescription("Count a knot").fetchSemanticsNodes().size,
        )
        compose.onNodeWithText("O Heavenly King").assertIsDisplayed()
    }

    @Test
    fun theRopeCanBeAskedForAnyway() {
        show()
        compose.onNodeWithContentDescription("Choose what to pray").performClick()
        compose.onNodeWithContentDescription("Pray Morning prayers").performScrollTo().performClick()
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Show or hide the rope").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Count a knot").assertIsDisplayed()
    }

    @Test
    fun choosingNothingLeavesTheRopeAlone() {
        show()
        compose.onNodeWithContentDescription("Choose what to pray").performClick()
        compose.onNodeWithContentDescription("Pray The rope alone").performClick()
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Count a knot").assertIsDisplayed()
        // Nothing to read, which is the point: the words are already known.
        assertEquals(
            0,
            compose.onAllNodesWithContentDescription("Source · Common usage")
                .fetchSemanticsNodes().size,
        )
    }

    @Test
    fun aRopePrayerShowsItsWordsBeneathTheCount() {
        show()
        compose.onNodeWithText(
            "Lord Jesus Christ, Son of God, have mercy on me, a sinner.",
        ).assertIsDisplayed()
    }
}
