package org.chotki.core.liturgical

import org.chotki.core.CalendarDate
import org.chotki.core.Jurisdiction
import org.chotki.core.Reckoning
import org.chotki.core.store.JdbcDb
import org.chotki.core.store.SqliteStore
import java.time.Instant
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Translated from suite "Liturgical service". */
class LiturgicalServiceTest {

    private val db = JdbcDb.inMemory()
    private val store = SqliteStore(db)
    private val now = Instant.parse("2026-08-19T09:00:00Z")

    @AfterTest fun tearDown() = store.close()

    private fun d(y: Int, m: Int, day: Int) = CalendarDate.of(y, m, day)!!

    private val julianJurisdiction = Jurisdiction.of(
        "Georgian Orthodox Church", Reckoning.JULIAN, org.chotki.core.Tradition.GEORGIAN,
    )
    private val newCalendar = julianJurisdiction.copy(reckoning = Reckoning.REVISED_JULIAN)

    /** Answers from the recorded fixtures, and counts what it was asked for. */
    private class Recorded(private val answers: Map<String, String>) : HttpFetching {
        var calls = 0
            private set
        var failing = false

        override fun data(url: String): String {
            calls += 1
            if (failing) throw HttpException.Transport("no network")
            return answers[url] ?: throw HttpException.Status(404)
        }
    }

    private fun recorded(): Recorded = Recorded(
        mapOf(
            "https://example.test/api/julian/2026/8/19/" to fixture("julian-2026-08-19"),
            "https://example.test/api/julian/2026/8/28/" to fixture("julian-2026-08-28"),
            "https://example.test/api/gregorian/2026/8/19/" to fixture("gregorian-2026-08-19"),
        ),
    )

    private fun service(http: HttpFetching, jurisdiction: Jurisdiction = julianJurisdiction) =
        LiturgicalService(
            store,
            OrthocalClient(http, host = "https://example.test"),
            jurisdiction,
        )

    @Test
    fun `a fetched day is cached and answered without asking again`() {
        val http = recorded()
        val service = service(http)

        assertEquals(1, service.refresh(d(2026, 8, 19), days = 1, now = now))
        assertEquals(1, http.calls)

        // Second time round it is already there.
        assertEquals(0, service.refresh(d(2026, 8, 19), days = 1, now = now))
        assertEquals(1, http.calls, "it went back to the network for a day it had")
    }

    @Test
    fun `the cache survives a new service over the same store`() {
        service(recorded()).refresh(d(2026, 8, 19), days = 1, now = now)

        val fresh = service(recorded())
        fresh.loadSnapshot(d(2026, 8, 19))
        assertNotNull(fresh.cachedDay(d(2026, 8, 19)))
        assertTrue(fresh.isFastDay(d(2026, 8, 19)))
    }

    // The whole point: a read is answered from what is stored, so the app opens
    // on a plane showing the day rather than a spinner.
    @Test
    fun `a failed refresh is a state, not an error`() {
        val http = recorded().also { it.failing = true }
        val service = service(http)

        assertEquals(0, service.refresh(d(2026, 8, 19), days = 2, now = now), "it must not throw")
        assertTrue(service.isOffline)
        assertNull(service.lastRefresh())
    }

    @Test
    fun `a successful refresh clears the offline mark`() {
        val http = recorded()
        val service = service(http)
        http.failing = true
        service.refresh(d(2026, 8, 19), days = 1, now = now)
        assertTrue(service.isOffline)

        http.failing = false
        service.refresh(d(2026, 8, 19), days = 1, now = now)
        assertTrue(!service.isOffline)
        assertEquals(now, service.lastRefresh())
    }

    // A day cached under one reckoning is not an answer for the other. Keeping
    // the remembered absences across a switch made every day look absent.
    @Test
    fun `switching the calendar does not answer from the other one`() {
        val http = recorded()
        val service = service(http)
        service.refresh(d(2026, 8, 19), days = 1, now = now)
        assertTrue(service.isFastDay(d(2026, 8, 19)), "the Old Calendar is in the Dormition Fast")

        service.setJurisdiction(newCalendar, around = d(2026, 8, 19))
        assertNull(
            service.cachedDay(d(2026, 8, 19)),
            "the Julian day was served as though it were a Revised Julian one",
        )

        service.refresh(d(2026, 8, 19), days = 1, now = now)
        assertNull(service.season(d(2026, 8, 19)), "and the New Calendar is not in the fast")
    }

    @Test
    fun `switching back costs no requests`() {
        val http = recorded()
        val service = service(http)
        service.refresh(d(2026, 8, 19), days = 1, now = now)
        val afterFirst = http.calls

        service.setJurisdiction(newCalendar, around = d(2026, 8, 19))
        service.refresh(d(2026, 8, 19), days = 1, now = now)

        service.setJurisdiction(julianJurisdiction, around = d(2026, 8, 19))
        val before = http.calls
        service.refresh(d(2026, 8, 19), days = 1, now = now)
        assertEquals(before, http.calls, "the Julian day was still a correct Julian day")
        assertTrue(afterFirst > 0)
    }

    @Test
    fun `an uncached day answers no rather than guessing`() {
        val service = service(recorded())
        assertNull(service.cachedDay(d(2030, 1, 1)))
        assertTrue(!service.isFastDay(d(2030, 1, 1)))
        assertTrue(!service.isGreatFeast(d(2030, 1, 1)))
        assertNull(service.season(d(2030, 1, 1)))
        assertNull(service.fastFreeReason(d(2030, 1, 1)))
    }

    @Test
    fun `clearing the cache empties only the reckoning asked for`() {
        val http = recorded()
        val service = service(http)
        service.refresh(d(2026, 8, 19), days = 1, now = now)
        service.setJurisdiction(newCalendar, around = d(2026, 8, 19))
        service.refresh(d(2026, 8, 19), days = 1, now = now)

        store.clearLiturgicalCache(Reckoning.REVISED_JULIAN)
        assertTrue(store.liturgicalDays(Reckoning.REVISED_JULIAN, d(2026, 1, 1), d(2026, 12, 31)).isEmpty())
        assertEquals(
            1,
            store.liturgicalDays(Reckoning.JULIAN, d(2026, 1, 1), d(2026, 12, 31)).size,
            "the other reckoning was cleared with it",
        )
    }

    @Test
    fun `a cached day round-trips through the store whole`() {
        service(recorded()).refresh(d(2026, 8, 19), days = 1, now = now)
        val loaded = store.liturgicalDay(d(2026, 8, 19), Reckoning.JULIAN)
        assertNotNull(loaded)
        assertEquals(decodeFixture("julian-2026-08-19", d(2026, 8, 19), Reckoning.JULIAN), loaded)
    }
}
