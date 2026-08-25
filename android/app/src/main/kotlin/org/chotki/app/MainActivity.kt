package org.chotki.app

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.ui.Chotki
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.LibrarySheet
import org.chotki.app.ui.ReadinessBanner
import org.chotki.app.ui.ReminderReadiness
import org.chotki.app.ui.RuleScreen

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
                Chotki(state)
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

@androidx.compose.runtime.Composable
private fun Chotki(state: AppState) {
    var showingLibrary by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val readiness = remember(showingLibrary) { ReminderReadiness.of(context) }

    Column(Modifier.fillMaxSize().background(Chotki.ground)) {
        ReadinessBanner(readiness)

        if (showingLibrary) {
            Row(
                Modifier.fillMaxWidth().padding(16.dp),
            ) {
                Text(
                    "‹ The day",
                    color = Chotki.gold,
                    fontSize = 15.sp,
                    modifier = Modifier
                        .clickable { showingLibrary = false }
                        .semantics { contentDescription = "Back to the day" },
                )
            }
            LibrarySheet(state, Modifier.weight(1f))
        } else {
            RuleScreen(state, Modifier.weight(1f))
            Text(
                "Library",
                color = Chotki.gold,
                fontSize = 15.sp,
                modifier = Modifier
                    .clickable { showingLibrary = true }
                    .padding(16.dp)
                    .semantics { contentDescription = "Open the library" },
            )
        }
    }
}
