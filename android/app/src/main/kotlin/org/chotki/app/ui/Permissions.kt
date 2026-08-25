package org.chotki.app.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import org.chotki.app.platform.AndroidNotifier
import org.chotki.app.platform.ReminderAlarms

/**
 * Whether a reminder will actually arrive.
 *
 * Three separate systems have to agree, and **each one fails silently**: a
 * notification permission that was never asked for, an exact alarm quietly
 * downgraded to an inexact one, and battery optimisation deferring both. None of
 * them produces an error; the reminder simply does not come, or comes at the
 * wrong time.
 *
 * So this is a standing report rather than a one-off wizard. Permissions get
 * revoked, phones get replaced, and OEM updates reset these lists. An app whose
 * whole point is honest measurement should be able to say plainly whether its
 * reminders are going to arrive.
 */
data class ReminderReadiness(
    val notificationsAllowed: Boolean,
    val exactAlarmsAllowed: Boolean,
    val exemptFromBatteryOptimisation: Boolean,
    /** Samsung keeps its own list, which cannot be read or set from here. */
    val hasVendorSleepList: Boolean,
) {
    val allClear: Boolean
        get() = notificationsAllowed && exactAlarmsAllowed && exemptFromBatteryOptimisation

    companion object {
        fun of(context: Context): ReminderReadiness {
            val power = context.getSystemService(PowerManager::class.java)
            return ReminderReadiness(
                notificationsAllowed = AndroidNotifier(context).requestAuthorization(),
                exactAlarmsAllowed = ReminderAlarms(context).canScheduleExact(),
                exemptFromBatteryOptimisation =
                    power.isIgnoringBatteryOptimizations(context.packageName),
                hasVendorSleepList = isSamsung(),
            )
        }

        /**
         * OneUI puts apps it decides are idle into a "sleeping apps" list that is
         * separate from the standard exemption, and can be neither read nor set
         * programmatically. Being exempt from Doze does not remove an app from
         * it. All the app can do is name the route.
         */
        fun isSamsung(): Boolean =
            Build.MANUFACTURER.equals("samsung", ignoreCase = true)

        const val VENDOR_ROUTE =
            "Settings › Battery › Background usage limits › Never sleeping apps"
    }
}

/** Opens the system's own battery-optimisation dialogue for this app. */
fun batteryExemptionIntent(context: Context): Intent =
    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
        .setData(Uri.parse("package:${context.packageName}"))

/**
 * The always-permitted fallback: opens the list and lets the person find the app.
 *
 * Google Play restricts the direct request above to apps with a qualifying use
 * case. That does not apply to a directly installed APK, but it would need
 * answering if the Play Store ever came up, and this route never needs
 * permission at all.
 */
fun batteryOptimisationSettingsIntent(): Intent =
    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)

fun exactAlarmSettingsIntent(context: Context): Intent? =
    if (Build.VERSION.SDK_INT >= 31) {
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            .setData(Uri.parse("package:${context.packageName}"))
    } else {
        null
    }
