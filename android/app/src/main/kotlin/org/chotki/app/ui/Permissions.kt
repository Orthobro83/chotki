package org.chotki.app.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.chotki.app.platform.AndroidNotifier
import org.chotki.app.platform.ReminderAlarms

/**
 * What the phone currently allows, for the Settings screen to say plainly.
 *
 * There is no banner and no nagging: the app asks for notifications once, on the first launch, and
 * after that this is where the permission is seen and changed. Battery optimisation is not asked
 * about at all. Reminders at a set hour need the "alarms and reminders" access on Android 12 and
 * later (`SCHEDULE_EXACT_ALARM`, which the person grants; Play does not allow `USE_EXACT_ALARM`
 * for an app that is neither an alarm clock nor a calendar); without it they still arrive, a little
 * late, and Settings says so.
 */
data class PhonePermissions(
    val notificationsAllowed: Boolean,
    val exactAlarmsAllowed: Boolean,
    /** Below Android 12 there is nothing to grant, so there is nothing to show. */
    val exactAlarmsNeedAGrant: Boolean,
) {
    companion object {
        fun of(context: Context) = PhonePermissions(
            notificationsAllowed = AndroidNotifier(context).requestAuthorization(),
            exactAlarmsAllowed = ReminderAlarms(context).canScheduleExact(),
            exactAlarmsNeedAGrant = Build.VERSION.SDK_INT >= 31,
        )
    }
}

/** This app's own notification settings, where the permission can be restored. */
fun notificationSettingsIntent(context: Context): Intent =
    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)

fun exactAlarmSettingsIntent(context: Context): Intent? =
    if (Build.VERSION.SDK_INT >= 31) {
        Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            .setData(Uri.parse("package:${context.packageName}"))
    } else {
        null
    }
