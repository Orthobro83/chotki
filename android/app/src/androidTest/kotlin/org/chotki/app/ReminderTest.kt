package org.chotki.app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.chotki.app.platform.AndroidNotifier
import org.chotki.app.platform.PendingActions
import org.chotki.app.platform.ReminderAlarms
import org.chotki.app.platform.ReminderReceiver
import org.chotki.core.CalendarDate
import org.chotki.core.NotificationAction
import org.chotki.core.NotificationRequest
import org.chotki.core.TimeOfDay
import org.chotki.core.scheduling.PlannedNotification
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

/**
 * Reminders, driven on a device rather than reasoned about.
 *
 * Everything here fails silently in real use — a permission not asked for, a
 * notification posted under an id that cannot be cancelled, an alarm armed for a
 * moment already past. None of it shows up in a screenshot, and none of it can
 * be caught on the JVM.
 */
@RunWith(AndroidJUnit4::class)
class ReminderTest {

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    private val manager: NotificationManager
        get() = context.getSystemService(NotificationManager::class.java)

    @Before
    fun grantNotifications() {
        // From Android 13 nothing appears without this, and nothing errors —
        // which is exactly the failure the first-run screen exists to prevent
        // for a real user.
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            InstrumentationRegistry.getInstrumentation().uiAutomation.grantRuntimePermission(
                context.packageName,
                android.Manifest.permission.POST_NOTIFICATIONS,
            )
        }
        manager.cancelAll()
    }

    @After fun tidy() = manager.cancelAll()

    private fun request(id: String, title: String = "Evening prayers") = NotificationRequest(
        id = id,
        title = title,
        body = "At 21:30",
        actions = listOf(NotificationAction.MARK_COMPLETE, NotificationAction.SNOOZE),
    )

    private fun posted(id: String) =
        manager.activeNotifications.firstOrNull { it.tag == id }

    /**
     * Posting and cancelling are asynchronous IPC to the system server, so
     * reading `activeNotifications` on the next line sees whatever happens to be
     * there. Waiting for the state to arrive is the difference between a test
     * that means something and one that passes on a fast machine.
     */
    private fun waitUntil(what: String, timeoutMillis: Long = 3_000, condition: () -> Boolean) {
        val deadline = System.currentTimeMillis() + timeoutMillis
        while (System.currentTimeMillis() < deadline) {
            if (condition()) return
            Thread.sleep(25)
        }
        throw AssertionError(what)
    }

    @Test
    fun theChannelIsCreatedBeforeAnythingIsShown() {
        AndroidNotifier.ensureChannel(context)
        assertNotNull(manager.getNotificationChannel(AndroidNotifier.CHANNEL_ID))
    }

    @Test
    fun aReminderActuallyAppears() {
        AndroidNotifier(context).show(request("rule:2026-08-19:lead10"))
        waitUntil("nothing was posted") { posted("rule:2026-08-19:lead10") != null }
        assertEquals(
            "Evening prayers",
            posted("rule:2026-08-19:lead10")!!
                .notification.extras.getString(android.app.Notification.EXTRA_TITLE),
        )
    }

    @Test
    fun itCarriesItsButtons() {
        AndroidNotifier(context).show(request("with-actions"))
        waitUntil("nothing was posted") { posted("with-actions") != null }
        assertEquals(2, posted("with-actions")!!.notification.actions?.size)
    }

    // Every reminder for one occurrence must go the moment the rule is kept.
    // The string id is the tag for exactly this reason — an integer hash would
    // work until two of them collided on somebody's phone.
    @Test
    fun everyReminderForAnOccurrenceCanBeCancelledTogether() {
        val notifier = AndroidNotifier(context)
        val ids = listOf("r:2026-08-19:lead60", "r:2026-08-19:lead10")
        ids.forEach { notifier.show(request(it)) }
        waitUntil("both should be showing") { ids.all { id -> posted(id) != null } }

        notifier.cancel(ids)
        waitUntil("a reminder survived completion") { ids.all { id -> posted(id) == null } }
    }

    @Test
    fun cancellingOneLeavesTheOthers() {
        val notifier = AndroidNotifier(context)
        notifier.show(request("a"))
        notifier.show(request("b"))
        waitUntil("both should be showing") { posted("a") != null && posted("b") != null }

        notifier.cancel(listOf("a"))
        waitUntil("a was not cancelled") { posted("a") == null }
        assertNotNull("b was taken down with it", posted("b"))
    }

    // An alarm may fire long after the process that armed it is gone, so the
    // whole notification travels with it rather than an id to look up.
    @Test
    fun anAlarmCarriesTheWholeNotification() {
        val original = request("carried")
        val encoded = ReminderReceiver.encode(original)
        assertEquals(original, ReminderReceiver.decode(encoded))
    }

    @Test
    fun firingTheReceiverPostsTheReminder() {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_FIRE
            putExtra(ReminderReceiver.EXTRA_REQUEST, ReminderReceiver.encode(request("fired")))
        }
        ReminderReceiver().onReceive(context, intent)
        waitUntil("the alarm path did not post anything") { posted("fired") != null }
    }

    @Test
    fun pressingAButtonTakesTheReminderDownAndRecordsIt() {
        AndroidNotifier(context).show(request("pressed"))
        PendingActions.drain()

        ReminderReceiver().onReceive(
            context,
            Intent(context, ReminderReceiver::class.java).apply {
                action = ReminderReceiver.ACTION_BUTTON
                putExtra(AndroidNotifier.EXTRA_REQUEST_ID, "pressed")
                putExtra(AndroidNotifier.EXTRA_ACTION_ID, NotificationAction.MARK_COMPLETE.id)
            },
        )

        waitUntil("the banner stayed up after being acted on") { posted("pressed") == null }
        assertEquals(listOf("pressed" to "complete"), PendingActions.drain())
    }

    @Test
    fun drainingTwiceReturnsNothingTheSecondTime() {
        PendingActions.drain()
        PendingActions.record("x", "complete")
        assertEquals(1, PendingActions.drain().size)
        assertTrue(PendingActions.drain().isEmpty())
    }

    // Reported rather than demanded: the diagnostic screen says which of exact
    // or inexact is in force, instead of leaving a drifting reminder a mystery.
    @Test
    fun exactAlarmCapabilityIsReportable() {
        val alarms = ReminderAlarms(context)
        alarms.canScheduleExact() // must not throw on any version
    }

    @Test
    fun armingAndCancellingAnAlarmDoesNotThrow() {
        val zone = ZoneId.systemDefault()
        val planned = PlannedNotification(
            id = "armed",
            ruleID = UUID.randomUUID(),
            date = CalendarDate.of(2030, 1, 1)!!,
            fireAt = CalendarDate.of(2030, 1, 1)!!.dueInstant(TimeOfDay.of(9, 0)!!, zone)
                ?: Instant.now().plusSeconds(3600),
            request = request("armed"),
        )
        val alarms = ReminderAlarms(context)
        alarms.arm(listOf(planned))
        alarms.cancel(listOf(planned))
    }

    @Test
    fun theNotifierReportsWhetherItMayShowAnything() {
        // Granted in setUp, so this is the true case; the false case is what the
        // first-run screen is for.
        assertTrue(AndroidNotifier(context).requestAuthorization())
    }
}
