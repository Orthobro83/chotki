package org.chotki.core.liturgical

import org.chotki.core.CalendarDate
import org.chotki.core.Pascha
import org.chotki.core.Reckoning
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int) = CalendarDate.of(y, m, day)!!

private fun fnv1a(data: ByteArray, seed: ULong): ULong {
    var h = seed
    for (b in data) { h = h xor (b.toULong() and 0xFFu); h *= 0x100000001b3uL }
    return h
}

/** Translated from Swift's "The bundled calendar": the same bytes, held to the same digests. */
class BundledCalendarTest {

    private val bundle = assertNotNull(BundledCalendar.standard)

    private val allDates: List<CalendarDate>
        get() = generateSequence(bundle.first) { if (it < bundle.last) it.plusDays(1) else null }.toList()

    @Test
    fun `it covers the five-year window and says where it came from`() {
        assertEquals(d(2026, 1, 1), bundle.first)
        assertEquals(d(2031, 12, 31), bundle.last)
        assertEquals(1, bundle.manifest.schema)
        assertEquals("slavic", bundle.manifest.tradition)
        assertEquals(40, bundle.manifest.orthocalCommit.length)
        assertEquals(12, bundle.manifest.files.size)
        assertTrue(bundle.covers(d(2028, 2, 29)))
        assertFalse(bundle.covers(d(2025, 12, 31)))
        assertFalse(bundle.covers(d(2032, 1, 1)))
    }

    @Test
    fun `every day of the window is there, under both reckonings, filed under its civil date`() {
        for (reckoning in Reckoning.entries) for (date in allDates) {
            val day = bundle.day(date, reckoning)
            assertEquals(date, day?.civilDate, "$reckoning $date")
            assertEquals(reckoning, day?.reckoning)
        }
        assertNull(bundle.day(d(2032, 1, 1), Reckoning.JULIAN))
        assertNull(bundle.day(d(2025, 12, 31), Reckoning.JULIAN))
    }

    @Test
    fun `the Old Calendar is thirteen days behind, and both reckonings agree on Pascha`() {
        for (date in allDates) {
            val julian = assertNotNull(bundle.day(date, Reckoning.JULIAN))
            val revised = assertNotNull(bundle.day(date, Reckoning.REVISED_JULIAN))
            assertEquals(date.plusDays(-13), julian.observedDate, "$date")
            assertEquals(date, revised.observedDate, "$date")
            assertEquals(julian.paschaDistance, revised.paschaDistance, "$date")
            assertEquals(Pascha.distance(date), julian.paschaDistance, "$date")
        }
    }

    @Test
    fun `every reading has scripture, with no pilcrow, stray space or run of blank lines`() {
        var readings = 0
        var composites = 0
        for (reckoning in Reckoning.entries) for (date in allDates) {
            val day = assertNotNull(bundle.day(date, reckoning))
            for (reading in day.readings) {
                readings += 1
                if (reading.display.startsWith("Composite")) composites += 1
                assertTrue(reading.text.isNotEmpty(), "$date ${reading.display}")
                assertFalse(reading.text.contains("¶"))
                assertFalse(reading.text.contains("\n\n\n"))
                assertEquals(reading.text.trim(), reading.text)
            }
        }
        assertEquals(17_437, readings)
        assertEquals(612, composites)
    }

    @Test
    fun `the text resolves exactly as the bundle builder computed it (digest)`() {
        var h = 0xcbf29ce484222325uL
        for (reckoning in Reckoning.entries) for (date in allDates) {
            val day = assertNotNull(bundle.day(date, reckoning))
            for (reading in day.readings) {
                h = fnv1a(reading.text.toByteArray(Charsets.UTF_8), h)
                h = fnv1a(byteArrayOf(0x1f), h)
            }
        }
        assertEquals(bundle.manifest.textDigest, "%016x".format(h.toLong()))
    }

    @Test
    fun `every field of every day matches the audited source it was built from (digest)`() {
        var h = 0xcbf29ce484222325uL
        for (reckoning in Reckoning.entries) for (date in allDates) {
            val day = assertNotNull(bundle.day(date, reckoning))
            val o = day.observedDate
            val parts = mutableListOf(
                "%04d-%02d-%02d".format(o.year, o.month, o.day),
                day.tone?.toString() ?: "-",
                day.title ?: "-",
                day.summaryTitle,
                day.saints.joinToString("|"), day.feasts.joinToString("|"),
                day.fastLevel.toString(), day.fastLevelDescription, day.fastException.toString(),
                day.fastExceptionDescription ?: "-",
                day.abstentions.joinToString("|"),
                day.feastLevel.toString(), day.feastLevelDescription, day.paschaDistance.toString(),
            )
            parts += day.readings.map { "${it.source}\u001d${it.display}\u001d${it.shortDisplay}" }
            h = fnv1a(parts.joinToString("\u001e").toByteArray(Charsets.UTF_8), h)
            h = fnv1a(byteArrayOf(0x1f), h)
        }
        assertEquals(bundle.manifest.fieldsDigest, "%016x".format(h.toLong()))
    }

    @Test
    fun `the bundled day equals the day decoded from each recorded API response`() {
        val names = listOf(
            "gregorian-2026-04-12", "gregorian-2026-08-19", "gregorian-2026-08-28", "gregorian-2027-01-13",
            "julian-2026-04-12", "julian-2026-06-20", "julian-2026-08-19", "julian-2026-08-28",
            "julian-2026-12-25", "julian-2027-01-13",
        )
        for (stem in names) {
            val parts = stem.split("-", limit = 2)
            val reckoning = if (parts[0] == "julian") Reckoning.JULIAN else Reckoning.REVISED_JULIAN
            val date = assertNotNull(CalendarDate.parse(parts[1]))
            val recorded = decodeFixture(stem, date, reckoning)
            val shipped = assertNotNull(bundle.day(date, reckoning), stem)

            assertEquals(recorded.observedDate, shipped.observedDate, stem)
            assertEquals(recorded.tone, shipped.tone)
            assertEquals(recorded.title, shipped.title)
            assertEquals(recorded.feasts, shipped.feasts)
            assertEquals(recorded.fastLevel, shipped.fastLevel)
            assertEquals(recorded.fastLevelDescription, shipped.fastLevelDescription)
            assertEquals(recorded.fastException, shipped.fastException)
            assertEquals(recorded.fastExceptionDescription, shipped.fastExceptionDescription)
            assertEquals(recorded.abstentions, shipped.abstentions)
            assertEquals(recorded.feastLevel, shipped.feastLevel)
            assertEquals(recorded.feastLevelDescription, shipped.feastLevelDescription)
            assertEquals(recorded.paschaDistance, shipped.paschaDistance)
            // Upstream has added commemorations since some of these were recorded, never removed any.
            assertTrue(shipped.saints.toSet().containsAll(recorded.saints), stem)
            if (shipped.saints == recorded.saints) assertEquals(recorded.summaryTitle, shipped.summaryTitle, stem)
            assertEquals(recorded.readings.size, shipped.readings.size, stem)
            for ((a, b) in shipped.readings.zip(recorded.readings)) {
                assertEquals(b.source, a.source); assertEquals(b.display, a.display); assertEquals(b.shortDisplay, a.shortDisplay)
                // Both paths join the same keyed verses by the same paragraph rule.
                if (!a.display.startsWith("Composite")) assertEquals(b.text, a.text, "$stem ${a.display}")
            }
        }
    }

    // The files are the Swift core's, byte for byte; a Swift test holds them there too.
    @Test
    fun `the shipped files are identical to the Swift core's`() {
        val swift = java.io.File("../../core/Sources/ChotkiCore/Resources/calendar")
        if (!swift.isDirectory) return                       // a checkout without the Swift core
        val names = swift.listFiles { f -> f.name.endsWith(".json") }!!.map { it.name }
        assertEquals(16, names.size)
        for (name in names) {
            val ours = BundledCalendar::class.java.getResourceAsStream("/calendar/$name")!!.use { it.readBytes() }
            assertTrue(java.io.File(swift, name).readBytes().contentEquals(ours), "$name has drifted from the Swift core")
        }
    }
}
