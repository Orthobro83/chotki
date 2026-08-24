package org.chotki.app.platform

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Alarms do not survive a restart, so they are armed again.
 *
 * Without this, a phone rebooted overnight — which is when phones tend to
 * reboot — comes back with nothing scheduled, and the day passes in silence
 * with no indication that anything is wrong.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Reminders.rearm(context)
    }
}
