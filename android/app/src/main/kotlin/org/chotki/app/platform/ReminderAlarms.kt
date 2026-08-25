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

    /**
     * Arms exactly [planned] — and disarms anything armed before that is not in
     * it any more.
     *
     * That second half was missing entirely, and it is the reason a rule went on
     * buzzing after it had been marked kept. `plan` correctly stops returning a
     * completed rule, but AlarmManager had already been told about it and there
     * is no way to ask the system what is armed — so what was armed has to be
     * written down here, or it can never be taken back.
     */
    fun arm(planned: List<PlannedNotification>) {
        val wanted = planned.associateBy { it.id }
        val previously = armedIDs()

        for (id in previously - wanted.keys) {
            val stale = pendingFire(id, payload = null)
            alarms.cancel(stale)
            // The PendingIntent goes too. Cancelling the alarm leaves it behind
            // and still findable, which makes "is this armed?" unanswerable —
            // including for the tests that are supposed to prove this works.
            stale.cancel()
        }

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

        remember(wanted.keys)
    }

    /**
     * What is armed right now, as ids.
     *
     * Kept in preferences because AlarmManager will not say. A PendingIntent
     * cancels by matching request code and intent action, so the id alone is
     * enough to take one back — the payload it was armed with is irrelevant.
     */
    fun armedIDs(): Set<String> = store.getStringSet(KEY, emptySet()).orEmpty()

    /**
     * Whether the system is actually holding an alarm for [id].
     *
     * Asked of AlarmManager rather than of the note this class keeps: a test
     * against its own bookkeeping passes whether or not anything was cancelled,
     * which is precisely what the first version of these tests did.
     * `FLAG_NO_CREATE` returns null when no matching PendingIntent exists.
     */
    fun isArmed(id: String): Boolean =
        PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            Intent(context, ReminderReceiver::class.java).apply {
                action = ReminderReceiver.ACTION_FIRE
            },
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) != null

    private fun remember(ids: Set<String>) {
        store.edit().putStringSet(KEY, ids).apply()
    }

    private val store =
        context.getSharedPreferences("reminder-alarms", Context.MODE_PRIVATE)

    private companion object {
        const val KEY = "armed"
    }

    fun cancel(planned: List<PlannedNotification>) {
        for (notification in planned) alarms.cancel(pendingFire(notification))
    }

    private fun pendingFire(notification: PlannedNotification): PendingIntent =
        pendingFire(
            notification.id,
            payload = ReminderReceiver.encode(notification.request),
            ruleID = notification.ruleID.toString(),
            date = notification.date.iso,
        )

    private fun pendingFire(
        id: String,
        payload: String?,
        ruleID: String? = null,
        date: String? = null,
    ): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_FIRE
            // The whole notification travels with the alarm: it may fire long
            // after the process that armed it is gone.
            payload?.let { putExtra(ReminderReceiver.EXTRA_REQUEST, it) }
            // And what it is about, so the receiver can check the rule is still
            // due and still unkept before showing anything. An alarm held back
            // by Doze can arrive well after the day has been settled.
            ruleID?.let { putExtra(ReminderReceiver.EXTRA_RULE_ID, it) }
            date?.let { putExtra(ReminderReceiver.EXTRA_DATE, it) }
        }
        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
