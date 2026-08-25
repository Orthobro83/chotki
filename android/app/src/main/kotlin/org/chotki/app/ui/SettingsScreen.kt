package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState

/**
 * What can be changed, and a plain account of whether reminders will arrive.
 *
 * The diagnostic is the part that matters. Permissions get revoked, phones get
 * replaced, and OEM updates reset these lists — so this is a standing report
 * rather than a wizard shown once and forgotten.
 */
@Composable
fun SettingsScreen(state: AppState, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val readiness = ReminderReadiness.of(context)

    Column(
        modifier
            .fillMaxSize()
            .background(Chotki.ground)
            .verticalScroll(rememberScrollState()),
    ) {
        Heading("Your church")
        Line(state.settings.jurisdiction.name, Chotki.parchment)
        Line(state.settings.jurisdiction.reckoning.displayName, Chotki.goldDim)
        for (note in state.settings.jurisdiction.practice.notes) Line(note, Chotki.faint)

        Heading("The calendar")
        Line("Fasting — ${state.settings.observances.fasting.name.lowercase()}", Chotki.parchment)
        Line("Feasts — ${state.settings.observances.feasts.name.lowercase()}", Chotki.parchment)

        Heading("Reminders")
        Diagnostic("Notifications", readiness.notificationsAllowed)
        Diagnostic("Exact alarms", readiness.exactAlarmsAllowed)
        Diagnostic("Allowed to run in the background", readiness.exemptFromBatteryOptimisation)
        if (readiness.hasVendorSleepList) {
            Line(
                "This phone also keeps its own list. Add Chotki to " +
                    "${ReminderReadiness.VENDOR_ROUTE}, or reminders stop after a day or two.",
                Chotki.faint,
            )
        }

        Heading("This is an alpha")
        Line(
            "The glossary, the prayers and the readings are awaiting a priest's review. " +
                "Nothing here tells you what you must do; what you keep is settled with your priest.",
            Chotki.faint,
        )
        Spacer(Modifier.size(32.dp))
    }
}

@Composable
private fun Heading(text: String) {
    Text(
        text,
        color = Chotki.gold,
        fontSize = 13.sp,
        modifier = Modifier.padding(start = 16.dp, top = 18.dp, bottom = 4.dp),
    )
}

@Composable
private fun Line(text: String, colour: androidx.compose.ui.graphics.Color) {
    Text(text, color = colour, fontSize = 14.sp, modifier = Modifier.padding(horizontal = 16.dp, vertical = 3.dp))
}

/**
 * Stated as a fact, never as a scolding. The app is reporting on itself.
 */
@Composable
private fun Diagnostic(label: String, allowed: Boolean) {
    Text(
        "$label — ${if (allowed) "allowed" else "not allowed"}",
        color = if (allowed) Chotki.parchment else Chotki.gold,
        fontSize = 14.sp,
        modifier = Modifier
            .padding(horizontal = 16.dp, vertical = 3.dp)
            .semantics { contentDescription = "$label readiness" },
    )
}
