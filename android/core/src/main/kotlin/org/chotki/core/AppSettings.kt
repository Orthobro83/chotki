package org.chotki.core

import kotlinx.serialization.Serializable

/**
 * Everything the user can change, in one serialisable value.
 *
 * Lives in core so the settings someone has chosen move with their data rather
 * than being tied to one platform's preferences system.
 *
 * `reminders` arrives with the scheduler at phase 7; everything else the ported
 * code reads is here. Every field has a default, which is the property that
 * matters: the Swift version threw on a missing key, so each new setting made
 * every record written before it unreadable, and this app has already lost
 * someone's settings once.
 */
@Serializable
data class AppSettings(
    val jurisdiction: Jurisdiction = Jurisdiction.DEFAULT,
    val observances: ObservanceSettings = ObservanceSettings.DEFAULT,
    /** Cleared once the first rules have been taken on. */
    val hasCompletedFirstRun: Boolean = false,
    val clockStyle: ClockStyle = ClockStyle.TWENTY_FOUR_HOUR,
    /**
     * The day the calendar was last changed, if it ever was.
     *
     * Liturgical rules are the only ones whose due days come from outside the
     * app, and changing the reckoning moves them by thirteen days. Without this,
     * a fast kept faithfully under one calendar is re-scored against the other
     * and reads as a fortnight of failures — which the app must never be able to
     * say. Measured on the Swift side before it was fixed: fourteen kept and
     * none missed became one kept and thirteen missed. See [ScoringEngine].
     */
    val reckoningChangedOn: CalendarDate? = null,
) {
    companion object {
        val DEFAULT = AppSettings()
    }
}
