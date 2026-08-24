package org.chotki.app.platform

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.serialization.json.Json
import org.chotki.core.NotificationRequest

/**
 * What happens when an alarm goes off, and when a button on a reminder is
 * pressed.
 *
 * The alarm carries the whole notification with it rather than an id to look up.
 * A reminder that fires an hour after the app was last killed must not depend on
 * anything still being in memory, and re-deriving it would mean opening the
 * database on the main thread of a broadcast.
 */
class ReminderReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE = "org.chotki.FIRE"
        const val ACTION_BUTTON = "org.chotki.BUTTON"
        const val EXTRA_REQUEST = "org.chotki.request_json"

        private val json = Json { ignoreUnknownKeys = true }

        fun encode(request: NotificationRequest): String =
            json.encodeToString(NotificationRequest.serializer(), request)

        fun decode(text: String): NotificationRequest =
            json.decodeFromString(NotificationRequest.serializer(), text)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_FIRE -> {
                val payload = intent.getStringExtra(EXTRA_REQUEST) ?: return
                AndroidNotifier(context).show(decode(payload))
            }

            ACTION_BUTTON -> {
                val requestID = intent.getStringExtra(AndroidNotifier.EXTRA_REQUEST_ID) ?: return
                val actionID = intent.getStringExtra(AndroidNotifier.EXTRA_ACTION_ID) ?: return
                // Taken down as soon as it is acted on, whichever button it was.
                AndroidNotifier(context).cancel(listOf(requestID))
                PendingActions.record(requestID, actionID)
            }
        }
    }
}

/**
 * Button presses, held until something is awake to apply them.
 *
 * A broadcast receiver has a few milliseconds and no business opening a
 * database. Marking a rule kept is a decision `:core` makes against the store,
 * so the press is recorded here and applied when the app next runs.
 */
object PendingActions {
    private val lock = Any()
    private val recorded = mutableListOf<Pair<String, String>>()

    fun record(requestID: String, actionID: String) {
        synchronized(lock) { recorded.add(requestID to actionID) }
    }

    /** Returns what has accumulated and clears it. */
    fun drain(): List<Pair<String, String>> = synchronized(lock) {
        val out = recorded.toList()
        recorded.clear()
        out
    }
}
