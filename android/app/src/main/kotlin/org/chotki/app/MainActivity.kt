package org.chotki.app

import android.Manifest
import android.os.Build
import android.os.Bundle
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
        state = AppState.open(this)
        state.load()

        // Asked once, plainly, and not insisted on. From Android 13 nothing
        // appears without it and nothing errors — so the alternative to asking
        // is reminders that silently never come.
        if (Build.VERSION.SDK_INT >= 33) {
            askNotifications.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            ChotkiTheme {
                Shell(state)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (::state.isInitialized) {
            state.load()
            state.rearmReminders(this)
        }
    }
}
