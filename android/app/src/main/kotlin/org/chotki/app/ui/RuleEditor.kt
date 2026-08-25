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
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var title by remember { mutableStateOf(existing?.title ?: "") }
    var note by remember { mutableStateOf(existing?.note ?: "") }
    var source by remember { mutableStateOf(existing?.source ?: "") }
    var form by remember {
        mutableStateOf(existing?.let { RecurrenceForm.of(it.recurrence) } ?: RecurrenceForm())
    }
    var hasTime by remember { mutableStateOf(existing?.timeOfDay != null) }
    var hour by remember { mutableStateOf(existing?.timeOfDay?.hour ?: 6) }
    var minute by remember { mutableStateOf(existing?.timeOfDay?.minute ?: 30) }

    Column(
        modifier
            .fillMaxSize()
            .background(Chotki.ground)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            if (existing == null) "Write your own rule" else "Edit this rule",
            color = Chotki.parchment,
            fontSize = 18.sp,
            modifier = Modifier.semantics { contentDescription = "Rule editor" },
        )
        Spacer(Modifier.size(14.dp))

        Field("What is it?", title, "Evening prayers", "Rule title") { title = it }
        Field("A note, if you want one", note, "before sleep", "Rule note") { note = it }
        // Rules arrive from other people over months and their origin matters
        // later: "Fr. Peter", "my godfather", "the parish bulletin".
        Field("Where it came from", source, "my godfather", "Rule source") { source = it }

        Spacer(Modifier.size(10.dp))
        Text("How often", color = Chotki.gold, fontSize = 13.sp)
        for (kind in RecurrenceForm.Kind.entries) {
            Choice(kind.label, form.kind == kind) { form = form.copy(kind = kind) }
        }

        if (form.kind == RecurrenceForm.Kind.WEEKLY) {
            Spacer(Modifier.size(8.dp))
            Text("Which days", color = Chotki.gold, fontSize = 13.sp)
            for (day in Weekday.entries) {
                val chosen = day in form.weekdays
                Choice(day.name.lowercase().replaceFirstChar { it.uppercase() }, chosen) {
                    form = form.copy(
                        weekdays = if (chosen) form.weekdays - day else form.weekdays + day,
                    )
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
            Text("Hour", color = Chotki.faint, fontSize = 12.sp)
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())) {
                for (candidate in 0..23) {
                    Choice(
                        Format.hourLabel(candidate, state.settings.clockStyle),
                        candidate == hour,
                        compact = true,
                    ) { hour = candidate }
                }
            }
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
                            (existing ?: Rule(title = title, recurrence = Recurrence.Daily)).copy(
                                title = title.trim(),
                                note = note.ifBlank { null },
                                source = source.ifBlank { null },
                                recurrence = form.recurrence(fallback = state.today),
                                timeOfDay = if (hasTime) TimeOfDay.of(hour, minute) else null,
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
