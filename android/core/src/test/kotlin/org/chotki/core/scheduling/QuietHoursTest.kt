package org.chotki.core.scheduling

import kotlinx.serialization.json.Json
import org.chotki.core.NotificationAction
import org.chotki.core.NotificationRequest
import org.chotki.core.TimeOfDay
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun t(h: Int, m: Int): TimeOfDay = TimeOfDay.of(h, m)!!

/** Translated from suite "TimeOfDay". */
class TimeOfDayTest {

    @Test
    fun `rejects out-of-range values rather than throwing`() {
        assertNull(TimeOfDay.of(24, 0))
        assertNull(TimeOfDay.of(-1, 0))
        assertNull(TimeOfDay.of(0, 60))
        assertNotNull(TimeOfDay.of(23, 59))
        assertNotNull(TimeOfDay.of(0, 0))
    }

    @Test
    fun `orders by minutes since midnight`() {
        assertTrue(t(6, 29) < t(6, 30))
        assertTrue(t(6, 30) < t(21, 30))
        assertEquals(21 * 60 + 30, t(21, 30).minutesSinceMidnight)
    }
}

/** Translated from suite "QuietHours". */
class QuietHoursTest {

    // The default window wraps midnight, which is the case a naive range check
    // gets wrong.
    @Test
    fun `wrapping window covers late evening`() {
        val q = QuietHours.DEFAULT
        assertTrue(q.wrapsMidnight)
        assertTrue(q.contains(t(21, 30)))
        assertTrue(q.contains(t(23, 59)))
    }

    @Test
    fun `wrapping window covers the small hours`() {
        val q = QuietHours.DEFAULT
        assertTrue(q.contains(t(0, 0)))
        assertTrue(q.contains(t(3, 0))) // the 3am case this type exists to prevent
        assertTrue(q.contains(t(6, 29)))
    }

    @Test
    fun `wrapping window excludes the day, with an exclusive end`() {
        val q = QuietHours.DEFAULT
        assertTrue(!q.contains(t(6, 30))) // end exclusive: a 06:30 rule still fires
        assertTrue(!q.contains(t(12, 0)))
        assertTrue(!q.contains(t(21, 29)))
    }

    @Test
    fun `non-wrapping window behaves as a plain range`() {
        val q = QuietHours(t(9, 0), t(17, 0))
        assertTrue(!q.wrapsMidnight)
        assertTrue(q.contains(t(9, 0)))
        assertTrue(q.contains(t(16, 59)))
        assertTrue(!q.contains(t(17, 0)))
        assertTrue(!q.contains(t(8, 59)))
        assertTrue(!q.contains(t(23, 0)))
    }

    // Equal bounds mean "no quiet hours", not "silent all day". Backwards, this
    // would silence the app permanently.
    @Test
    fun `equal bounds disable the window entirely`() {
        val q = QuietHours(t(9, 0), t(9, 0))
        assertTrue(q.isDisabled)
        for (hour in 0 until 24) {
            assertTrue(!q.contains(t(hour, 0)), "silenced at $hour:00")
        }
    }

    @Test
    fun `survives a serialisation round trip`() {
        val q = QuietHours.DEFAULT
        val text = Json.encodeToString(QuietHours.serializer(), q)
        assertEquals(q, Json.decodeFromString(QuietHours.serializer(), text))
    }
}

/** Translated from suite "Notifier contract". */
class NotifierContractTest {

    // Guards the tone constraint: no guilt language reaches a banner.
    @Test
    fun `built-in action copy carries no guilt language`() {
        val forbidden = listOf("overdue", "missed", "failed", "behind", "!")
        for (action in listOf(NotificationAction.MARK_COMPLETE, NotificationAction.SNOOZE)) {
            val title = action.title.lowercase()
            for (word in forbidden) {
                assertTrue(!title.contains(word), "${action.title} contains $word")
            }
        }
    }

    @Test
    fun `request identity is stable so every reminder can be cancelled together`() {
        val r = NotificationRequest(
            id = "rule-7:2026-08-19",
            title = "Evening prayers",
            body = "At 21:30",
            actions = listOf(NotificationAction.MARK_COMPLETE, NotificationAction.SNOOZE),
        )
        assertEquals("rule-7:2026-08-19", r.id)
        assertEquals(2, r.actions.size)
    }
}
