package org.chotki.app.platform

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import org.chotki.core.NotificationRequest
import org.chotki.core.Notifier

/**
 * Shows what `:core` decided. It decides nothing itself.
 *
 * Notification identity is the string id core already generates, carried as the
 * notification *tag* rather than squeezed into an integer. That is what lets
 * every reminder for one occurrence be cancelled together the moment the rule is
 * marked kept — hashing the string into an int would work until two of them
 * collided, silently, on somebody's phone.
 */
class AndroidNotifier(private val context: Context) : Notifier {

    companion object {
        const val CHANNEL_ID = "reminders"
        const val EXTRA_REQUEST_ID = "org.chotki.request"
        const val EXTRA_ACTION_ID = "org.chotki.action"

        /**
         * Created once and kept. The channel's importance is the user's to
         * change from Android 8 onwards, and the app must not fight that: if
         * they turn it down, reminders are quieter, and that is a decision they
         * are entitled to make.
         */
        fun ensureChannel(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Reminders",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "What is on your rule today."
                },
            )
        }
    }

    override val supportsActions: Boolean = true

    /**
     * Whether notifications can actually be shown.
     *
     * From Android 13 this is a runtime permission, and without it nothing
     * appears and nothing errors — the single most likely way for reminders to
     * fail silently on the test device. Asking for it needs an Activity, so this
     * only reports; the first-run screen does the asking.
     */
    override fun requestAuthorization(): Boolean {
        if (android.os.Build.VERSION.SDK_INT < 33) return true
        return context.checkSelfPermission(
            android.Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    override fun show(request: NotificationRequest) {
        ensureChannel(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(request.id, 0, build(request))
    }

    override fun cancel(ids: List<String>) {
        val manager = context.getSystemService(NotificationManager::class.java)
        for (id in ids) manager.cancel(id, 0)
    }

    private fun build(request: NotificationRequest): Notification {
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(request.title)
            .setContentText(request.body)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)

        for (action in request.actions) {
            builder.addAction(
                0,
                action.title,
                pendingAction(requestID = request.id, actionID = action.id),
            )
        }
        return builder.build()
    }

    private fun pendingAction(requestID: String, actionID: String): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ReminderReceiver.ACTION_BUTTON
            putExtra(EXTRA_REQUEST_ID, requestID)
            putExtra(EXTRA_ACTION_ID, actionID)
        }
        return PendingIntent.getBroadcast(
            context,
            "$requestID:$actionID".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
