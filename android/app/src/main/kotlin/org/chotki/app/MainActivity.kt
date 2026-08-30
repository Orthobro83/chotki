package org.chotki.app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.Shell

class MainActivity : ComponentActivity() {

    private lateinit var state: AppState

    private val askNotifications =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge to edge on every version, not only where it is forced.
        //
        // From Android 15 an app targeting SDK 35 or later gets this whether it
        // asks or not, and this one targets 37 — so on a new phone the bottom
        // bar was drawing underneath the gesture pill, with the pill sitting
        // across Reading and Progress. Opting in everywhere means one behaviour
        // to handle rather than two, and the insets below are applied by the app
        // on old versions as well as new.
        enableEdgeToEdge()
        state = AppState.open(this)
        state.load()

        // Asked once, plainly, and not insisted on. From Android 13 nothing
        // appears without it and nothing errors — so the alternative to asking
        // is reminders that silently never come.
        if (Build.VERSION.SDK_INT >= 33) {
            askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        // Fills in the fortnight ahead, off the main thread. The interface shows
        // what is already stored meanwhile rather than a spinner.
        state.refreshCalendar()

        setContent {
            ChotkiTheme {
                Shell(state)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (::state.isInitialized) {
            // Before load(), so what is loaded is the right day's.
            state.advanceDayIfNeeded()
            state.load()
            state.rearmReminders(this)
            state.refreshCalendar()
        }
        // Midnight, and any clock or timezone change, for the case where the
        // app is left open in the foreground and nobody backgrounds it.
        // Registered only while resumed: a receiver alive behind a screen
        // nobody is looking at would be waking the phone for nothing.
        ContextCompat.registerReceiver(
            this,
            dayChanged,
            IntentFilter().apply {
                addAction(Intent.ACTION_DATE_CHANGED)
                addAction(Intent.ACTION_TIME_CHANGED)
                addAction(Intent.ACTION_TIMEZONE_CHANGED)
            },
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onPause() {
        super.onPause()
        runCatching { unregisterReceiver(dayChanged) }
    }

    private val dayChanged = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (::state.isInitialized) state.advanceDayIfNeeded()
        }
    }
}
