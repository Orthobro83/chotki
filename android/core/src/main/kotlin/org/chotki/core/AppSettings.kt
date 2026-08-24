package org.chotki.core

import kotlinx.serialization.Serializable

/**
 * Everything the user can change, in one serialisable value.
 *
 * Lives in core so the settings someone has chosen move with their data rather
 * than being tied to one platform's preferences system.
 *
 * Incomplete on purpose. `jurisdiction` arrives with the liturgical layer at
 * phase 6 and `reminders` with the scheduler at phase 7; what is here is what
 * the ported code actually reads. Every field is optional at the boundary and
 * defaults when absent, which is the property that matters: the Swift version
 * threw on a missing key, so each new setting made every record written before
 * it unreadable, and this app has already lost someone's settings once.
 */
@Serializable
data class AppSettings(
    val observances: ObservanceSettings = ObservanceSettings.DEFAULT,
    /** Cleared once the first rules have been taken on. */
    val hasCompletedFirstRun: Boolean = false,
    val clockStyle: ClockStyle = ClockStyle.TWENTY_FOUR_HOUR,
) {
    companion object {
        val DEFAULT = AppSettings()
    }
}
