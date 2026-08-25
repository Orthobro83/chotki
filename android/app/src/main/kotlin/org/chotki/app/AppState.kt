package org.chotki.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.chotki.app.platform.AndroidDb
import org.chotki.app.platform.Reminders
import org.chotki.core.Activation
import org.chotki.core.AppSettings
import org.chotki.core.CalendarDate
import org.chotki.core.CustomLibrary
import org.chotki.core.DayEntry
import org.chotki.core.EditPlanner
import org.chotki.core.EditScope
import org.chotki.core.Occurrence
import org.chotki.core.OccurrenceStatus
import org.chotki.core.Practice
import org.chotki.core.Rule
import org.chotki.core.content.Content
import org.chotki.core.content.model
import org.chotki.core.content.modelCategory
import org.chotki.core.content.modelReminders
import org.chotki.core.content.modelTimeOfDay
import org.chotki.core.store.SqliteStore
import org.chotki.core.store.Store
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
class AppState(private val store: Store, private val zone: ZoneId = ZoneId.systemDefault()) {

    companion object {
        fun open(context: Context): AppState = AppState(SqliteStore(AndroidDb.open(context)))
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
        get() = Practice(rules, activations, occurrences, settings)

    fun load() {
        settings = store.loadSettings() ?: AppSettings.DEFAULT
        rules = store.rules()
        activations = store.activations()
        occurrences = store.occurrences()
    }

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
    }

    /** Takes a rule on from the library, from today. */
    fun take(templateID: String) {
        val template = Content.ruleLibrary.firstOrNull { it.id == templateID } ?: return
        val rule = Rule(
            title = template.title,
            note = template.note,
            source = "the library",
            recurrence = template.recurrence.model,
            timeOfDay = template.modelTimeOfDay,
            category = template.modelCategory,
            reminders = template.modelReminders,
            prayerIDs = template.prayerIDs.ifEmpty { null },
        )
        store.save(rule)
        store.save(Activation(ruleID = rule.id, from = today))

        // Taking on a rule tied to the church calendar is a clear statement of
        // intent, so the observance it depends on is turned on rather than the
        // rule silently never coming due.
        val needed = Practice(
            store.rules(), store.activations(), store.occurrences(), settings,
        ).observancesNeeded()
        if (needed.isNotEmpty()) {
            var updated = settings
            for (trigger in needed) updated = updated.copy(
                observances = updated.observances.observing(trigger),
            )
            store.saveSettings(updated)
        }
        load()
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
        load()
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
    }

    /** Out of the Custom list. The rule and its history are untouched. */
    fun setAside(rule: Rule) {
        store.save(CustomLibrary.settingAside(rule))
        load()
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
    }

    fun rearmReminders(context: Context) = Reminders.rearm(context, zone = zone)

    fun rule(id: UUID): Rule? = rules.firstOrNull { it.id == id }
}
