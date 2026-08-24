package org.chotki.app.platform

import android.content.Context
import org.chotki.core.AppSettings
import org.chotki.core.CalendarDate
import org.chotki.core.RecurrenceEngine
import org.chotki.core.scheduling.Scheduler
import org.chotki.core.store.SqliteStore
import java.time.Instant
import java.time.ZoneId

/**
 * The one place the app turns a stored rule into an armed alarm.
 *
 * Everything here is bookkeeping: what to remind about, and when, is decided by
 * `Scheduler` in `:core`, which knows nothing about Android.
 */
object Reminders {

    fun rearm(context: Context, now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()) {
        val db = AndroidDb.open(context)
        try {
            val store = SqliteStore(db)
            val settings = store.loadSettings() ?: AppSettings.DEFAULT
            val today = CalendarDate.from(now, zone)

            val scheduler = Scheduler(
                engine = RecurrenceEngine(observances = settings.observances),
                policy = settings.reminders,
                zone = zone,
            )

            // Only what is still ahead. Arming an alarm for a moment that has
            // passed fires it immediately, which is how a reboot at lunchtime
            // would deliver the whole morning at once.
            val pending = scheduler.pending(
                rules = store.rules(),
                activations = store.activations(),
                occurrences = store.occurrences(from = today, through = today),
                on = today,
                after = now,
            )
            ReminderAlarms(context).arm(pending)
        } finally {
            db.close()
        }
    }
}
