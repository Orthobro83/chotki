package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState

/**
 * Where the app can be: the same seven places the macOS sidebar offers.
 *
 * The Library is reached from the day rather than living here, because taking a
 * rule on is something you do while looking at what you already keep — which is
 * the judgement the whole screen exists to support.
 */
enum class Place(val title: String) {
    RULE("Rule"),
    PRAYERS("Prayers"),
    READING("Reading"),
    PROGRESS("Progress"),
    GLOSSARY("Glossary"),
    SETTINGS("Settings"),
}

@Composable
fun Shell(state: AppState) {
    var place by remember { mutableStateOf(Place.RULE) }
    var showingLibrary by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val readiness = remember(place, showingLibrary) { ReminderReadiness.of(context) }

    Column(Modifier.fillMaxSize().background(Chotki.ground)) {
        // Only when something is actually wrong, and only about the app's own
        // ability to do what it said — never about the person's practice.
        ReadinessBanner(readiness)

        Column(Modifier.weight(1f)) {
            when {
                showingLibrary -> {
                    Text(
                        "‹ The day",
                        color = Chotki.gold,
                        fontSize = 15.sp,
                        modifier = Modifier
                            .clickable { showingLibrary = false }
                            .padding(16.dp)
                            .semantics { contentDescription = "Back to the day" },
                    )
                    LibrarySheet(state, Modifier.weight(1f))
                }

                place == Place.RULE -> {
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

                place == Place.PRAYERS -> PrayersScreen(Modifier.weight(1f))
                place == Place.READING -> ReadingScreen(state, Modifier.weight(1f))
                place == Place.PROGRESS -> ProgressScreen(state, Modifier.weight(1f))
                place == Place.GLOSSARY -> GlossaryScreen(Modifier.weight(1f))
                place == Place.SETTINGS -> SettingsScreen(state, Modifier.weight(1f))
            }
        }

        Row(Modifier.fillMaxWidth().background(Chotki.panel)) {
            for (candidate in Place.entries) {
                Text(
                    candidate.title,
                    color = if (candidate == place) Chotki.gold else Chotki.muted,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .clickable {
                            place = candidate
                            showingLibrary = false
                        }
                        .padding(vertical = 12.dp)
                        .semantics { contentDescription = "Go to ${candidate.title}" },
                )
            }
        }
    }
}
