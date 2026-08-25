package org.chotki.app

import org.chotki.app.ui.Journey
import org.chotki.app.ui.Place
import org.chotki.app.ui.Screen
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Where back goes, decided as a value rather than discovered on a device.
 *
 * The behaviour this covers was reported in use: back took you to the wrong
 * place, or straight out of the app. Both had the same cause — the screens were
 * separate flags with nowhere for "the place before this one" to live.
 *
 * Kept off the device on purpose. Asserting that back from the day *closes* the
 * app means finishing the activity, and doing that mid-suite crashed the
 * instrumentation runner for every test that ran after it.
 */
class JourneyTest {

    @Test
    fun `it starts on the day`() {
        assertEquals(Screen.Day, Journey().current)
        assertEquals(Place.RULE, Journey().current.place)
    }

    // The part that was never wrong: from the start destination, back leaves.
    @Test
    fun `there is nowhere back to go from the day`() {
        assertTrue("back from the day should close the app", !Journey().canGoBack)
        assertEquals("and going back changes nothing", Journey(), Journey().back())
    }

    @Test
    fun `back returns one step, whatever the depth`() {
        val journey = Journey()
            .push(Screen.Library)
            .push(Screen.Editor(null))
        assertTrue(journey.current is Screen.Editor)

        val once = journey.back()
        assertEquals("it skipped a step or jumped out", Screen.Library, once.current)

        val twice = once.back()
        assertEquals(Screen.Day, twice.current)
        assertTrue(!twice.canGoBack)
    }

    @Test
    fun `a bar destination sits directly on the day`() {
        for (place in Place.entries - Place.RULE) {
            val journey = Journey().go(place)
            assertEquals(place, journey.current.place)
            assertTrue("$place cannot be backed out of", journey.canGoBack)
            assertEquals("back from $place", Screen.Day, journey.back().current)
        }
    }

    // Glancing at three places must not cost three presses to leave.
    @Test
    fun `bar destinations replace rather than pile up`() {
        val journey = Journey()
            .go(Place.READING)
            .go(Place.PROGRESS)
            .go(Place.GLOSSARY)
        assertEquals(2, journey.stack.size)
        assertEquals(Screen.Day, journey.back().current)
    }

    @Test
    fun `the day clears whatever was open`() {
        val journey = Journey().push(Screen.Library).push(Screen.Editor(null)).go(Place.RULE)
        assertEquals(listOf(Screen.Day), journey.stack)
        assertTrue(!journey.canGoBack)
    }

    // A term is a step of its own, so back returns to the list rather than
    // jumping out of the glossary altogether.
    @Test
    fun `a term opened from the glossary is its own step`() {
        val journey = Journey().go(Place.GLOSSARY).push(Screen.Terms("amen"))
        assertEquals(Screen.Terms("amen"), journey.current)

        val back = journey.back()
        assertEquals("it left the glossary entirely", Screen.Terms(null), back.current)
        assertEquals(Place.GLOSSARY, back.current.place)
    }

    @Test
    fun `every screen lights the right bar item`() {
        assertEquals(Place.RULE, Screen.Library.place)
        assertEquals(Place.RULE, Screen.Editor(null).place)
        assertEquals(Place.RULE, Screen.RulePrayers(UUID.randomUUID()).place)
        assertEquals(Place.PRAYERS, Screen.Rope.place)
        assertEquals(Place.READING, Screen.Reading.place)
        assertEquals(Place.PROGRESS, Screen.Progress.place)
        assertEquals(Place.GLOSSARY, Screen.Terms("amen").place)
        assertEquals(Place.SETTINGS, Screen.Settings.place)
    }

    // Editing a rule from the day should come back to the day; from the library,
    // to the library. The stack is what makes that fall out rather than needing
    // a rule of its own.
    @Test
    fun `the editor returns to wherever it was opened from`() {
        val fromTheDay = Journey().push(Screen.Editor(null))
        assertEquals(Screen.Day, fromTheDay.back().current)

        val fromTheLibrary = Journey().push(Screen.Library).push(Screen.Editor(null))
        assertEquals(Screen.Library, fromTheLibrary.back().current)
    }
}
