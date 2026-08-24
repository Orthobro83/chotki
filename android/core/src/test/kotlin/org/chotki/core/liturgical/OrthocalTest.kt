package org.chotki.core.liturgical

import org.chotki.core.CalendarDate
import org.chotki.core.FastingSeason
import org.chotki.core.LiturgicalDay
import org.chotki.core.Reckoning
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal fun fixture(name: String): String =
    OrthocalTest::class.java.getResourceAsStream("/fixtures/$name.json")
        ?.bufferedReader()?.readText()
        ?: error("no fixture $name")

private val recordedAt: Instant = Instant.parse("2026-08-19T09:00:00Z")

internal fun decodeFixture(
    name: String,
    civil: CalendarDate,
    reckoning: Reckoning,
): LiturgicalDay = OrthocalClient.decode(fixture(name), civil, reckoning, recordedAt)

/** Recorded responses from orthocal.info, decoded. Translated from "Orthocal decoding". */
class OrthocalTest {

    private fun d(y: Int, m: Int, day: Int) = CalendarDate.of(y, m, day)!!

    // The trap the whole cache design exists for: the URL takes a civil date and
    // the body answers in the requested reckoning. Keying on the reported date
    // would misfile every Old Calendar day by thirteen days.
    @Test
    fun `the reported date is not the date asked for`() {
        val day = decodeFixture("julian-2027-01-13", d(2027, 1, 13), Reckoning.JULIAN)
        assertEquals(d(2027, 1, 13), day.civilDate, "the key is the day the user is living")
        assertEquals(d(2026, 12, 31), day.observedDate, "and the body answers thirteen days back")
    }

    @Test
    fun `the new calendar reports the date it was asked for`() {
        val day = decodeFixture("gregorian-2027-01-13", d(2027, 1, 13), Reckoning.REVISED_JULIAN)
        assertEquals(day.civilDate, day.observedDate)
    }

    @Test
    fun `the same civil day differs between the reckonings`() {
        val julian = decodeFixture("julian-2026-08-19", d(2026, 8, 19), Reckoning.JULIAN)
        val revised = decodeFixture("gregorian-2026-08-19", d(2026, 8, 19), Reckoning.REVISED_JULIAN)

        assertEquals(FastingSeason.DORMITION_FAST, julian.season, "the Old Calendar is in the fast")
        assertNull(revised.season, "the New Calendar is not")
        assertTrue(julian.isGreatFeast, "and keeps the Transfiguration that day")
        assertTrue(!revised.isGreatFeast)
    }

    @Test
    fun `fast levels map to the seasons`() {
        assertEquals(
            FastingSeason.APOSTLES_FAST,
            decodeFixture("julian-2026-06-20", d(2026, 6, 20), Reckoning.JULIAN).season,
        )
        assertEquals(
            FastingSeason.NATIVITY_FAST,
            decodeFixture("julian-2026-12-25", d(2026, 12, 25), Reckoning.JULIAN).season,
        )
        assertEquals(
            FastingSeason.DORMITION_FAST,
            decodeFixture("julian-2026-08-19", d(2026, 8, 19), Reckoning.JULIAN).season,
        )
        // Level 1 is the weekly fast, which is not a season.
        assertNull(decodeFixture("gregorian-2026-08-19", d(2026, 8, 19), Reckoning.REVISED_JULIAN).season)
    }

    @Test
    fun `Pascha is a great feast and fast-free`() {
        val pascha = decodeFixture("gregorian-2026-04-12", d(2026, 4, 12), Reckoning.REVISED_JULIAN)
        assertTrue(pascha.isGreatFeast)
        assertTrue(pascha.isFastFree)
        assertTrue(!pascha.isFast)
        assertEquals(0, pascha.paschaDistance)
    }

    @Test
    fun `the days between the feasts are named as such`() {
        val day = decodeFixture("julian-2027-01-13", d(2027, 1, 13), Reckoning.JULIAN)
        assertTrue(day.isFastFree)
        assertEquals("the days between the Nativity and Theophany", day.fastFreeReason)
    }

    @Test
    fun `an ordinary fast day has no dispensation`() {
        val day = decodeFixture("gregorian-2026-08-19", d(2026, 8, 19), Reckoning.REVISED_JULIAN)
        assertTrue(day.isFast)
        assertNull(day.fastFreeReason, "a fast day is not a fast-free day")
    }

    @Test
    fun `readings come through with their text`() {
        val day = decodeFixture("gregorian-2026-04-12", d(2026, 4, 12), Reckoning.REVISED_JULIAN)
        assertTrue(day.readings.isNotEmpty())
        assertTrue(day.readings.all { it.display.isNotEmpty() })
        assertTrue(day.readings.any { it.text.isNotEmpty() }, "the passages are empty")
    }

    @Test
    fun `titles and descriptions survive`() {
        val day = decodeFixture("julian-2026-08-28", d(2026, 8, 28), Reckoning.JULIAN)
        assertNotNull(day.title)
        assertTrue(day.fastLevelDescription.isNotEmpty())
        assertTrue(day.feastLevelDescription.isNotEmpty())
        assertEquals(recordedAt, day.fetchedAt)
    }

    // The wording describes what the calendar marks; it never instructs.
    @Test
    fun `a relaxed fast reads as the fast plus the relaxation`() {
        val day = decodeFixture("julian-2026-06-20", d(2026, 6, 20), Reckoning.JULIAN)
        assertTrue(day.isFast)
        assertTrue(day.fastDescription.contains("—"), "got: ${day.fastDescription}")
        assertTrue(day.fastDescription.startsWith(day.fastLevelDescription))
    }

    @Test
    fun `the url takes a civil date and the right endpoint`() {
        val client = OrthocalClient({ error("no network in tests") }, host = "https://example.test")
        assertEquals(
            "https://example.test/api/julian/2027/1/13/",
            client.url(d(2027, 1, 13), Reckoning.JULIAN),
        )
        assertEquals(
            "https://example.test/api/gregorian/2027/1/13/",
            client.url(d(2027, 1, 13), Reckoning.REVISED_JULIAN),
            "orthocal calls the New Calendar gregorian",
        )
    }

    @Test
    fun `a day is stale after a month and not before`() {
        val day = decodeFixture("gregorian-2026-08-19", d(2026, 8, 19), Reckoning.REVISED_JULIAN)
        assertTrue(!day.isStale(recordedAt.plusSeconds(60L * 60 * 24 * 29)))
        assertTrue(day.isStale(recordedAt.plusSeconds(60L * 60 * 24 * 31)))
    }
}
