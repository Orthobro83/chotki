package org.chotki.app

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.ui.unit.dp
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.RuleScreen
import org.chotki.core.Recurrence
import org.chotki.core.Rule as PrayerRule
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The calendar used to eat the screen.
 *
 * A six-row month on a phone is most of the height available, and the rules it
 * sits above were laid out beneath it with whatever was left — often nothing —
 * in a column that does not scroll. So a person with a real rule could see
 * their calendar and never their rules, and no amount of dragging helped.
 *
 * These are the three things that must stay true.
 */
@RunWith(AndroidJUnit4::class)
class CalendarFoldTest {

    @get:Rule val compose = createComposeRule()

    /**
     * Enough to overflow the list, which is the only state where folding
     * happens or is needed. Fourteen was not: they fitted in the space below a
     * capped calendar, nothing scrolled, and nothing folded — correctly.
     */
    private fun stateWithRules(count: Int): AppState {
        val state = AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }
        repeat(count) {
            val rule = PrayerRule(title = "Rule number $it", recurrence = Recurrence.Daily)
            state.save(rule)
            state.takeUp(rule)
        }
        return state
    }

    private fun show(state: AppState) {
        compose.setContent { ChotkiTheme { RuleScreen(state, Modifier.fillMaxSize()) } }
    }

    /** The bug itself: the last rule has to be reachable. */
    @Test fun everyRuleCanBeReachedNoMatterHowManyThereAre() {
        show(stateWithRules(30))

        compose.onNode(hasScrollAction()).performScrollToNode(hasText("Rule number 29"))
        compose.onNodeWithText("Rule number 29").assertIsDisplayed()
    }

    /** Half the screen, and no more, however many weeks the month runs to. */
    @Test fun theCalendarNeverTakesMoreThanHalfTheScreen() {
        show(stateWithRules(3))

        val screen = compose.onRoot().fetchSemanticsNode().size.height
        val calendar = compose.onNodeWithTag("the calendar").fetchSemanticsNode().size.height

        assertTrue(
            "the calendar is $calendar of $screen",
            calendar <= screen / 2,
        )
    }

    /** Scrolling the rules folds the month down to the week being looked at. */
    @Test fun scrollingTheRulesFoldsTheCalendarToAWeek() {
        show(stateWithRules(30))
        compose.onNodeWithContentDescription("The month before").assertIsDisplayed()

        val before = compose.onNodeWithTag("the calendar").fetchSemanticsNode().size.height
        compose.onNode(hasScrollAction()).performScrollToNode(hasText("Rule number 29"))
        compose.waitForIdle()

        val after = compose.onNodeWithTag("the calendar").fetchSemanticsNode().size.height
        assertTrue("the calendar did not fold: $before then $after", after < before)
        compose.onNodeWithContentDescription("The week before").assertIsDisplayed()
    }

    /** Folded, the arrows step a week. A month would move it out of view. */
    @Test fun theArrowsStepAWeekWhileFolded() {
        val state = stateWithRules(30)
        show(state)
        val started = state.selectedDate

        compose.onNode(hasScrollAction()).performScrollToNode(hasText("Rule number 29"))
        compose.waitForIdle()
        compose.onNodeWithContentDescription("The week after").performClick()
        compose.waitForIdle()

        assertTrue(
            "moved from $started to ${state.selectedDate}",
            state.selectedDate == started.plusDays(7),
        )
    }

    /** Back at the top, the whole month comes back. */
    @Test fun returningToTheTopUnfoldsTheMonth() {
        show(stateWithRules(30))

        compose.onNode(hasScrollAction()).performScrollToNode(hasText("Rule number 29"))
        compose.waitForIdle()
        compose.onNodeWithContentDescription("The week before").assertIsDisplayed()

        compose.onNode(hasScrollAction()).performScrollToNode(hasText("Rule number 0"))
        compose.waitForIdle()
        compose.onNodeWithContentDescription("The month before").assertIsDisplayed()
    }

    /**
     * A six-row month on an ordinary phone, with the readiness banner taking
     * its share, still shows as a month.
     *
     * The calendar folds by itself when a month will not fit legibly, and that
     * guard was first set tight enough that a full banner tipped it over — so a
     * fresh install opened folded, with nothing scrolled and no reason for it.
     * 470dp is what a 851dp phone leaves this screen once the title, a
     * two-line banner, the library link and the bottom bar have taken theirs.
     */
    @Test fun aMonthStillFitsOnAPhoneWithTheBannerShowing() {
        val state = stateWithRules(2)
        compose.setContent {
            ChotkiTheme {
                Box(Modifier.height(470.dp)) { RuleScreen(state, Modifier.fillMaxSize()) }
            }
        }

        // Folded, the arrows say "week"; unfolded they say "month".
        compose.onNodeWithContentDescription("The month before").assertIsDisplayed()
    }

    /** And it does still fold when the space is genuinely too small. */
    @Test fun aMonthFoldsWhenThereIsTrulyNoRoom() {
        val state = stateWithRules(2)
        compose.setContent {
            ChotkiTheme {
                Box(Modifier.height(260.dp)) { RuleScreen(state, Modifier.fillMaxSize()) }
            }
        }

        compose.onNodeWithContentDescription("The week before").assertIsDisplayed()
    }
}
