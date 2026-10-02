package org.chotki.app.ui

import org.chotki.core.CalendarDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.DataInputStream
import java.io.File
import java.io.FileInputStream
import kotlin.math.abs
import kotlin.math.hypot

/**
 * The same crop the Mac card uses, checked against the packaged library rather
 * than against a device. A picture that rests on the wrong part of itself is
 * not something a screenshot of one day would catch.
 */
class SayingPanTest {
    private val library: File = File("../../macos/Sources/Chotki/Resources/sayings").canonicalFile

    @Test
    fun `the year of pictures is packaged, each with a subject`() {
        val names = sayingNames(library.resolve("order.txt").readText())
        val approved = approvedSayingFocus(library.resolve("approved-sources.json").readText())
        assertEquals(365, names.size)
        assertEquals(365, names.toSet().size)
        assertEquals((1..42).toSet(), curatedSayingFocus.keys)
        assertEquals((43..365).toSet(), approved.keys)
        assertTrue(curatedSayingFocus.values.all { it.x in 0f..1f && it.y in 0f..1f })
        assertTrue(approved.values.all { it.x in 0f..1f && it.y in 0f..1f })
        for (name in names) {
            assertTrue("missing $name", library.resolve(name.removePrefix("sayings/")).isFile)
            val focus = sayingFocus(name, approved)
            assertTrue(focus.x in 0f..1f && focus.y in 0f..1f)
        }
    }

    @Test
    fun `a civil year uses each picture once, and a leap year shares one day`() {
        val names = sayingNames(library.resolve("order.txt").readText())
        val year = CalendarDate.of(2026, 1, 1)!!
        val chosen = (0 until 365).map { sayingName(names, year.plusDays(it)) }
        assertEquals(365, chosen.toSet().size)
        assertEquals(names[1], sayingName(names, CalendarDate.of(2026, 1, 1)!!))
        assertEquals(names[0], sayingName(names, CalendarDate.of(2026, 12, 31)!!))
        assertEquals("sayings/260.jpg", sayingName(names, CalendarDate.of(2026, 9, 16)!!))
        assertEquals("sayings/286.jpg", sayingName(names, CalendarDate.of(2026, 10, 12)!!))
        val leapNewYear = sayingName(names, CalendarDate.of(2028, 1, 1)!!)
        assertEquals(leapNewYear, sayingName(names, CalendarDate.of(2028, 12, 31)!!))
    }

    @Test
    fun `a tall portrait rests on its face rather than at the top edge`() {
        val image = imageSize(library.resolve("22.jpg"))
        val viewport = PanSize(850f, 270f)
        val rendered = renderedSize(image, viewport)
        val focus = sayingFocus("sayings/22.jpg", emptyMap())
        val resting = restingOrigin(rendered, viewport, focus)
        assertTrue("the face should sit down in the pane, not at y=${resting.y}", resting.y < -20f)
        assertTrue(
            abs(resting.y + focus.y * rendered.height - viewport.height * 0.4f) < 1f,
        )
    }

    @Test
    fun `every picture drifts a short way, on a desktop pane and on the phone card`() {
        val names = sayingNames(library.resolve("order.txt").readText())
        val approved = approvedSayingFocus(library.resolve("approved-sources.json").readText())
        val panes = listOf(PanSize(850f, 270f), PanSize(370f, 235f), PanSize(411f, 220f))
        for (viewport in panes) {
            for (name in names) {
                val image = imageSize(library.resolve(name.removePrefix("sayings/")))
                val rendered = renderedSize(image, viewport)
                val end = restingOrigin(rendered, viewport, sayingFocus(name, approved))
                val start = startingOrigin(rendered, viewport, end, imageNumber(name))
                val distance = hypot((start.x - end.x).toDouble(), (start.y - end.y).toDouble())
                assertTrue(
                    "motion outside the subtle range for $name at ${viewport.width.toInt()}×${viewport.height.toInt()}: $distance",
                    distance >= 10.0 && distance <= 23.0,
                )
                assertTrue(start.x <= 0f && start.x >= viewport.width - rendered.width)
                assertTrue(start.y <= 0f && start.y >= viewport.height - rendered.height)
                assertTrue(end.x <= 0f && end.x >= viewport.width - rendered.width)
                assertTrue(end.y <= 0f && end.y >= viewport.height - rendered.height)
            }
        }
    }

    @Test
    fun `today's drift is remembered, and another day's is not stored`() {
        val store = MemoryStore()
        val first = SayingPanTimeline()
        val started = first.start("2026-10-02", "sayings/22.jpg", persist = true, now = 1_000L, store = store)
        assertEquals(1_000L, started)
        assertEquals(1_000L, first.start("2026-10-02", "sayings/22.jpg", persist = true, now = 9_000L, store = store))

        val resumed = SayingPanTimeline()
        assertEquals(1_000L, resumed.start("2026-10-02", "sayings/22.jpg", persist = true, now = 5_000L, store = store))

        val browsing = SayingPanTimeline()
        assertEquals(7_000L, browsing.start("2026-10-01", "sayings/21.jpg", persist = false, now = 7_000L, store = store))
        assertNull(store.read("pan3-2026-10-01-sayings/21.jpg"))
        assertEquals(7_000L, browsing.start("2026-10-01", "sayings/21.jpg", persist = false, now = 8_000L, store = store))
    }

    private class MemoryStore : PanStartStore {
        private val saved = HashMap<String, Long>()
        override fun read(identity: String): Long? = saved[identity]
        override fun write(identity: String, startedAt: Long) {
            saved[identity] = startedAt
        }
    }
}

private fun imageSize(file: File): PanSize {
    DataInputStream(FileInputStream(file)).use { input ->
        val kind = input.readUnsignedByte()
        if (kind == 0x89) return pngSize(input)
        if (kind == 0xFF) return jpegSize(input)
        error("not a picture: ${file.name}")
    }
}

private fun pngSize(input: DataInputStream): PanSize {
    input.skipBytes(7 + 8)
    return PanSize(input.readInt().toFloat(), input.readInt().toFloat())
}

private fun jpegSize(input: DataInputStream): PanSize {
    check(input.readUnsignedByte() == 0xD8)
    while (true) {
        var marker = input.readUnsignedByte()
        while (marker != 0xFF) marker = input.readUnsignedByte()
        do {
            marker = input.readUnsignedByte()
        } while (marker == 0xFF)
        if (marker == 0xD9) break
        if (marker in 0xD0..0xD7 || marker == 0x01) continue
        val length = input.readUnsignedShort()
        if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
            input.readUnsignedByte()
            val height = input.readUnsignedShort()
            val width = input.readUnsignedShort()
            return PanSize(width.toFloat(), height.toFloat())
        }
        input.skipBytes(length - 2)
    }
    error("jpeg has no frame")
}
