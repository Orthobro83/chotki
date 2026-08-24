package org.chotki.core

import kotlinx.serialization.Serializable

/** One button on a notification. */
@Serializable
data class NotificationAction(val id: String, val title: String) {
    companion object {
        /**
         * Copy is deliberately neutral: a reminder says what is due, never how
         * overdue it is.
         */
        val MARK_COMPLETE = NotificationAction("complete", "Mark complete")
        val SNOOZE = NotificationAction("snooze", "Snooze an hour")
    }
}

@Serializable
data class NotificationRequest(
    /** Stable, so the scheduler can cancel every pending reminder for one occurrence. */
    val id: String,
    val title: String,
    val body: String,
    val actions: List<NotificationAction> = emptyList(),
)

data class NotificationActionEvent(val requestID: String, val actionID: String)

/**
 * Implemented per platform. Core decides *when*; this only *shows*.
 *
 * `supportsActions` is not decoration — a platform that ignores action buttons
 * must degrade to a plain notification rather than losing the reminder.
 *
 * Synchronous, unlike the Swift original, which returns an `AsyncStream` of
 * action events. Adding a coroutines dependency to `:core` for one callback is
 * not a trade worth making: Android pushes action events in rather than core
 * pulling them out.
 */
interface Notifier {
    val supportsActions: Boolean
    fun requestAuthorization(): Boolean
    fun show(request: NotificationRequest)
    fun cancel(ids: List<String>)
}
