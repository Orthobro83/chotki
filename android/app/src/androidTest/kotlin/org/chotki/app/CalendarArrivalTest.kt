package org.chotki.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.ReadingScreen
import org.chotki.core.LiturgicalDay
import org.chotki.core.Reckoning
import org.chotki.core.liturgical.LiturgicalService
import org.chotki.core.store.SqliteStore
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * The calendar arrives after the screen is already drawn.
 *
 * It is fetched on a background thread at launch, so the first draw of the
 * reading has nothing to show. When the fortnight lands the screen has to
 * redraw — and the thing it reads, the service's snapshot, is an ordinary map
 * that Compose cannot observe. This is the test for that gap: it failed as
 * "No reading stored for this day yet" before [AppState.calendarVersion] was
 * read on the screens' behalf.
 */
@RunWith(AndroidJUnit4::class)
class CalendarArrivalTest {

    @get:Rule val compose = createComposeRule()

    @Test fun theReadingAppearsWhenTheFortnightLands() {
        val store = SqliteStore(AndroidDb.inMemory())
        val service = LiturgicalService(store)
        val state = AppState(store, liturgical = service).also { it.load() }

        compose.setContent { ReadingScreen(state) }

        compose.onNodeWithText("No reading stored for this day yet.").assertIsDisplayed()

        // What refreshCalendar does when it succeeds, minus the network.
        val today = state.selectedDate
        store.saveLiturgicalDay(
            LiturgicalDay(
                civilDate = today,
                reckoning = state.settings.jurisdiction.reckoning,
                observedDate = today,
                title = "Afterfeast of the Transfiguration",
                fastLevel = 2,
                fastLevelDescription = "Dormition Fast",
                fastException = 0,
                feastLevel = 0,
                feastLevelDescription = "",
                paschaDistance = 134,
                fetchedAt = Instant.now(),
            ),
        )
        // The real path: refreshCalendar reloads the snapshot from the store
        // and tells Compose, exactly as it does when the network answers.
        val done = CountDownLatch(1)
        state.refreshCalendar { done.countDown() }
        assertTrue(done.await(10, TimeUnit.SECONDS))

        compose.waitForIdle()
        compose.onNodeWithText("Afterfeast of the Transfiguration").assertIsDisplayed()
    }
}
