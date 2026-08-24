package org.chotki.core.scheduling

import org.chotki.core.Activation
import org.chotki.core.CalendarDate
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.TimeOfDay
import org.chotki.core.Weekday
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int): CalendarDate = CalendarDate.of(y, m, day)!!
private val zone: ZoneId = ZoneId.of("Europe/London")

private fun localTime(instant: Instant): String {
    val local = LocalDateTime.ofInstant(instant, zone)
    return "%02d:%02d".format(local.hour, local.minute)
}

/** Translated from suite "Scheduler". */
class SchedulerTest {

    private fun scheduler(policy: ReminderPolicy = ReminderPolicy.DEFAULT) =
        Scheduler(policy = policy, zone = zone)

    private fun timedRule(hour: Int, minute: Int): Pair<Rule, List<Activation>> {
        val rule = Rule(
            title = "Evening prayers",
            recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(hour, minute),
        )
        return rule to listOf(Activation(ruleID = rule.id, from = d(2026, 1, 1)))
    }

    private fun untimedRule(): Pair<Rule, List<Activation>> {
        val rule = Rule(title = "Jesus prayer — 50 knots", recurrence = Recurrence.Daily)
        return rule to listOf(Activation(ruleID = rule.id, from = d(2026, 1, 1)))
    }

    // MARK: timed rules

    @Test
    fun `a timed rule warns ten minutes ahead`() {
        val (rule, activations) = timedRule(21, 30)
        val planned = scheduler().plan(listOf(rule), activations, emptyList(), d(2026, 8, 19))
        assertEquals(1, planned.size)
        assertEquals("21:20", localTime(planned.first().fireAt))
        assertEquals("At 21:30", planned[0].request.body)
    }

    // The bug this test exists to prevent: with quiet hours ending 06:30, a
    // 06:30 rule has a lead time of 06:20 — inside the quiet window. Silencing
    // it would make the app useless for the rule people most want kept.
    @Test
    fun `a reminder the user set themselves is never silenced by quiet hours`() {
        val (rule, activations) = timedRule(6, 30)
        val planned = scheduler().plan(listOf(rule), activations, emptyList(), d(2026, 8, 19))
        assertEquals(1, planned.size, "morning prayers must still remind")
        assertEquals("06:20", localTime(planned.first().fireAt))
    }

    @Test
    fun `a rule not due that day produces nothing`() {
        val rule = Rule(
            title = "Sunday Liturgy",
            recurrence = Recurrence.Weekly(setOf(Weekday.SUNDAY)),
            timeOfDay = TimeOfDay.of(9, 0),
        )
        val activations = listOf(Activation(ruleID = rule.id, from = d(2026, 1, 1)))
        // 19 August 2026 is a Wednesday.
        assertTrue(scheduler().plan(listOf(rule), activations, emptyList(), d(2026, 8, 19)).isEmpty())
    }

    @Test
    fun `a rule outside its activation produces nothing`() {
        val rule = Rule(
            title = "Evening prayers",
            recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(21, 30),
        )
        val paused = listOf(
            Activation(ruleID = rule.id, from = d(2026, 1, 1), to = d(2026, 5, 10)),
        )
        assertTrue(scheduler().plan(listOf(rule), paused, emptyList(), d(2026, 8, 19)).isEmpty())
    }

    // MARK: untimed rules

    @Test
    fun `the default spreads reminders across the waking day`() {
        val (rule, activations) = untimedRule()
        val planned = scheduler().plan(listOf(rule), activations, emptyList(), d(2026, 8, 19))
        assertEquals(4, planned.size, "the default cap")
        val times = planned.map { localTime(it.fireAt) }
        assertEquals("07:00", times.first(), "starts at the first waking hour")
        assertEquals("21:00", times.last(), "and is still in front of you in the evening")
        // The point of spreading: no two reminders back to back.
        assertEquals(4, times.toSet().size)
    }

    // The literal original cadence, kept available. Four nudges before breakfast
    // and then silence for fourteen hours.
    @Test
    fun `the hourly policy clusters in the morning`() {
        val (rule, activations) = untimedRule()
        val planned = Scheduler(policy = ReminderPolicy.HOURLY, zone = zone)
            .plan(listOf(rule), activations, emptyList(), d(2026, 8, 19))
        assertEquals(
            listOf("07:00", "08:00", "09:00", "10:00"),
            planned.map { localTime(it.fireAt) },
        )
    }

    @Test
    fun `nothing is ever scheduled inside the quiet window`() {
        val (rule, activations) = untimedRule()
        val planned = Scheduler(
            policy = ReminderPolicy(untimedCap = 0, spacing = UntimedSpacing.HOURLY),
            zone = zone,
        ).plan(listOf(rule), activations, emptyList(), d(2026, 8, 19))
        val times = planned.map { localTime(it.fireAt) }
        assertEquals("07:00", times.first())
        assertEquals("21:00", times.last())
        assertTrue("03:00" !in times, "the 3am case this exists to prevent")
        assertTrue("22:00" !in times)
        assertTrue("06:00" !in times)
    }

    @Test
    fun `the gentle policy asks once and then leaves you alone`() {
        val (rule, activations) = untimedRule()
        val planned = Scheduler(policy = ReminderPolicy.GENTLE, zone = zone)
            .plan(listOf(rule), activations, emptyList(), d(2026, 8, 19))
        assertEquals(1, planned.size)
    }

    @Test
    fun `the master switch silences everything`() {
        val (rule, activations) = untimedRule()
        assertTrue(
            Scheduler(policy = ReminderPolicy.SILENT, zone = zone)
                .plan(listOf(rule), activations, emptyList(), d(2026, 8, 19)).isEmpty(),
        )
    }

    // MARK: settling a day

    @Test
    fun `completing silences the rest of the day`() {
        for (status in listOf(
            OccurrenceStatus.COMPLETED,
            OccurrenceStatus.COMPLETED_LATE,
            OccurrenceStatus.SKIPPED,
            OccurrenceStatus.CANCELLED,
            OccurrenceStatus.MOVED,
        )) {
            val (rule, activations) = untimedRule()
            val occurrence = Occurrence(ruleID = rule.id, date = d(2026, 8, 19), status = status)
            assertTrue(
                scheduler().plan(listOf(rule), activations, listOf(occurrence), d(2026, 8, 19))
                    .isEmpty(),
                "$status must stop the reminders",
            )
        }
    }

    @Test
    fun `an archived rule reminds about nothing`() {
        val (rule, activations) = timedRule(21, 30)
        val archived = rule.copy(archivedAt = Instant.now())
        assertTrue(
            scheduler().plan(listOf(archived), activations, emptyList(), d(2026, 8, 19)).isEmpty(),
        )
    }

    @Test
    fun `a rule with its reminders turned off stays due but silent`() {
        val (rule, activations) = timedRule(21, 30)
        val silenced = rule.copy(reminders = RuleReminders.SILENT)
        assertTrue(
            scheduler().plan(listOf(silenced), activations, emptyList(), d(2026, 8, 19)).isEmpty(),
        )
    }

    @Test
    fun `a rule may ask for more than one warning`() {
        val (rule, activations) = timedRule(9, 0)
        val forService = rule.copy(reminders = RuleReminders.FOR_SERVICE)
        val planned = scheduler().plan(listOf(forService), activations, emptyList(), d(2026, 8, 19))
        assertEquals(
            listOf("08:00", "08:50"), planned.map { localTime(it.fireAt) },
            "an hour before to get ready, ten minutes before to leave",
        )
    }

    @Test
    fun `the evening before fires at a predictable hour the night before`() {
        val (rule, activations) = timedRule(9, 0)
        val nightBefore = rule.copy(
            reminders = RuleReminders(leads = listOf(ReminderLead.THE_EVENING_BEFORE)),
        )
        val planned = scheduler().plan(listOf(nightBefore), activations, emptyList(), d(2026, 8, 19))
        assertEquals(1, planned.size)
        assertEquals("20:00", localTime(planned[0].fireAt))
        assertEquals("Tomorrow at 09:00", planned[0].request.body)
    }

    @Test
    fun `cancellation covers every reminder armed for that day`() {
        val (rule, activations) = untimedRule()
        val planned = scheduler().plan(listOf(rule), activations, emptyList(), d(2026, 8, 19))
        val cancelled = scheduler().cancellationIDs(rule.id, d(2026, 8, 19), listOf(rule))
        assertEquals(
            planned.map { it.id }.toSet(), cancelled.toSet(),
            "no reminder may survive completion",
        )
        assertTrue(cancelled.isNotEmpty())
    }

    @Test
    fun `pending only returns reminders still ahead`() {
        val (rule, activations) = untimedRule()
        val nineAM = d(2026, 8, 19).dueInstant(TimeOfDay.of(9, 0)!!, zone)!!
        val pending = scheduler()
            .pending(listOf(rule), activations, emptyList(), d(2026, 8, 19), nineAM)
        assertEquals(
            listOf("12:00", "16:00", "21:00"), pending.map { localTime(it.fireAt) },
            "the 07:00 reminder is behind us; the rest of the day is not",
        )
    }

    // MARK: tone

    @Test
    fun `no reminder ever carries guilt language`() {
        val (timed, timedActivations) = timedRule(21, 30)
        val (untimed, untimedActivations) = untimedRule()
        val planned = scheduler().plan(
            listOf(timed, untimed),
            timedActivations + untimedActivations,
            emptyList(),
            d(2026, 8, 19),
        )
        assertTrue(planned.isNotEmpty())
        val forbidden = listOf(
            "overdue", "missed", "still", "again", "behind", "failed", "!", "don't forget",
        )
        for (notification in planned) {
            val text = "${notification.request.title} ${notification.request.body}".lowercase()
            for (word in forbidden) {
                assertTrue(!text.contains(word), "$text contains $word")
            }
        }
    }
}

/** The headless proof: a month of days, against an injected clock. */
class SimulatedMonthTest {

    @Test
    fun `a month of days produces reminders only when a rule is actually due`() {
        val morning = Rule(
            title = "Morning prayers", recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(6, 30),
        )
        val liturgy = Rule(
            title = "Sunday Liturgy", recurrence = Recurrence.Weekly(setOf(Weekday.SUNDAY)),
            timeOfDay = TimeOfDay.of(9, 0),
        )
        val knots = Rule(title = "Jesus prayer", recurrence = Recurrence.Daily)

        val rules = listOf(morning, liturgy, knots)
        val activations = rules.map { Activation(ruleID = it.id, from = d(2026, 8, 1)) }
        val scheduler = Scheduler(policy = ReminderPolicy.DEFAULT, zone = zone)

        val byRule = mutableMapOf<UUID, Int>()
        var everQuiet = false

        for (day in 1..31) {
            val planned = scheduler.plan(rules, activations, emptyList(), d(2026, 8, day))
            for (notification in planned) {
                byRule[notification.ruleID] = (byRule[notification.ruleID] ?: 0) + 1
                val local = LocalDateTime.ofInstant(notification.fireAt, zone)
                val time = TimeOfDay.of(local.hour, local.minute)!!
                // Timed reminders are exempt by design; untimed must never be quiet.
                if (notification.request.body == "Today" && QuietHours.DEFAULT.contains(time)) {
                    everQuiet = true
                }
            }
        }

        assertEquals(31, byRule[morning.id], "daily, every day of the month")
        assertEquals(5, byRule[liturgy.id], "five Sundays in August 2026")
        assertEquals(31 * 4, byRule[knots.id], "four reminders a day, capped")
        assertTrue(
            !everQuiet,
            "no untimed reminder landed in the quiet window across a whole month",
        )
    }

    @Test
    fun `completing each day silences that day and no other`() {
        val rule = Rule(
            title = "Evening prayers", recurrence = Recurrence.Daily,
            timeOfDay = TimeOfDay.of(21, 30),
        )
        val activations = listOf(Activation(ruleID = rule.id, from = d(2026, 8, 1)))
        val scheduler = Scheduler(zone = zone)

        // Kept on the 19th only.
        val occurrences = listOf(
            Occurrence(ruleID = rule.id, date = d(2026, 8, 19), status = OccurrenceStatus.COMPLETED),
        )

        val reminded = (17..21).filter {
            scheduler.plan(listOf(rule), activations, occurrences, d(2026, 8, it)).isNotEmpty()
        }
        assertEquals(listOf(17, 18, 20, 21), reminded, "only the 19th is silent")
    }
}
