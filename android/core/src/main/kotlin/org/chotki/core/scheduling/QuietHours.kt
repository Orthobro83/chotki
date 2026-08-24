package org.chotki.core.scheduling

import kotlinx.serialization.Serializable
import org.chotki.core.TimeOfDay

/**
 * The window in which the app will not send notifications.
 *
 * Exists so that an untimed rule repeating hourly cannot wake the user at 3am.
 * The window normally wraps midnight (21:30 to 06:30), so containment is not a
 * simple range check.
 */
@Serializable
data class QuietHours(val start: TimeOfDay, val end: TimeOfDay) {

    companion object {
        /** 21:30 to 06:30. */
        val DEFAULT = QuietHours(TimeOfDay.of(21, 30)!!, TimeOfDay.of(6, 30)!!)
    }

    /**
     * `start == end` means no quiet window at all, not a 24-hour one. A user who
     * sets both to the same time wants notifications, not silence.
     */
    val isDisabled: Boolean get() = start == end

    /** True when the window runs through midnight. */
    val wrapsMidnight: Boolean get() = end < start

    /**
     * Start is inclusive, end is exclusive — so a rule due exactly at the end of
     * quiet hours fires rather than being held for another hour.
     */
    fun contains(time: TimeOfDay): Boolean {
        if (isDisabled) return false
        val t = time.minutesSinceMidnight
        val s = start.minutesSinceMidnight
        val e = end.minutesSinceMidnight
        return if (wrapsMidnight) t >= s || t < e else t in s until e
    }
}
