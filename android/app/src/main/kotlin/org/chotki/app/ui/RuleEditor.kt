package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.foundation.layout.Box
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.ui.Alignment
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.ClockStyle
import org.chotki.core.Format
import org.chotki.core.scheduling.ReminderLead
import org.chotki.core.scheduling.RuleReminders
import org.chotki.core.Recurrence
import org.chotki.core.RecurrenceForm
import org.chotki.core.Rule
import org.chotki.core.TimeOfDay
import org.chotki.core.Weekday

/**
 * Writing a rule, and changing one.
 *
 * The shape of a recurrence goes through `RecurrenceForm` in `:core` rather than
 * being assembled here. That type exists because the macOS editor had three
 * silent data-loss bugs — a one-off day became a daily rule, a Great Lent rule
 * became a general fast-day rule, and a monthly rule's short-month policy reset
 * — each because the form could not express the shape it had loaded, so saving
 * replaced it with something else without saying so.
 */
@Composable
fun RuleEditor(
    state: AppState,
    existing: Rule?,
    /**
     * A new rule, filled in from a library template but not yet saved. The
     * fields start here and the button still says "Take it on", because that is
     * what saving it does.
     */
    startingFrom: Rule? = null,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // From whichever rule is being filled in. Reading only `existing` dropped
    // the template's own time: Morning prayers arrived at 06:30 and the editor
    // opened saying it ran all day, which is not what was taken on.
    val filling = existing ?: startingFrom
    var title by remember { mutableStateOf(filling?.title ?: "") }
    var note by remember { mutableStateOf(filling?.note ?: "") }
    var source by remember { mutableStateOf(filling?.source ?: "") }
    var form by remember {
        mutableStateOf(filling?.let { RecurrenceForm.of(it.recurrence) } ?: RecurrenceForm())
    }
    val startingReminders = filling?.effectiveReminders ?: RuleReminders.DEFAULT
    var remind by remember { mutableStateOf(startingReminders.enabled) }
    var leads by remember { mutableStateOf(startingReminders.leads.toSet()) }
    var hasTime by remember { mutableStateOf(filling?.timeOfDay != null) }
    var hour by remember { mutableStateOf(filling?.timeOfDay?.hour ?: 6) }
    var minute by remember { mutableStateOf(filling?.timeOfDay?.minute ?: 30) }

    Column(
        modifier
            .fillMaxSize()
            .background(Chotki.ground)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            when {
                existing != null -> "Edit this rule"
                startingFrom != null -> "Take this on"
                else -> "Write your own rule"
            },
            color = Chotki.parchment,
            fontSize = 18.sp,
            modifier = Modifier.semantics { contentDescription = "Rule editor" },
        )
        Spacer(Modifier.size(14.dp))

        Field("What is it?", title, "Write something…", "Rule title") { title = it }
        Field("A note, if you want one", note, "Write something…", "Rule note") { note = it }
        // Rules arrive from other people over months and their origin matters
        // later: "Fr. Peter", "my godfather", "the parish bulletin". The hint is
        // neutral rather than an example, because an example that contradicts
        // the rule being taken on — "before sleep" under Morning prayers —
        // reads as the app not paying attention.
        Field("Where it came from", source, "Write something…", "Rule source") { source = it }

        Spacer(Modifier.size(10.dp))
        // Seven full-width choices stacked took most of a phone screen before
        // the time picker had even appeared. One line, opened when wanted.
        Dropdown(
            label = "How often",
            chosen = form.kind.label,
            options = RecurrenceForm.Kind.entries.map { it.label },
        ) { index -> form = form.copy(kind = RecurrenceForm.Kind.entries[index]) }

        if (form.kind == RecurrenceForm.Kind.WEEKLY) {
            Spacer(Modifier.size(8.dp))
            Text("Which days", color = Chotki.gold, fontSize = 13.sp)
            // Several at once, so these stay chips rather than becoming a menu —
            // but in a row that scrolls, for the same reason as above.
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())) {
                for (day in Weekday.entries) {
                    val chosen = day in form.weekdays
                    Choice(day.name.take(3).lowercase().replaceFirstChar { it.uppercase() }, chosen, compact = true) {
                        form = form.copy(
                            weekdays = if (chosen) form.weekdays - day else form.weekdays + day,
                        )
                    }
                }
            }
        }

        Spacer(Modifier.size(10.dp))
        Choice("At a set time", hasTime) { hasTime = !hasTime }
        if (hasTime) {
            // Labelled in whichever clock he reads, so an evening rule cannot be
            // set to the morning by picking the number that looks right — which
            // is how Evening prayers came to sit at half past ten in the morning
            // on the macOS side for several days.
            // A menu, not a scrolling row. Twenty-four chips in a horizontal
            // scroll sitting inside the page's vertical scroll lost the gesture
            // on a real phone: the row would not move past the ninth, so an
            // evening rule simply could not be set. It read as a formatting
            // problem and was a gesture one.
            Dropdown(
                label = "Hour",
                chosen = Format.hourLabel(hour, state.settings.clockStyle),
                options = (0..23).map { Format.hourLabel(it, state.settings.clockStyle) },
            ) { hour = it }
            Text("Minute", color = Chotki.faint, fontSize = 12.sp)
            Row {
                for (candidate in listOf(0, 15, 30, 45)) {
                    Choice("%02d".format(candidate), candidate == minute, compact = true) {
                        minute = candidate
                    }
                }
            }
            Text(
                "Due at ${Format.time(TimeOfDay.of(hour, minute)!!, state.settings.clockStyle)}",
                color = Chotki.goldDim,
                fontSize = 13.sp,
                modifier = Modifier.padding(top = 6.dp),
            )
        } else {
            Text(
                "It runs all day, and reminders are spread across the waking hours.",
                color = Chotki.faint,
                fontSize = 13.sp,
            )
        }

        Spacer(Modifier.size(10.dp))
        // Never offered here at all until now, so a rule arrived with whatever
        // the library had decided and there was no way to change it — nor to
        // put reminders on a rule of one's own. Which meant reminders could not
        // be tested, let alone kept.
        Choice("Remind me", remind) { remind = !remind }
        if (remind) {
            Text("When", color = Chotki.faint, fontSize = 12.sp)
            // Several at once is the point: an hour before to get ready, ten
            // minutes before to actually begin.
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())) {
                for (lead in ReminderLead.CHOICES) {
                    val chosen = lead in leads
                    Choice(lead.label, chosen, compact = true) {
                        leads = if (chosen) leads - lead else leads + lead
                    }
                }
            }
            if (leads.isEmpty()) {
                Text(
                    "Pick at least one, or Chotki will fall back to ten minutes before.",
                    color = Chotki.faint,
                    fontSize = 12.sp,
                )
            }
        } else {
            Text("This rule will not buzz. It is still due, and still counted.", color = Chotki.faint, fontSize = 12.sp)
        }

        Spacer(Modifier.size(20.dp))
        Row {
            Text(
                if (existing == null) "Take it on" else "Save",
                color = Chotki.gold,
                fontSize = 16.sp,
                modifier = Modifier
                    .border(1.dp, Chotki.goldDim, RoundedCornerShape(4.dp))
                    .clickable(enabled = title.isNotBlank()) {
                        state.save(
                            (existing ?: startingFrom ?: Rule(title = title, recurrence = Recurrence.Daily)).copy(
                                title = title.trim(),
                                note = note.ifBlank { null },
                                source = source.ifBlank { null },
                                recurrence = form.recurrence(fallback = state.today),
                                timeOfDay = if (hasTime) TimeOfDay.of(hour, minute) else null,
                                reminders = RuleReminders(
                                    enabled = remind,
                                    leads = leads.sortedWith(ReminderLead.BY_LEAD)
                                        .ifEmpty { RuleReminders.DEFAULT.leads },
                                ),
                            ),
                        )
                        onDone()
                    }
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .semantics { contentDescription = "Save the rule" },
            )
            Spacer(Modifier.size(12.dp))
            Text(
                "Cancel",
                color = Chotki.muted,
                fontSize = 16.sp,
                modifier = Modifier
                    .clickable(onClick = onDone)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
                    .semantics { contentDescription = "Cancel editing" },
            )
        }

        if (existing != null) {
            Spacer(Modifier.size(24.dp))
            Text(
                "Remove from your rule",
                color = Chotki.ochre,
                fontSize = 14.sp,
                modifier = Modifier
                    .clickable { state.remove(existing); onDone() }
                    .padding(vertical = 8.dp)
                    .semantics { contentDescription = "Remove the rule" },
            )
            // Nothing is ever destroyed, and the wording says so plainly rather
            // than leaving someone afraid to press it.
            Text(
                "Everything it has kept stays in the record, and it can be taken up again " +
                    "from the library.",
                color = Chotki.faint,
                fontSize = 12.sp,
            )
        }
        Spacer(Modifier.size(40.dp))
    }
}

@Composable
private fun Field(
    label: String,
    value: String,
    hint: String,
    description: String,
    onChange: (String) -> Unit,
) {
    Text(label, color = Chotki.gold, fontSize = 13.sp, modifier = Modifier.padding(top = 10.dp))
    TextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(hint, color = Chotki.faint) },
        singleLine = true,
        colors = TextFieldDefaults.colors(
            focusedContainerColor = Chotki.panel,
            unfocusedContainerColor = Chotki.panel,
            focusedTextColor = Chotki.parchment,
            unfocusedTextColor = Chotki.parchment,
        ),
        modifier = Modifier.fillMaxWidth().semantics { contentDescription = description },
    )
}

@Composable
private fun Choice(label: String, chosen: Boolean, compact: Boolean = false, onPick: () -> Unit) {
    Text(
        label,
        color = if (chosen) Chotki.ground else Chotki.parchment,
        fontSize = 14.sp,
        modifier = Modifier
            .padding(vertical = 3.dp, horizontal = if (compact) 3.dp else 0.dp)
            .background(
                if (chosen) Chotki.gold else Chotki.panel,
                RoundedCornerShape(4.dp),
            )
            .clickable(onClick = onPick)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics { contentDescription = "Choose $label" },
    )
}
