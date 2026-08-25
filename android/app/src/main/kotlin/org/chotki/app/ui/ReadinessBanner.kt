package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Says plainly whether reminders are going to arrive.
 *
 * Shown only when something is actually wrong, and never as a warning about the
 * person's practice — it is a statement about the app's own ability to do what it
 * said it would.
 *
 * Dismissible, and dismissed by what is wrong rather than once and for all: put
 * the battery warning away and it stays away, but a notification permission
 * revoked next week still speaks up. It is always in Settings either way, so
 * dismissing it loses nothing.
 */
@Composable
fun ReadinessBanner(
    readiness: ReminderReadiness,
    modifier: Modifier = Modifier,
    onDismiss: () -> Unit = {},
) {
    if (readiness.allClear && !readiness.hasVendorSleepList) return
    val context = LocalContext.current

    Column(
        modifier
            .fillMaxWidth()
            .background(Chotki.panel)
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .semantics { contentDescription = "Reminder readiness" },
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(Modifier.weight(1f)) {
                if (!readiness.notificationsAllowed) {
                    Text("Chotki cannot show notifications yet.", color = Chotki.gold, fontSize = 14.sp)
                    Text(
                        "Without this, reminders never appear and nothing says so. Tap to allow.",
                        color = Chotki.goldDim,
                        fontSize = 13.sp,
                        modifier = Modifier
                            .clickable { context.startActivity(notificationSettingsIntent(context)) }
                            .semantics { contentDescription = "Allow notifications" },
                    )
                }
                if (!readiness.exactAlarmsAllowed) {
                    Text("Reminders may arrive late.", color = Chotki.gold, fontSize = 14.sp)
                    Text(
                        "Exact alarms are not permitted, so a rule kept at a set hour is " +
                            "reminded whenever the system finds convenient. Tap to allow.",
                        color = Chotki.goldDim,
                        fontSize = 13.sp,
                        modifier = Modifier
                            .clickable {
                                exactAlarmSettingsIntent(context)?.let(context::startActivity)
                            }
                            .semantics { contentDescription = "Allow exact alarms" },
                    )
                }
                if (!readiness.exemptFromBatteryOptimisation) {
                    Text("Battery saving may hold reminders back.", color = Chotki.gold, fontSize = 14.sp)
                    Text(
                        "Tap to let Chotki run in the background.",
                        color = Chotki.goldDim,
                        fontSize = 13.sp,
                        modifier = Modifier
                            .clickable { context.startActivity(batteryExemptionIntent(context)) }
                            .semantics { contentDescription = "Allow background" },
                    )
                }
                if (readiness.hasVendorSleepList) {
                    // Cannot be read or set from code, so the route is named and
                    // the decision left with the person.
                    Text(
                        "On Samsung phones, also add Chotki to " +
                            "${ReminderReadiness.VENDOR_ROUTE}, or reminders stop after a day " +
                            "or two.",
                        color = Chotki.faint,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }
            }

            Text(
                "✕",
                color = Chotki.muted,
                fontSize = 15.sp,
                modifier = Modifier
                    .clickable(onClick = onDismiss)
                    .padding(start = 12.dp, top = 2.dp)
                    .semantics { contentDescription = "Dismiss this notice" },
            )
        }

        Text(
            "This stays in Settings.",
            color = Chotki.faint,
            fontSize = 11.sp,
            modifier = Modifier.padding(top = 6.dp),
        )
    }
}
