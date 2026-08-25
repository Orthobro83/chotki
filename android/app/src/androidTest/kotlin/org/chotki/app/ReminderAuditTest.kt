package org.chotki.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.chotki.app.platform.ReminderAlarms
import org.chotki.app.platform.Reminders
import org.chotki.core.CalendarDate
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.TimeOfDay
import org.chotki.core.Activation
import org.chotki.core.store.SqliteStore
import org.chotki.app.platform.AndroidDb
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Instant
import java.time.ZoneId

/**
 * What is armed, and what stops being armed.
 *
 * Reported from a real phone: reminders arriving for rules already marked kept.
 * `Scheduler.plan` was right the whole time — it stops returning a settled rule
 * — but nothing ever took back the alarm that had already been handed to the
 * system, and AlarmManager will not tell you what it is holding. So the alarms
 * are written down, and these check the writing down.
 */
@RunWith(AndroidJUnit4::class)
class ReminderAuditTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val zone: ZoneId = ZoneId.systemDefault()

    /** The app's real database, which `Reminders.rearm` opens by name. */
    private fun store(): SqliteStore = SqliteStore(AndroidDb.open(context))

    private fun today() = CalendarDate.from(Instant.now(), zone)

    /**
     * Nothing is ever deleted in Chotki — history survives — so a clean slate
     * here means archiving, which is what removing a rule does anyway.
     */
    @Before fun emptyTheRecord() {
        val s = store()
        for (rule in s.rules()) s.save(rule.copy(archivedAt = Instant.now()))
        ReminderAlarms(context).arm(emptyList())
    }

    private fun aRuleDueLaterToday(): Rule {
        // Late enough that its reminder is still ahead of now.
        val rule = Rule(
            title = "Evening prayers",
            recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(23, 30),
        )
        val s = store()
        s.save(rule)
        s.save(Activation(ruleID = rule.id, from = today().plusDays(-1)))
        return rule
    }

    @Test fun aRuleDueLaterTodayIsArmed() {
        aRuleDueLaterToday()
        Reminders.rearm(context, zone = zone)

        assertTrue(
            "nothing was armed for a rule due tonight",
            ReminderAlarms(context).armedIDs().isNotEmpty(),
        )
    }

    /** The complaint, exactly. */
    @Test fun markingItKeptDisarmsIt() {
        val rule = aRuleDueLaterToday()
        Reminders.rearm(context, zone = zone)
        val armedBefore = ReminderAlarms(context).armedIDs()
        assertTrue("nothing was armed to begin with", armedBefore.isNotEmpty())

        store().save(
            Occurrence(
                ruleID = rule.id,
                date = today(),
                status = OccurrenceStatus.COMPLETED,
                completedAt = Instant.now(),
            ),
        )
        Reminders.rearm(context, zone = zone)

        // Today's are gone; tomorrow's stay, because keeping today says
        // nothing about tomorrow. An earlier version of this test asserted
        // everything went and failed against correct behaviour.
        // Asked of AlarmManager, not of this class's own note of what it did.
        val alarms = ReminderAlarms(context)
        val todaysAlarms = armedBefore.filter { today().iso in it }
        assertTrue("nothing was armed for today to begin with", todaysAlarms.isNotEmpty())
        for (id in todaysAlarms) {
            assertTrue("still armed after being kept: $id", !alarms.isArmed(id))
        }
        assertTrue(
            "tomorrow was disarmed too, which keeping today does not warrant",
            armedBefore.any { today().plusDays(1).iso in it && alarms.isArmed(it) },
        )
    }

    /** Standing a day down must silence it too, not only completing it. */
    @Test fun standingItDownDisarmsIt() {
        val rule = aRuleDueLaterToday()
        Reminders.rearm(context, zone = zone)
        assertTrue(ReminderAlarms(context).armedIDs().isNotEmpty())

        store().save(
            Occurrence(ruleID = rule.id, date = today(), status = OccurrenceStatus.SKIPPED),
        )
        Reminders.rearm(context, zone = zone)

        assertTrue(
            "standing today down left today armed",
            ReminderAlarms(context).armedIDs().none { today().iso in it },
        )
    }

    /** Removing a rule archives it, and takes its alarms with it. */
    @Test fun removingTheRuleDisarmsIt() {
        val rule = aRuleDueLaterToday()
        Reminders.rearm(context, zone = zone)
        assertTrue(ReminderAlarms(context).armedIDs().isNotEmpty())

        store().save(rule.copy(archivedAt = Instant.now()))
        Reminders.rearm(context, zone = zone)

        assertEquals(emptySet<String>(), ReminderAlarms(context).armedIDs())
    }

    /**
     * Tomorrow is armed as well as today. Only today was, which meant a day the
     * app was not opened had no reminders — and "the evening before", which
     * fires the day before the rule is due, could never be armed at all.
     */
    @Test fun tomorrowIsArmedToo() {
        aRuleDueLaterToday()
        Reminders.rearm(context, zone = zone)

        val tomorrow = today().plusDays(1).iso
        assertTrue(
            "nothing armed for tomorrow: ${ReminderAlarms(context).armedIDs()}",
            ReminderAlarms(context).armedIDs().any { tomorrow in it },
        )
    }

    @Test fun turningRemindersOffForARuleDisarmsIt() {
        val rule = aRuleDueLaterToday()
        Reminders.rearm(context, zone = zone)
        assertTrue(ReminderAlarms(context).armedIDs().isNotEmpty())

        store().save(
            rule.copy(reminders = org.chotki.core.scheduling.RuleReminders.SILENT),
        )
        Reminders.rearm(context, zone = zone)

        assertEquals(emptySet<String>(), ReminderAlarms(context).armedIDs())
    }
}
