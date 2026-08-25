package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.ClockStyle
import org.chotki.app.BuildConfig

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

    // The two pickers are Android's own, so no storage permission is involved
    // and the person chooses where their record goes.
    var keepingNotice by remember { mutableStateOf<String?>(null) }
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

        Heading("The clock")
        // Missing entirely until now, which left the hour picker labelling
        // itself 00 to 23 with no way to change it — and made "08:45" read as
        // a quarter to nine in the evening to anyone thinking in twelve hours.
        Dropdown(
            label = "How times are written",
            chosen = state.settings.clockStyle.displayName,
            options = ClockStyle.entries.map { it.displayName },
        ) { index -> state.setClockStyle(ClockStyle.entries[index]) }

        Heading("Reminders")
        // Always here, whether or not the banner has been put away — and each
        // one opens the screen where it is actually changed, rather than naming
        // a setting and leaving the person to find it.
        Diagnostic("Notifications", readiness.notificationsAllowed) {
            context.startActivity(notificationSettingsIntent(context))
        }
        Diagnostic("Exact alarms", readiness.exactAlarmsAllowed) {
            exactAlarmSettingsIntent(context)?.let(context::startActivity)
        }
        Diagnostic(
            "Allowed to run in the background",
            readiness.exemptFromBatteryOptimisation,
        ) {
            context.startActivity(batteryExemptionIntent(context))
        }
        if (readiness.hasVendorSleepList) {
            Line(
                "This phone also keeps its own list, on top of Android's. Add " +
                    "Chotki to ${ReminderReadiness.VENDOR_ROUTE}, or reminders stop " +
                    "after a day or two.",
                Chotki.faint,
            )
            // No app can read or set that list, so the app cannot tell you
            // whether it worked — and saying so is better than implying it can.
            Line(
                "Chotki cannot see that list or change it, so it cannot tell you " +
                    "whether it took. If Chotki is not offered there, open it and " +
                    "leave it a moment first — some phones only list apps they have " +
                    "seen running. The setting above is Android's own and matters most.",
                Chotki.faint,
            )
        }

        Heading("Your record")
        // Android gives an app no place to leave anything behind and Chotki
        // turns Android's own backup off, so this is the only way a record
        // reaches a new phone. Said plainly, because someone who does not know
        // it will find out the hard way.
        Line(
            "Your record is kept on this phone only. It is not sent anywhere, and " +
                "uninstalling Chotki takes it with it. Save a copy before you change phones.",
            Chotki.faint,
        )
        Action("Save a copy of your record") { save.launch(Keeping.suggestedName()) }
        Action("Restore from a copy") { restore.launch(arrayOf("application/json", "*/*")) }
        keepingNotice?.let { Line(it, Chotki.gold) }

        Heading("This is an alpha")
        Line(
            "Chotki ${BuildConfig.VERSION_NAME} (build ${BuildConfig.VERSION_CODE})",
            Chotki.parchment,
        )
        Line(
            "The glossary, the prayers and the readings are awaiting a priest's review. " +
                "Nothing here tells you what you must do; what you keep is settled with your priest or spiritual father.",
            Chotki.faint,
        )
        // On macOS this framing reaches you through the releases page. An apk is
        // passed from hand to hand with no page attached, so it has to travel
        // inside the app or it does not travel at all.
        Line(
            "Chotki is an independent project. It was inspired by The Brotherhood " +
                "of the Narrow Path, but it is not sanctioned by, affiliated with, or " +
                "endorsed by them, and nothing in it speaks for them.",
            Chotki.faint,
        )
        Line(
            "Not open source. During the alpha you may install and run it for your own " +
                "use. Please do not sell it or pass it on further.",
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
 *
 * Tapping opens the system screen where the setting lives. Naming a permission
 * and leaving someone to hunt for it through Android's settings is not help.
 */
@Composable
private fun Diagnostic(label: String, allowed: Boolean, onOpen: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onOpen)
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .semantics { contentDescription = "$label readiness" },
    ) {
        Text(
            "$label — ${if (allowed) "allowed" else "not allowed"}",
            color = if (allowed) Chotki.parchment else Chotki.gold,
            fontSize = 14.sp,
        )
        Text(
            if (allowed) "Tap to review" else "Tap to change this",
            color = Chotki.faint,
            fontSize = 12.sp,
        )
    }
}

/** A line that does something, told apart from the rest by being gold. */
@Composable
private fun Action(label: String, onTap: () -> Unit) {
    Text(
        label,
        color = Chotki.gold,
        fontSize = 15.sp,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .semantics { contentDescription = label },
    )
}
