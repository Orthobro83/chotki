package org.chotki.core

/** Supplies church-calendar facts to the recurrence engine. */
interface LiturgicalDayProvider {
    fun isFastDay(date: CalendarDate): Boolean
    fun isGreatFeast(date: CalendarDate): Boolean
    fun season(date: CalendarDate): FastingSeason?

    /**
     * Why a fast that would otherwise fall on this day is not kept, if it is
     * not. The Church lifts the weekly fast in several stretches of the year.
     * Providers that know nothing about dispensations simply have none.
     */
    fun fastFreeReason(date: CalendarDate): String? = null
}

/**
 * Answers "no" to everything. Used where a rule has no liturgical component, and
 * in tests of the civil recurrence paths.
 */
object NoLiturgicalData : LiturgicalDayProvider {
    override fun isFastDay(date: CalendarDate): Boolean = false
    override fun isGreatFeast(date: CalendarDate): Boolean = false
    override fun season(date: CalendarDate): FastingSeason? = null
    override fun fastFreeReason(date: CalendarDate): String? = null
}
