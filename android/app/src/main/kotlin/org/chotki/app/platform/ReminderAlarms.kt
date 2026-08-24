package org.chotki.app.platform

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.chotki.core.scheduling.PlannedNotification

/**
 * Arms the alarms for what `:core` has planned.
 *
 * Exact alarms, because a rule kept at 06:30 reminded "sometime this morning" is
 * not a reminder. From Android 12 that needs permission; without it the system
 * downgrades to an inexact alarm rather than refusing, which means the failure
 * is a reminder that drifts rather than one that never comes — quieter, and
 * harder to notice.
 */
class ReminderAlarms(private val context: Context) {

    private val alarms = context.getSystemService(AlarmManager::class.java)

    /** Whether exact alarms are permitted. Reported, not demanded. */
    fun canScheduleExact(): Boolean =
        if (Build.VERSION.SDK_INT >= 31) alarms.canScheduleExactAlarms() else true

    fun arm(planned: List<PlannedNotification>) {
        for (notification in planned) {
            val pending = pendingFire(notification)
            val at = notification.fireAt.toEpochMilli()
            if (canScheduleExact()) {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                // Better late than never, and the diagnostic screen says which
                // of the two is happening rather than leaving it a mystery.
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
    }

    fun cancel(planned: List<PlannedNotification>) {
        for (notification in planned) alarms.cancel(pendingFire(notification))
    }

    private fun pendingFire(notification: PlannedNotification): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_FIRE
            // The whole notification travels with the alarm: it may fire long
            // after the process that armed it is gone.
            putExtra(ReminderReceiver.EXTRA_REQUEST, ReminderReceiver.encode(notification.request))
        }
        return PendingIntent.getBroadcast(
            context,
            notification.id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
