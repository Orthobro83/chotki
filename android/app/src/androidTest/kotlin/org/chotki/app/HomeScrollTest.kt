package org.chotki.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotDisplayed
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.RuleScreen
import org.chotki.app.ui.oldStyleDate
import org.chotki.core.Recurrence
import org.chotki.core.Rule as PrayerRule
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertTrue
import kotlin.math.abs
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Home grows downward. The saying follows the day. It is not pinned to the
 * bottom of the screen, and a day that needs more room scrolls to reach it.
 */
@RunWith(AndroidJUnit4::class)
class HomeScrollTest {

    @get:Rule val compose = createComposeRule()

    private fun state(): AppState = AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }

    @Test fun todayStartsCenteredInTheWeek() {
        val state = state()
        compose.setContent {
            ChotkiTheme {
                Box(Modifier.fillMaxSize()) { RuleScreen(state, Modifier.fillMaxSize()) }
            }
        }
        compose.waitForIdle()

        val week = compose.onNodeWithTag("the week").fetchSemanticsNode().boundsInRoot
        val day = compose.onNode(hasContentDescription("Day ${state.today.iso}", substring = true))
            .fetchSemanticsNode()
            .boundsInRoot
        val miss = abs(day.center.x - week.center.x)
        assertTrue(
            "today should sit in the middle of the week, off by $miss",
            miss < day.width,
        )
    }

    @Test fun theSayingFollowsTheInviteInsteadOfSittingAtTheBottom() {
        val state = state()
        compose.setContent {
            ChotkiTheme {
                Box(Modifier.height(900.dp)) { RuleScreen(state, Modifier.fillMaxSize()) }
            }
        }

        val invite = compose.onNodeWithText("Create your first rule").fetchSemanticsNode()
        val saying = compose.onNodeWithText("Sayings of the church fathers").fetchSemanticsNode()
        val screen = compose.onRoot().fetchSemanticsNode().size.height

        assertTrue(
            "the saying should follow the invite, not sit above it",
            saying.boundsInRoot.top >= invite.boundsInRoot.bottom,
        )
        assertTrue(
            "the saying is pinned to the bottom: ${saying.boundsInRoot.bottom} of $screen",
            saying.boundsInRoot.bottom < screen * 0.78f,
        )
        compose.onNodeWithText(oldStyleDate(state.selectedDate)).assertIsDisplayed()
    }

    @Test fun aTallDayScrollsToTheSaying() {
        val state = state()
        repeat(4) {
            val rule = PrayerRule(title = "Rule number $it", recurrence = Recurrence.Daily)
            state.save(rule)
            state.takeUp(rule)
        }
        compose.setContent {
            ChotkiTheme {
                Box(Modifier.height(360.dp)) { RuleScreen(state, Modifier.fillMaxSize()) }
            }
        }

        compose.onNodeWithText("Today's commitments").assertIsDisplayed()
        compose.onNodeWithText("Sayings of the church fathers").assertIsNotDisplayed()
        compose.onNodeWithText("Sayings of the church fathers").performScrollTo().assertIsDisplayed()
    }
}
