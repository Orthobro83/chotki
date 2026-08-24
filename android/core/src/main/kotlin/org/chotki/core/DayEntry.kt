package org.chotki.core

/** One rule on one day, with whatever has become of it. */
data class DayEntry(
    val rule: Rule,
    val date: CalendarDate,
    val occurrence: Occurrence?,
    /** Why the Church has lifted this rule today, if it has. */
    val dispensation: String?,
) {
    val id: String get() = "${rule.id}:${date.iso}"
    val status: OccurrenceStatus? get() = occurrence?.status
    val isKept: Boolean
        get() = status == OccurrenceStatus.COMPLETED || status == OccurrenceStatus.COMPLETED_LATE
    val isStoodDown: Boolean
        get() = status == OccurrenceStatus.SKIPPED || status == OccurrenceStatus.CANCELLED
    val isDispensed: Boolean get() = dispensation != null

    /**
     * Shown with a tick either way — but a dispensed day was never asked of
     * anyone, so it is not something they did.
     */
    val showsAsSatisfied: Boolean get() = isKept || isDispensed
}
