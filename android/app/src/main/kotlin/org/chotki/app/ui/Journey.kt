package org.chotki.app.ui

import org.chotki.core.Rule
import org.chotki.core.Weekday
import java.util.UUID

/**
 * Everywhere the app can be, as values rather than as a handful of booleans.
 *
 * Made explicit so that going back can mean something. With the screens held as
 * separate flags there was nowhere for "the place before this one" to live, so
 * the system back button fell through to Android's default — which is to leave
 * the app, whether you were reading a prayer or three fields into the editor.
 */
sealed interface Screen {
    /** The start destination. Back from here leaves the app, as it should. */
    data object Day : Screen
    /** The kathismata appointed for the day. */
    data object Psalter : Screen

    data object Library : Screen
    /**
     * [rule] is an existing rule being changed. [startingFrom] is a new one
     * filled in from a library template and not yet saved — taking something on
     * is a decision about how often, so it is asked before the rule lands on
     * the day rather than after.
     */
    data class Editor(val rule: Rule?, val startingFrom: Rule? = null) : Screen
    data class RulePrayers(val ruleID: UUID) : Screen
    data object Rope : Screen
    data object Reading : Screen
    data object Progress : Screen
    data class Terms(val slug: String? = null) : Screen
    /**
     * The seven questions and the journal of answers.
     *
     * A screen under Rule rather than a seventh bar item: six is already what
     * the bar carries, and this is reached the way the Psalter is — from the
     * rule that names it on the day, and from Settings for browsing.
     *
     * [weekday] is the day to open on. Tapping the way through from Tuesday's
     * rule should land on Tuesday's question rather than at the top of a
     * seven-day scroll; null opens at the top, which is what Settings wants.
     */
    data class Reflections(val weekday: Weekday? = null) : Screen
    data object Settings : Screen

    /** Which bar item is lit while this screen is showing. */
    val place: Place
        get() = when (this) {
            Day, Library, is Editor, is RulePrayers, is Reflections -> Place.RULE
            Rope, Psalter -> Place.PRAYERS
            Reading -> Place.READING
            Progress -> Place.PROGRESS
            is Terms -> Place.GLOSSARY
            Settings -> Place.SETTINGS
        }
}

/**
 * Where the app has been, so back can go back one step.
 *
 * Bottom-bar destinations replace rather than pile up: tapping through Reading,
 * Progress and Glossary should not mean three presses to get out. That is the
 * platform's convention — back from a secondary destination returns to the start
 * one — and it is also what stops the stack growing without limit while someone
 * browses.
 */
data class Journey(val stack: List<Screen> = listOf(Screen.Day)) {

    val current: Screen get() = stack.last()

    /** True when back has somewhere to go. False means the app should close. */
    val canGoBack: Boolean get() = stack.size > 1

    fun push(screen: Screen): Journey = copy(stack = stack + screen)

    fun back(): Journey = if (canGoBack) copy(stack = stack.dropLast(1)) else this

    /**
     * A bar item. The start destination clears the stack; anything else sits
     * directly on top of it, so one press of back returns to the day.
     */
    fun go(place: Place): Journey = when (place) {
        Place.RULE -> Journey(listOf(Screen.Day))
        Place.PRAYERS -> Journey(listOf(Screen.Day, Screen.Rope))
        Place.READING -> Journey(listOf(Screen.Day, Screen.Reading))
        Place.PROGRESS -> Journey(listOf(Screen.Day, Screen.Progress))
        Place.GLOSSARY -> Journey(listOf(Screen.Day, Screen.Terms()))
        Place.SETTINGS -> Journey(listOf(Screen.Day, Screen.Settings))
    }
}
