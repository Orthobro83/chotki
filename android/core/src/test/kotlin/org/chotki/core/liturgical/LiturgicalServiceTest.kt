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
import kotlin.test.assertFalse
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
            // These test the network and cache layers alone; the bundled calendar has its own suite.
            bundle = null,
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

/**
 * The calendar that ships with the app answers before the cache or the network, and the network is
 * only a refill beyond it. Translated from Swift's "The bundled calendar in the service".
 */
class BundledServiceTest {

    private val db = JdbcDb.inMemory()
    private val store = SqliteStore(db)

    @AfterTest fun tearDown() = store.close()

    private fun d(y: Int, m: Int, day: Int) = CalendarDate.of(y, m, day)!!

    private class Failing : HttpFetching {
        var requests = 0
        override fun data(url: String): String { requests += 1; throw HttpException.Transport("no network") }
    }

    private fun service(
        http: HttpFetching,
        reckoning: Reckoning = Reckoning.JULIAN,
        policy: NetworkPolicy = NetworkPolicy.BEYOND_BUNDLE,
        bundle: BundledCalendar? = BundledCalendar.standard,
    ) = LiturgicalService(
        store, OrthocalClient(http), Jurisdiction.of("Test", reckoning, org.chotki.core.Tradition.RUSSIAN),
        bundle = bundle, networkPolicy = policy,
    )

    private fun stored(date: CalendarDate, title: String, readings: List<org.chotki.core.Reading> = emptyList()) =
        org.chotki.core.LiturgicalDay(
            civilDate = date, reckoning = Reckoning.JULIAN, observedDate = date, tone = 1, title = title,
            summaryTitle = "s", fastLevel = 0, fastLevelDescription = "No Fast", fastException = 0,
            feastLevel = 0, feastLevelDescription = "Liturgy", readings = readings, paschaDistance = 0,
            fetchedAt = Instant.now(),
        )

    @Test
    fun `a covered day is answered with an empty store, no network, and no sign of being offline`() {
        val http = Failing()
        val service = service(http)
        assertNotNull(service.cachedDay(d(2027, 4, 16)))
        assertEquals(0, service.refresh(d(2026, 10, 1), days = 60))
        assertEquals(0, http.requests, "nothing inside the window may be asked for")
        assertFalse(service.isOffline)
    }

    @Test
    fun `the calendar facts the recurrence engine asks for come from the bundle`() {
        val service = service(Failing(), Reckoning.REVISED_JULIAN)
        // Great Lent 2027 began on Monday 15 March, new and old calendar alike.
        assertTrue(service.isFastDay(d(2027, 3, 15)))
        assertEquals(org.chotki.core.FastingSeason.GREAT_LENT, service.season(d(2027, 3, 15)))
        // Pascha, 2 May 2027, is a Great Feast.
        assertTrue(service.isGreatFeast(d(2027, 5, 2)))
        assertEquals("Bright Week", service.fastFreeReason(d(2027, 5, 5)))
    }

    @Test
    fun `a date past the bundle is asked for once, and a failure is quiet`() {
        val http = Failing()
        val service = service(http)
        assertEquals(0, service.refresh(d(2032, 1, 15), days = 1))
        assertEquals(1, http.requests)
        assertTrue(service.isOffline)
        assertNull(service.cachedDay(d(2032, 1, 15)))
    }

    @Test
    fun `a stored row for a covered date is never shown, because the bundle wins`() {
        val date = d(2026, 8, 19)
        store.saveLiturgicalDay(stored(date, "A stale title"))
        val service = service(Failing())
        service.loadSnapshot(date)
        val shown = assertNotNull(service.cachedDay(date))
        assertTrue(shown.title != "A stale title")
        assertTrue(shown.readings.isNotEmpty())
    }

    @Test
    fun `Composite text cached by an older build is replaced on the way out, and the row is untouched`() {
        val date = d(2032, 2, 1)                    // past the bundle, so the cache answers
        store.saveLiturgicalDay(
            stored(date, "t", listOf(org.chotki.core.Reading("Vespers", "Composite 24 - Leviticus 26", "Lev", "A TRANSLATION THAT IS NOT OURS"))),
        )
        val shown = assertNotNull(service(Failing()).cachedDay(date)?.readings?.firstOrNull())
        assertFalse(shown.text.contains("NOT OURS"))
        assertTrue(shown.text.startsWith("Ye shall make you no idols"))
        assertEquals("A TRANSLATION THAT IS NOT OURS", store.liturgicalDay(date, Reckoning.JULIAN)?.readings?.first()?.text)
    }

    @Test
    fun `with the network switched off nothing is ever requested, and nothing looks offline`() {
        val http = Failing()
        val service = service(http, policy = NetworkPolicy.NEVER)
        assertEquals(0, service.refresh(d(2032, 1, 15), days = 10))
        assertEquals(0, service.refresh(d(2027, 1, 1), days = 10))
        assertEquals(0, http.requests)
        assertFalse(service.isOffline)
        assertNotNull(service.cachedDay(d(2027, 1, 5)), "the bundle still answers")
        assertNull(service.cachedDay(d(2032, 1, 15)), "and a date past it is simply absent")
    }

    @Test
    fun `a refresh that straddles the end of the bundle never makes bundled days look cached`() {
        val http = Failing()
        val service = service(http)
        service.refresh(d(2031, 12, 28), days = 10)          // 28 Dec 2031 ... 6 Jan 2032
        assertEquals(6, http.requests, "only the six uncovered days are asked for")
        assertTrue(service.isOffline)
        assertFalse(service.isOffline(d(2031, 12, 30)))
        assertTrue(service.isOffline(d(2032, 1, 2)))
        assertTrue(service.isBundled(d(2031, 12, 31)) && !service.isBundled(d(2032, 1, 1)))
    }

    @Test
    fun `a service with no bundle behaves as the app did before there was one`() {
        val http = Failing()
        val bare = service(http, bundle = null)
        bare.refresh(d(2027, 1, 1), days = 3)
        assertEquals(3, http.requests)
        assertTrue(bare.isOffline(d(2027, 1, 1)))
        assertNull(bare.cachedDay(d(2027, 1, 1)))
    }
}

class UserAgentTest {
    @Test
    fun `requests name the app and where to find it`() {
        assertTrue(org.chotki.core.liturgical.HttpFetching.USER_AGENT.startsWith("Chotki"))
        assertTrue(org.chotki.core.liturgical.HttpFetching.USER_AGENT.contains("https://github.com/Orthobro83/chotki"))
    }
}
