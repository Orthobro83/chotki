package org.chotki.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.chotki.app.platform.AndroidDb
import org.chotki.app.platform.AndroidHttp
import org.chotki.app.platform.Reminders
import org.chotki.core.Activation
import org.chotki.core.AppSettings
import org.chotki.core.CalendarDate
import org.chotki.core.ClockStyle
import org.chotki.core.CustomLibrary
import org.chotki.core.DayEntry
import org.chotki.core.EditPlanner
import org.chotki.core.EditScope
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.LiturgicalDay
import org.chotki.core.NoLiturgicalData
import org.chotki.core.Practice
import org.chotki.core.Rule
import org.chotki.core.content.Content
import org.chotki.core.content.model
import org.chotki.core.content.modelCategory
import org.chotki.core.content.modelReminders
import org.chotki.core.content.modelTimeOfDay
import org.chotki.core.liturgical.LiturgicalService
import org.chotki.core.liturgical.OrthocalClient
import org.chotki.core.store.SqliteStore
import org.chotki.core.store.Store
import org.chotki.core.store.exportJson
import org.chotki.core.store.importJson
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

/**
 * What the screens read, and the only thing that writes.
 *
 * Deliberately thin. Everything it is asked — what is due today, whether a day
 * is settled, what the progress says — is answered by `Practice` in `:core`.
 * The macOS app learned this the hard way: decisions that lived in its view
 * model were the ones a port would have had to rewrite, and the ones every bug
 * found by hand was in.
 */
class AppState(
    private val store: Store,
    private val zone: ZoneId = ZoneId.systemDefault(),
    /**
     * The church calendar. Null in tests that have no business reaching a
     * network, which answers "no" to every question rather than pretending.
     */
    val liturgical: LiturgicalService? = null,
) {

    companion object {
        fun open(context: Context): AppState {
            val store = SqliteStore(AndroidDb.open(context))
            return AppState(
                store = store,
                liturgical = LiturgicalService(store, OrthocalClient(AndroidHttp())),
            ).also { it.appContext = context.applicationContext }
        }
    }

    /**
     * Set only when the real app opens the state, so a change to a rule can
     * reschedule its alarms there and then.
     *
     * Null under test, which is deliberate: no test may reach the device's
     * alarm manager. It also means a test that wanted to check rescheduling
     * would have to say so, rather than doing it by accident.
     */
    private var appContext: Context? = null

    /**
     * Alarms follow the rules. Called after anything that changes when a rule
     * is due — until now this happened only in `onResume`, so a reminder set in
     * the editor did not schedule until the app had been backgrounded and
     * reopened, which looks exactly like reminders not working.
     */
    private fun rescheduleReminders() {
        appContext?.let { Reminders.rearm(it, zone = zone) }
    }

    var settings by mutableStateOf(AppSettings.DEFAULT)
        private set
    var rules by mutableStateOf<List<Rule>>(emptyList())
        private set
    var activations by mutableStateOf<List<Activation>>(emptyList())
        private set
    var occurrences by mutableStateOf<List<Occurrence>>(emptyList())
        private set
    var selectedDate by mutableStateOf(CalendarDate.from(Instant.now(), zone))
    var visibleMonth by mutableStateOf(CalendarDate.from(Instant.now(), zone))

    val today: CalendarDate get() = CalendarDate.from(Instant.now(), zone)

    private val practice: Practice
        get() {
            // The four lists below are snapshot state, so a screen reading
            // through Practice redraws when a rule is taken up or a box ticked.
            // The calendar is not — the service holds it in a plain map — so
            // read the counter here, once, on behalf of every screen. A rule
            // that is due only because of the church calendar (the Dormition
            // Fast) would otherwise not appear until the app was restarted,
            // and no screen author would think to ask for it.
            calendarVersion
            return Practice(
                rules, activations, occurrences, settings,
                liturgical ?: NoLiturgicalData,
            )
        }

    /** The church calendar for a day, if it has been fetched. */
    fun liturgicalDay(date: CalendarDate): LiturgicalDay? {
        calendarVersion
        return liturgical?.cachedDay(date)
    }

    val isOffline: Boolean get() = liturgical?.isOffline ?: false

    fun load() {
        settings = store.loadSettings() ?: AppSettings.DEFAULT
        rules = store.rules()
        activations = store.activations()
        occurrences = store.occurrences()
        liturgical?.let { service ->
            service.setJurisdiction(settings.jurisdiction, around = today, window = 21)
        }
        calendarVersion += 1
    }

    /**
     * Bumped whenever the calendar changes, so screens reading through
     * [liturgicalDay] recompose. The service holds its snapshot in a plain map
     * for the sake of the recurrence engine, which asks about forty-two days on
     * every redraw and cannot afford to suspend — so Compose needs telling.
     */
    var calendarVersion by mutableStateOf(0)
        private set

    /**
     * Fills in the fortnight ahead, off the main thread.
     *
     * Never throws and never blocks the interface: a failed refresh is a state
     * the app reflects — "cached" — rather than an error shown where text should
     * be. Opening on a plane shows the day it already has.
     */
    fun refreshCalendar(onDone: () -> Unit = {}) {
        val service = liturgical ?: return
        Thread {
            runCatching { service.refresh(from = today.plusDays(-7), days = 28) }
            runCatching { service.loadSnapshot(around = today, window = 21) }
            // Snapshot state is safe to write from any thread, and this is what
            // tells the screens the fortnight has arrived. Without it the days
            // were fetched and stored and nothing redrew.
            calendarVersion += 1
            onDone()
        }.start()
    }

    /**
     * True when the calendar has never been fetched at all.
     *
     * Distinguished from "not fetched *this* day" so the empty reading can say
     * which it is. A permission that was never declared and a network that is
     * merely down look identical from here, and both looked like "it will fill
     * in shortly" — which was a promise the app could not keep.
     */
    val hasNoCalendarAtAll: Boolean
        get() = liturgical?.let { service ->
            calendarVersion
            (0..3).none { service.cachedDay(today.plusDays(it)) != null }
        } ?: true

    /**
     * The record, as a file that outlives the app.
     *
     * Android is given no permission to back this app up — a record of
     * someone's prayer life is not something to hand to Google — so this is the
     * only way it reaches a new phone. See [org.chotki.app.ui.Keeping].
     */
    fun exportJson(): String = store.exportJson()

    /** Merges a backup in and reloads. Nothing already here is removed. */
    fun restoreFrom(text: String) {
        store.importJson(text)
        load()
    }

    /**
     * Any change to the settings, with the consequences that follow it.
     *
     * The reckoning is the one that bites. Moving it shifts every fast and
     * feast by thirteen days, and without [AppSettings.reckoningChangedOn] the
     * scoring re-derives the past from the new calendar — turning a fortnight
     * someone actually kept into a fortnight of misses. Stamping the date stops
     * scoring reaching back past it.
     */
    fun updateSettings(change: (AppSettings) -> AppSettings) {
        val before = settings
        val updated = change(before)
        val reckoningChanged =
            updated.jurisdiction.reckoning != before.jurisdiction.reckoning
        val settled = if (reckoningChanged) updated.copy(reckoningChangedOn = today) else updated

        store.saveSettings(settled)
        settings = settled

        if (updated.jurisdiction != before.jurisdiction) {
            // The calendar itself has to be refetched: the same civil day is a
            // different church day under the other reckoning.
            liturgical?.let { runCatching { it.setJurisdiction(settled.jurisdiction, around = today, window = 21) } }
            refreshCalendar()
        }
        calendarVersion += 1
    }

    /** How times are written, everywhere at once. */
    fun setClockStyle(style: ClockStyle) = updateSettings { it.copy(clockStyle = style) }

    fun entries(on: CalendarDate): List<DayEntry> = practice.entries(on)

    fun isSettled(on: CalendarDate): Boolean = practice.isSettled(on)

    fun report(days: Int = 30) = practice.report(days = days, today = today, zone = zone)

    /**
     * Marking kept and un-marking it.
     *
     * Un-ticking removes the record rather than writing "skipped": absence is
     * the default state, and skipped means something else entirely — a day
     * deliberately stood down, which leaves both sides of the score.
     */
    /**
     * Marking a day settled changes what should be armed, so it reschedules.
     *
     * It did not, and that is half of why a rule went on buzzing after it had
     * been kept — the plan stopped including it and nothing acted on that.
     */
    fun toggleKept(entry: DayEntry) {
        if (entry.isDispensed) return
        if (entry.isKept) {
            store.removeOccurrence(entry.rule.id, entry.date)
        } else {
            val late = entry.date < today
            store.save(
                Occurrence(
                    ruleID = entry.rule.id,
                    date = entry.date,
                    status = if (late) OccurrenceStatus.COMPLETED_LATE else OccurrenceStatus.COMPLETED,
                    completedAt = Instant.now(),
                ),
            )
        }
        load()
        rescheduleReminders()
    }

    fun standDown(entry: DayEntry) {
        store.save(
            Occurrence(
                ruleID = entry.rule.id,
                date = entry.date,
                status = OccurrenceStatus.SKIPPED,
            ),
        )
        load()
        rescheduleReminders()
    }

    /** Takes a rule on from the library, from today. */
    /**
     * The rule a library template would make, without saving it.
     *
     * So the editor can be shown first, filled in — taking something on is a
     * decision about how often, and asking afterwards meant finding the rule on
     * the day and opening the pencil.
     */
    fun ruleFrom(templateID: String): Rule? {
        val template = Content.ruleLibrary.firstOrNull { it.id == templateID } ?: return null
        return Rule(
            title = template.title,
            note = template.note,
            source = "the library",
            recurrence = template.recurrence.model,
            timeOfDay = template.modelTimeOfDay,
            category = template.modelCategory,
            reminders = template.modelReminders,
            prayerIDs = template.prayerIDs.ifEmpty { null },
        )
    }

    fun take(templateID: String) {
        val rule = ruleFrom(templateID) ?: return
        store.save(rule)
        store.save(Activation(ruleID = rule.id, from = today))
        turnOnNeededObservances()
        load()
        rescheduleReminders()
    }

    /**
     * A rule tied to the church calendar is a clear statement of intent, so the
     * observance it depends on is turned on rather than the rule silently never
     * coming due.
     *
     * Called from [save] as well as [take]: a rule written by hand on fast days
     * has exactly the same problem, and only the library path was covered.
     */
    private fun turnOnNeededObservances() {
        val needed = Practice(
            store.rules(), store.activations(), store.occurrences(), settings,
        ).observancesNeeded()
        if (needed.isEmpty()) return
        var updated = settings
        for (trigger in needed) updated = updated.copy(
            observances = updated.observances.observing(trigger),
        )
        store.saveSettings(updated)
    }

    fun isTaken(templateID: String): Boolean {
        val title = Content.ruleLibrary.firstOrNull { it.id == templateID }?.title ?: return false
        return rules.any { it.title == title }
    }

    // MARK: rules of one's own

    /** The Custom section: rules he wrote, whether or not they are in force. */
    val customEntries: List<Rule>
        get() = CustomLibrary.entries(store.rules(includeArchived = true))

    /** Not archived, and with an open stretch. */
    fun isOnTheRule(rule: Rule): Boolean = !rule.isArchived && !practice.isPaused(rule)

    fun save(rule: Rule, from: CalendarDate = today) {
        val existing = store.rule(rule.id)
        store.save(rule)
        if (existing == null) store.save(Activation(ruleID = rule.id, from = from))
        turnOnNeededObservances()
        load()
        rescheduleReminders()
    }

    /**
     * Puts a rule of his own back on the rule, from today.
     *
     * The same rule, not a copy: its history follows it, and the gap shows as a
     * gap rather than as two unrelated rules with the record split between them.
     */
    fun takeUp(rule: Rule) {
        store.save(CustomLibrary.takingUp(rule))
        if (practice.isPaused(rule)) {
            store.save(Activation(ruleID = rule.id, from = today))
        }
        load()
        rescheduleReminders()
    }

    /** Out of the Custom list. The rule and its history are untouched. */
    fun setAside(rule: Rule) {
        store.save(CustomLibrary.settingAside(rule))
        load()
        rescheduleReminders()
    }

    /** Stops a rule from today onwards, keeping everything it has kept. */
    fun remove(rule: Rule) {
        store.apply(
            EditPlanner().delete(
                rule = rule,
                activations = activations,
                date = today,
                scope = EditScope.WHOLE_SERIES,
            ),
        )
        load()
        rescheduleReminders()
    }

    fun rearmReminders(context: Context) = Reminders.rearm(context, zone = zone)

    fun rule(id: UUID): Rule? = rules.firstOrNull { it.id == id }
}
