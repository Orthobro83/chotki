package org.chotki.app.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.ClockStyle
import org.chotki.core.Jurisdiction
import org.chotki.core.Observance
import org.chotki.core.Reckoning
import org.chotki.core.scheduling.ReminderLead

/**
 * The settings page, as the mockup draws it.
 *
 * Sans throughout, except the two name fields, which are set in the reading
 * face. The controls do what their labels say: a name is the greeting, a
 * church is the calendar that is fetched, Shown and Observed are different,
 * and turning notifications off silences the app without touching the record.
 */
@Composable
fun SettingsScreen(
    state: AppState,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    var keepingNotice by remember { mutableStateOf<String?>(null) }
    var churchOpen by remember { mutableStateOf(false) }
    var leadOpen by remember { mutableStateOf(false) }
    val save = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri ->
        keepingNotice = uri?.let {
            when (val outcome = Keeping.save(context, state, it)) {
                is Keeping.Outcome.Saved -> "Saved to ${outcome.name}."
                is Keeping.Outcome.Failed -> outcome.reason
                else -> null
            }
        }
    }
    val restore = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        keepingNotice = uri?.let {
            when (val outcome = Keeping.restore(context, state, it)) {
                is Keeping.Outcome.Restored ->
                    "Restored. You are keeping ${outcome.rules} " +
                        if (outcome.rules == 1) "rule." else "rules."
                is Keeping.Outcome.Failed -> outcome.reason
                else -> null
            }
        }
    }

    // The rest of the app is serif. This page is not.
    MaterialTheme(typography = Typography(), colorScheme = MaterialTheme.colorScheme) {
        Column(
            modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 14.dp, vertical = 4.dp),
        ) {
            Group("You")
            Panel {
                NameField(
                    label = "My name",
                    value = state.settings.displayName,
                    hint = "First name or Baptismal name.",
                ) { next -> state.updateSettings { it.copy(displayName = next) } }
                Hairline()
                NameField(
                    label = "My spiritual father's name",
                    value = state.settings.spiritualFatherName,
                    hint = "Name",
                ) { next -> state.updateSettings { it.copy(spiritualFatherName = next) } }
                // Blanks the name only. Rules that already recorded it as who
                // suggested them keep that text.
                Text(
                    "Clear",
                    color = if (state.settings.spiritualFatherName.isEmpty()) Chotki.faint else Chotki.gold,
                    fontSize = 13.5.sp,
                    modifier = Modifier
                        .padding(start = 12.dp, end = 12.dp, bottom = 10.dp)
                        .clickable {
                            state.updateSettings { it.copy(spiritualFatherName = "") }
                        }
                        .semantics { contentDescription = "Clear spiritual father's name" },
                )
            }

            Group("Your church")
            Panel {
                Box {
                    ValueRow("Jurisdiction", state.settings.jurisdiction.name) { churchOpen = true }
                    DropdownMenu(expanded = churchOpen, onDismissRequest = { churchOpen = false }) {
                        Jurisdiction.KNOWN.forEach { church ->
                            DropdownMenuItem(
                                text = { Text(church.name, color = Chotki.parchment, fontSize = 14.sp) },
                                onClick = {
                                    churchOpen = false
                                    state.updateSettings { it.copy(jurisdiction = church) }
                                },
                            )
                        }
                    }
                }
                Hairline()
                ValueRow("Reckoning", state.settings.jurisdiction.reckoning.shortName()) {
                    val next = if (state.settings.jurisdiction.reckoning == Reckoning.JULIAN) {
                        Reckoning.REVISED_JULIAN
                    } else {
                        Reckoning.JULIAN
                    }
                    state.updateSettings { it.copy(jurisdiction = it.jurisdiction.copy(reckoning = next)) }
                }
            }

            Group("The calendar")
            Panel {
                SegmentRow("Fasting", state.settings.observances.fasting) { chosen ->
                    state.updateSettings {
                        it.copy(observances = it.observances.copy(fasting = chosen))
                    }
                }
                Hairline()
                SegmentRow("Feasts", state.settings.observances.feasts) { chosen ->
                    state.updateSettings {
                        it.copy(observances = it.observances.copy(feasts = chosen))
                    }
                }
                Hairline()
                SwitchRow("Old-style dates", state.settings.showOldStyleDates) { on ->
                    state.updateSettings { it.copy(showOldStyleDates = on) }
                }
            }
            Help("Shown reports what the calendar marks. Observed is a rule you take on. Neither is assumed.")

            Group("Reminders")
            Panel {
                SwitchRow("Notifications", state.settings.reminders.notificationsEnabled) { on ->
                    state.updateSettings {
                        it.copy(reminders = it.reminders.copy(notificationsEnabled = on))
                    }
                }
                Hairline()
                Box {
                    ValueRow("Lead", state.settings.reminders.defaultLead.shortName()) { leadOpen = true }
                    DropdownMenu(expanded = leadOpen, onDismissRequest = { leadOpen = false }) {
                        ReminderLead.CHOICES.forEach { lead ->
                            DropdownMenuItem(
                                text = { Text(lead.shortName(), color = Chotki.parchment, fontSize = 14.sp) },
                                onClick = {
                                    leadOpen = false
                                    state.updateSettings {
                                        it.copy(reminders = it.reminders.copy(defaultLead = lead))
                                    }
                                },
                            )
                        }
                    }
                }
            }
            Help("Turning these off silences the app. It does not change what is due, or how anything is counted.")

            Group("Prayer rope")
            Panel {
                SwitchRow("Chime when a knot is complete", state.settings.chimeOnCompletion) { on ->
                    state.updateSettings { it.copy(chimeOnCompletion = on) }
                }
                Hairline()
                SwitchRow("Click on each knot", state.settings.tickEachKnot) { on ->
                    state.updateSettings { it.copy(tickEachKnot = on) }
                }
            }

            Group("Your record")
            Panel {
                ValueRow("Export a backup", "JSON") { save.launch(Keeping.suggestedName()) }
                Hairline()
                ValueRow("Restore from a backup", "Merges") {
                    restore.launch(arrayOf("application/json", "*/*"))
                }
            }
            keepingNotice?.let { Help(it) }

            Group("General")
            Panel {
                SwitchRow("Consistency figure", state.settings.showConsistencyNumber) { on ->
                    state.updateSettings { it.copy(showConsistencyNumber = on) }
                }
                Hairline()
                ValueRow("Clock", state.settings.clockStyle.shortName()) {
                    val next = if (state.settings.clockStyle == ClockStyle.TWENTY_FOUR_HOUR) {
                        ClockStyle.TWELVE_HOUR
                    } else {
                        ClockStyle.TWENTY_FOUR_HOUR
                    }
                    state.setClockStyle(next)
                }
            }
        }
    }
}

private fun Reckoning.shortName(): String = when (this) {
    Reckoning.JULIAN -> "Old calendar"
    Reckoning.REVISED_JULIAN -> "New calendar"
}

private fun ClockStyle.shortName(): String = when (this) {
    ClockStyle.TWENTY_FOUR_HOUR -> "24-hour"
    ClockStyle.TWELVE_HOUR -> "12-hour"
}

private fun ReminderLead.shortName(): String = when (this) {
    ReminderLead.AT_THE_TIME -> "At the time"
    ReminderLead.TEN_MINUTES -> "10 minutes"
    ReminderLead.THIRTY_MINUTES -> "30 minutes"
    ReminderLead.ONE_HOUR -> "1 hour"
    ReminderLead.TWO_HOURS -> "2 hours"
    ReminderLead.THE_EVENING_BEFORE -> "The evening before"
}

@Composable
private fun Group(title: String) {
    Text(
        title,
        color = Chotki.faint,
        fontSize = 11.sp,
        modifier = Modifier.padding(start = 6.dp, top = 8.dp, bottom = 3.dp),
    )
}

@Composable
private fun Help(text: String) {
    Text(
        text,
        color = Chotki.faint,
        fontSize = 11.sp,
        lineHeight = 15.sp,
        modifier = Modifier.padding(start = 6.dp, end = 6.dp, top = 4.dp),
    )
}

@Composable
private fun Panel(content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Chotki.panel),
    ) { content() }
}

@Composable
private fun Hairline() {
    Box(Modifier.fillMaxWidth().height(1.dp).background(Color(0xFF23242C)))
}

@Composable
private fun NameField(
    label: String,
    value: String,
    hint: String,
    onChange: (String) -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp)) {
        Text(label, color = Chotki.parchment, fontSize = 13.5.sp)
        BasicTextField(
            value = value,
            onValueChange = onChange,
            singleLine = true,
            textStyle = TextStyle(
                color = Chotki.parchment,
                fontFamily = FontFamily.Serif,
                fontSize = 15.sp,
            ),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
            cursorBrush = SolidColor(Chotki.gold),
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 4.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF12131A))
                .padding(horizontal = 10.dp, vertical = 8.dp)
                .semantics { contentDescription = label },
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty()) {
                        Text(
                            hint,
                            color = Chotki.faint,
                            fontFamily = FontFamily.Serif,
                            fontSize = 15.sp,
                        )
                    }
                    inner()
                }
            },
        )
    }
}

@Composable
private fun ValueRow(label: String, value: String, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics { contentDescription = label },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = Chotki.parchment, fontSize = 13.5.sp)
        Text(
            value,
            color = Chotki.muted,
            fontSize = 12.sp,
            textAlign = TextAlign.End,
            modifier = Modifier.weight(1f).padding(start = 12.dp),
        )
    }
}

@Composable
private fun SwitchRow(label: String, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickable { onChange(!on) }
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics { contentDescription = label },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            color = Chotki.parchment,
            fontSize = 13.5.sp,
            modifier = Modifier.weight(1f).padding(end = 10.dp),
        )
        Switch(on)
    }
}

@Composable
private fun Switch(on: Boolean) {
    Box(
        Modifier
            .size(width = 32.dp, height = 18.dp)
            .clip(RoundedCornerShape(99.dp))
            .background(if (on) Color(0xFF3D3418) else Color(0xFF2A2C34)),
    ) {
        Box(
            Modifier
                .padding(2.dp)
                .size(14.dp)
                .align(if (on) Alignment.CenterEnd else Alignment.CenterStart)
                .clip(CircleShape)
                .background(if (on) Chotki.gold else Chotki.faint),
        )
    }
}

@Composable
private fun SegmentRow(label: String, selected: Observance, onSelect: (Observance) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = Chotki.parchment, fontSize = 13.5.sp, modifier = Modifier.weight(1f))
        Row(
            Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(Color(0xFF12131A))
                .padding(2.dp),
        ) {
            for (option in Observance.entries) {
                val on = option == selected
                val name = option.name.lowercase().replaceFirstChar { it.uppercase() }
                Text(
                    name,
                    color = if (on) Chotki.gold else Chotki.faint,
                    fontSize = 11.sp,
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .background(if (on) Color(0xFF2A2618) else Color.Transparent)
                        .clickable { onSelect(option) }
                        .padding(horizontal = 7.dp, vertical = 4.dp)
                        .semantics { contentDescription = "$label $name" },
                )
            }
        }
    }
}
