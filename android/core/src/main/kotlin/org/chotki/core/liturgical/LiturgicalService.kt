package org.chotki.core.liturgical

import org.chotki.core.CalendarDate
import org.chotki.core.FastingSeason
import org.chotki.core.Jurisdiction
import org.chotki.core.LiturgicalDay
import org.chotki.core.LiturgicalDayProvider
import org.chotki.core.store.Store
import java.time.Instant

/**
 * Cache-first access to the church calendar.
 *
 * Two rules govern this type. The network is only ever a refill — every read is
 * answered from cache, so opening the app on a plane shows the day rather than a
 * spinner. And [LiturgicalDayProvider] conformance is **synchronous**: the
 * recurrence engine asks whether a day is a fast and gets an answer immediately,
 * from an in-memory snapshot, never a suspend.
 */
class LiturgicalService(
    private val store: Store,
    private val client: OrthocalClient? = null,
    jurisdiction: Jurisdiction = Jurisdiction.DEFAULT,
) : LiturgicalDayProvider {

    private val lock = Any()

    private var currentJurisdiction: Jurisdiction = jurisdiction

    /**
     * Snapshot of the cache for the current reckoning, so the synchronous
     * provider methods never touch SQLite on a hot path.
     */
    private val snapshot = mutableMapOf<CalendarDate, LiturgicalDay>()
    private val knownAbsent = mutableSetOf<CalendarDate>()
    private var lastRefreshFailed = false
    private var lastSuccessfulRefresh: Instant? = null

    val jurisdiction: Jurisdiction get() = synchronized(lock) { currentJurisdiction }

    /**
     * True when the last attempt to reach orthocal failed. The interface uses
     * this to mark content as cached — never to show an error where text should
     * be.
     */
    val isOffline: Boolean get() = synchronized(lock) { lastRefreshFailed }

    fun lastRefresh(): Instant? = synchronized(lock) { lastSuccessfulRefresh }

    // MARK: jurisdiction

    /**
     * Cached days for the previous reckoning are kept rather than deleted: a
     * Julian day remains a correct Julian day, so switching back is instant and
     * costs no requests. Only the snapshot re-targets.
     */
    fun setJurisdiction(jurisdiction: Jurisdiction, around: CalendarDate, window: Int = 14) {
        synchronized(lock) {
            currentJurisdiction = jurisdiction
            snapshot.clear()
            // Both caches are keyed by civil date but hold answers for one
            // reckoning. Keeping the misses would make every day look absent
            // after a switch from Old to New calendar.
            knownAbsent.clear()
        }
        loadSnapshot(around, window)
    }

    // MARK: cache

    /** Pull the cached window into memory. Call on launch and after a refresh. */
    fun loadSnapshot(around: CalendarDate, window: Int = 14) {
        val reckoning = jurisdiction.reckoning
        val days = store.liturgicalDays(reckoning, around.plusDays(-window), around.plusDays(window))
        synchronized(lock) {
            for (day in days) {
                snapshot[day.civilDate] = day
                knownAbsent.remove(day.civilDate)
            }
        }
    }

    fun cachedDay(date: CalendarDate): LiturgicalDay? {
        synchronized(lock) { snapshot[date] }?.let { return it }
        // A month grid asks about forty-two days on every redraw, and most of
        // them fall outside the cached window. Without remembering the misses,
        // each redraw ran forty-two queries that were always going to find
        // nothing. Cleared whenever new days arrive or the reckoning changes.
        if (synchronized(lock) { date in knownAbsent }) return null

        val found = runCatching { store.liturgicalDay(date, jurisdiction.reckoning) }.getOrNull()
        synchronized(lock) {
            if (found != null) snapshot[date] = found else knownAbsent.add(date)
        }
        return found
    }

    /**
     * Fetch the window ahead, skipping anything already cached.
     *
     * Never throws. A failed refresh is a state the interface reflects, not an
     * error the user is shown — the app carries on with what it has.
     */
    fun refresh(from: CalendarDate, days: Int = 14, now: Instant = Instant.now()): Int {
        val client = this.client ?: return 0
        val reckoning = jurisdiction.reckoning
        var fetched = 0
        var anyFailure = false

        for (offset in 0 until days) {
            val date = from.plusDays(offset)
            if (cachedDay(date) != null) continue
            try {
                val day = client.day(date, reckoning, now)
                store.saveLiturgicalDay(day)
                synchronized(lock) {
                    snapshot[date] = day
                    knownAbsent.remove(date)
                }
                fetched += 1
            } catch (_: Exception) {
                anyFailure = true
            }
        }

        synchronized(lock) {
            lastRefreshFailed = anyFailure
            if (!anyFailure) lastSuccessfulRefresh = now
        }
        return fetched
    }

    // MARK: LiturgicalDayProvider

    override fun isFastDay(date: CalendarDate): Boolean = cachedDay(date)?.isFast ?: false
    override fun isGreatFeast(date: CalendarDate): Boolean = cachedDay(date)?.isGreatFeast ?: false
    override fun season(date: CalendarDate): FastingSeason? = cachedDay(date)?.season
    override fun fastFreeReason(date: CalendarDate): String? = cachedDay(date)?.fastFreeReason
}
