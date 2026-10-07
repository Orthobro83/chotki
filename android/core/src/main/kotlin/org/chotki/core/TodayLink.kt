package org.chotki.core

/**
 * The link back to today that the calendar shows once it has been moved away from it.
 *
 * Away in the future, the link points back, on the left: "← Today". Away in the past, it points
 * forward, on the right: "Today →". On today it is not there at all. Ported from `TodayLink.swift`;
 * the decision is here so every platform puts the link on the same side.
 */
enum class TodayLink(val text: String) {
    /** Today is earlier than where the calendar is: shown on the left. */
    OnTheLeft("← Today"),

    /** Today is later than where the calendar is: shown on the right. */
    OnTheRight("Today →");

    companion object {
        /**
         * @param selected the day the calendar has selected.
         * @param visibleMonth the month showing; only looked at while the whole month is open.
         * @param monthOpen whether the whole month, rather than the week, is showing.
         */
        fun needed(
            selected: CalendarDate,
            today: CalendarDate,
            visibleMonth: CalendarDate,
            monthOpen: Boolean,
        ): TodayLink? {
            var reference = selected
            if (selected == today && monthOpen &&
                (visibleMonth.year != today.year || visibleMonth.month != today.month)
            ) {
                reference = CalendarDate.of(visibleMonth.year, visibleMonth.month, 1) ?: visibleMonth
            }
            if (reference == today) return null
            return if (reference > today) OnTheLeft else OnTheRight
        }
    }
}
