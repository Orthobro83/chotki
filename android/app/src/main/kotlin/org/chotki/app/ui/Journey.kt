package org.chotki.app.ui

import org.chotki.core.Rule
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
    data object Library : Screen
    data class Editor(val rule: Rule?) : Screen
    data class RulePrayers(val ruleID: UUID) : Screen
    data object Rope : Screen
    data object Reading : Screen
    data object Progress : Screen
    data class Terms(val slug: String? = null) : Screen
    data object Settings : Screen

    /** Which bar item is lit while this screen is showing. */
    val place: Place
        get() = when (this) {
            Day, Library, is Editor, is RulePrayers -> Place.RULE
            Rope -> Place.PRAYERS
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
