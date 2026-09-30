package org.chotki.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.onLast
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.click
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import org.chotki.app.ui.RuleEditor
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.LibrarySheet
import org.chotki.app.ui.RuleScreen
import org.chotki.core.Recurrence
import org.chotki.core.Rule as PrayerRule
import org.chotki.core.store.SqliteStore
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue

/**
 * The interface, driven.
 *
 * Every interface bug in the macOS app was a control that drew correctly and did
 * nothing: an unclickable checkbox, buttons that set state nothing read, a whole
 * screen unreachable. A screenshot showed none of them. These tap things and
 * check what happened to the record underneath.
 */
@RunWith(AndroidJUnit4::class)
class RuleScreenTest {

    @get:Rule val compose = createComposeRule()

    private fun freshState(): AppState =
        AppState(SqliteStore(AndroidDb.inMemory()))

    @Test
    fun anEmptyRuleSaysSoRatherThanShowingNothing() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { RuleScreen(state) } }

        compose.onNodeWithText("Create your first rule").assertIsDisplayed()
    }

    /**
     * Taking something on now opens it filled in, so how often can be settled
     * before it lands rather than by hunting down the pencil afterwards.
     * Nothing is saved until the button is pressed.
     */
    @Test
    fun takingARuleOnFromTheLibraryPutsItOnTheDay() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { LibraryThenEditor(state) } }

        takeOn("Morning prayers", "Prayer")
        assertEquals("it was saved before the editor was even answered", 0, state.rules.size)

        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertTrue("the library did not take the rule on", state.isTaken("morning-prayers"))
        assertEquals(1, state.rules.size)
        assertTrue(
            "it was saved but is not due today",
            state.entries(state.today).any { it.rule.title == "Morning prayers" },
        )
    }

    @Test
    fun aRuleTakenOnCarriesItsPrayersAndItsTime() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { LibraryThenEditor(state) } }

        takeOn("Morning prayers", "Prayer")
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        val rule = state.rules.single()
        assertTrue("the prayers did not come with it", rule.hasPrayers)
        // The template's own time has to survive the trip through the editor.
        // Reading only `existing` dropped it, and the rule arrived running all
        // day when what was taken on said half past six.
        assertEquals(6, rule.timeOfDay?.hour)
        assertEquals(30, rule.timeOfDay?.minute)
    }

    /** How often can be changed before the rule ever reaches the day. */
    @Test
    fun theRecurrenceCanBeSettledWhileTakingItOn() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { LibraryThenEditor(state) } }

        takeOn("Morning prayers", "Prayer")

        compose.onNodeWithContentDescription("How often — Every day").performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Choose Certain weekdays").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        val recurrence = state.rules.single().recurrence
        assertTrue("it was saved as $recurrence", recurrence is org.chotki.core.Recurrence.Weekly)
    }

    // The circle marks a rule, and marks it again after it has been cleared.
    // A real tap, not the semantics action: the card underneath fills the same
    // corner, and a click that only the semantics node heard would leave a
    // finger tap opening the card instead of taking the mark off.
    @Test
    fun tappingTheBoxMarksTheRuleKept() {
        val state = freshState().also { it.load() }
        state.save(PrayerRule(title = "Cold plunge", recurrence = Recurrence.Daily))

        compose.setContent { ChotkiTheme { RuleScreen(state) } }
        compose.onNodeWithContentDescription("Mark Cold plunge kept").performTouchInput { click() }
        compose.waitForIdle()

        val entry = state.entries(state.today).single()
        assertTrue("the circle did nothing", entry.isKept)
        assertEquals(1, state.occurrences.size)
    }

    @Test
    fun tappingItAgainTakesTheRecordAwayRatherThanWritingSkipped() {
        val state = freshState().also { it.load() }
        state.save(PrayerRule(title = "Cold plunge", recurrence = Recurrence.Daily))

        compose.setContent { ChotkiTheme { RuleScreen(state) } }
        val circle = compose.onNodeWithContentDescription("Mark Cold plunge kept")
        circle.performTouchInput { click() }
        compose.waitForIdle()
        circle.performTouchInput { click() }
        compose.waitForIdle()

        assertTrue("un-ticking left a record behind", state.occurrences.isEmpty())
        assertTrue(!state.entries(state.today).single().isKept)
    }

    @Test
    fun tappingItAThirdTimeMarksItKeptAgain() {
        val state = freshState().also { it.load() }
        state.save(PrayerRule(title = "Cold plunge", recurrence = Recurrence.Daily))

        compose.setContent { ChotkiTheme { RuleScreen(state) } }
        val circle = compose.onNodeWithContentDescription("Mark Cold plunge kept")
        circle.performTouchInput { click() }
        compose.waitForIdle()
        circle.performTouchInput { click() }
        compose.waitForIdle()
        circle.performTouchInput { click() }
        compose.waitForIdle()

        assertTrue("checking again after an un-check did nothing", state.entries(state.today).single().isKept)
        assertEquals(1, state.occurrences.size)
    }

    // Finishing the prayers still marks them. The circle has to be able to
    // undo that, and to put it back, or an accidental mark stays for the day.
    @Test
    fun aPrayerTheAppCanSeeTogglesFromTheCircle() {
        val state = freshState().also { it.load() }
        state.take("morning-prayers")

        compose.setContent { ChotkiTheme { RuleScreen(state) } }
        val circle = compose.onNodeWithContentDescription("Mark Morning prayers kept")
        circle.performTouchInput { click() }
        compose.waitForIdle()
        assertTrue("the circle left the prayer unmarked", state.entries(state.today).single().isKept)

        circle.performTouchInput { click() }
        compose.waitForIdle()
        assertTrue("un-ticking a prayer the app can also mark left the record", state.occurrences.isEmpty())
        assertTrue(!state.entries(state.today).single().isKept)
    }

    @Test
    fun tappingTheTitleDoesNotMarkItKept() {
        val state = freshState().also { it.load() }
        state.take("morning-prayers")

        compose.setContent { ChotkiTheme { RuleScreen(state) } }
        compose.onNodeWithText("Morning prayers").performClick()
        compose.waitForIdle()

        assertTrue(
            "the row is a tap target again, which is what broke the prayers link on macOS",
            state.occurrences.isEmpty(),
        )
    }

    @Test
    fun theDayIsNamedInFull() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { RuleScreen(state) } }
        compose.onNodeWithContentDescription("The day").assertIsDisplayed()
    }

    // Taking on a rule tied to the church calendar turns the observance on, or
    // the rule sits on the list and can never come due.
    @Test
    fun takingOnAFastingRuleStartsObservingFasting() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { LibraryThenEditor(state) } }

        takeOn("Great Lent", "Fasting")
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertEquals(
            "the rule was added but could never come due",
            org.chotki.core.Observance.OBSERVED,
            state.settings.observances.fasting,
        )
    }

    /** A folded section hides its rows until it is opened, which is the tap. */
    private fun takeOn(title: String, section: String) {
        compose.onNode(hasContentDescription("Open $section", substring = true))
            .performScrollTo()
            .performClick()
        compose.waitForIdle()
        compose.onNode(hasScrollAction())
            .performScrollToNode(hasContentDescription("Take on $title"))
        compose.onNodeWithContentDescription("Take on $title").performClick()
        compose.waitForIdle()
    }

    /**
     * The library and the editor wired together as the Shell wires them, so
     * these tests drive the path a person actually takes without composing the
     * whole app around it.
     */
    @Composable
    private fun LibraryThenEditor(state: AppState) {
        var pending by remember { mutableStateOf<org.chotki.core.Rule?>(null) }
        val starting = pending
        if (starting == null) {
            LibrarySheet(state, onTakeOn = { pending = it })
        } else {
            RuleEditor(
                state = state,
                existing = null,
                startingFrom = starting,
                onDone = { pending = null },
            )
        }
    }

    /**
     * Every hour of the day has to be reachable.
     *
     * The picker was twenty-four chips in a horizontal scroll inside the page's
     * vertical scroll. On a real phone the page won the gesture and the row
     * would not move past the ninth, so an evening rule could not be set at
     * all — reported as "the maximum time is 08:45".
     */
    @Test fun anEveningHourCanBeChosen() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { LibraryThenEditor(state) } }

        takeOn("Morning prayers", "Prayer")

        compose.onNode(hasContentDescription("Hour", substring = true))
            .performScrollTo().performClick()
        compose.waitForIdle()
        // Twenty-four entries do not fit a menu, so the later hours are below
        // the fold — which is why the first version of this test clicked
        // nothing and saved the default.
        // Two things scroll once the menu is open — the page under it and the
        // menu itself. The menu is the later one.
        compose.onAllNodes(hasScrollAction()).onLast()
            .performScrollToNode(hasContentDescription("Choose 21"))
        compose.onNodeWithContentDescription("Choose 21").performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertEquals(21, state.rules.single().timeOfDay?.hour)
    }

    /**
     * Reminders have to be settable, or there is nothing to test on a phone.
     *
     * The editor never offered them: a rule arrived with whatever the library
     * had decided, and a rule of one's own could not have them at all.
     */
    @Test fun remindersCanBeTurnedOffWhileTakingARuleOn() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { LibraryThenEditor(state) } }

        takeOn("Morning prayers", "Prayer")
        compose.onNodeWithContentDescription("Choose Remind me").performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        assertEquals(false, state.rules.single().effectiveReminders.enabled)
    }

    @Test fun aLeadCanBeChosen() {
        val state = freshState().also { it.load() }
        compose.setContent { ChotkiTheme { LibraryThenEditor(state) } }

        takeOn("Morning prayers", "Prayer")
        compose.onNodeWithContentDescription("Choose 1 hour before").performScrollTo().performClick()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Save the rule").performScrollTo().performClick()
        compose.waitForIdle()

        val leads = state.rules.single().effectiveReminders.leads
        assertTrue("leads were $leads", org.chotki.core.scheduling.ReminderLead.ONE_HOUR in leads)
    }
}
