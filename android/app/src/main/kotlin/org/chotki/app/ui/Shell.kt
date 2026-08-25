package org.chotki.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.content.Glossary

/**
 * Where the app can be: the same seven places the macOS sidebar offers.
 *
 * The Library is reached from the day rather than living here, because taking a
 * rule on is something you do while looking at what you already keep — which is
 * the judgement the whole screen exists to support.
 */
/**
 * The bar, carrying the same meanings the macOS sidebar uses.
 *
 * The macOS icons are SF Symbols, which cannot come across. Rather than pull in
 * Material's whole extended icon set for six glyphs — it is large enough that
 * it would not even dex — they are drawn here, in the app's own line weight and
 * gold: a calendar for the rule, a rope for the prayers, an open book for the
 * reading, a rising line for progress, a closed book for the terms.
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
    var journey by remember { mutableStateOf(Journey()) }
    // Scoped once, here. Building it inside a screen would redo the filtering
    // and index rebuilding on every recomposition, and the linked text needs it
    // for every term on screen.
    val glossary = remember(state.settings.jurisdiction.tradition) {
        Glossary.shared(state.settings.jurisdiction.tradition)
    }
    val context = LocalContext.current
    val readiness = remember(journey) { ReminderReadiness.of(context) }
    val dismissals = remember { BannerDismissals(context) }
    var dismissed by remember(readiness) { mutableStateOf(dismissals.isDismissed(readiness)) }

    // Back goes back one screen, and only leaves the app from the day itself.
    // Without this it fell through to Android's default at every depth: three
    // fields into the editor, back closed Chotki.
    BackHandler(enabled = journey.canGoBack) { journey = journey.back() }

    Column(Modifier.fillMaxSize().background(Chotki.ground)) {
        if (!dismissed) {
            ReadinessBanner(readiness) {
                dismissals.dismiss(readiness)
                dismissed = true
            }
        }

        Column(Modifier.weight(1f)) {
            when (val screen = journey.current) {
                is Screen.Editor -> RuleEditor(
                    state = state,
                    existing = screen.rule,
                    startingFrom = screen.startingFrom,
                    onDone = { journey = journey.back() },
                    modifier = Modifier.weight(1f),
                )

                is Screen.RulePrayers -> {
                    val rule = state.rule(screen.ruleID)
                    if (rule == null) {
                        journey = journey.back()
                    } else {
                        RulePrayers(
                            rule = rule,
                            onBack = { journey = journey.back() },
                            modifier = Modifier.weight(1f),
                            glossary = glossary,
                            onOpenTerm = { journey = journey.push(Screen.Terms(it)) },
                        )
                    }
                }

                Screen.Psalter -> {
                    Text(
                        "‹ The day",
                        color = Chotki.gold,
                        fontSize = 15.sp,
                        modifier = Modifier
                            .clickable { journey = journey.back() }
                            .padding(16.dp)
                            .semantics { contentDescription = "Back to the day" },
                    )
                    PsalterScreen(state, Modifier.weight(1f))
                }

                Screen.Library -> {
                    Text(
                        "‹ The day",
                        color = Chotki.gold,
                        fontSize = 15.sp,
                        modifier = Modifier
                            .clickable { journey = journey.back() }
                            .padding(16.dp)
                            .semantics { contentDescription = "Back to the day" },
                    )
                    LibrarySheet(
                        state = state,
                        modifier = Modifier.weight(1f),
                        onWriteYourOwn = { journey = journey.push(Screen.Editor(null)) },
                        onTakeOn = { journey = journey.push(Screen.Editor(null, startingFrom = it)) },
                    )
                }

                Screen.Day -> {
                    RuleScreen(
                        state = state,
                        modifier = Modifier.weight(1f),
                        onReadPrayers = { journey = journey.push(Screen.RulePrayers(it.rule.id)) },
                        // The day's readings already have a place of their own.
                        onReadReading = { journey = journey.go(Place.READING) },
                        onReadPsalter = { journey = journey.push(Screen.Psalter) },
                        onEdit = { journey = journey.push(Screen.Editor(it.rule)) },
                    )
                    Text(
                        "Library",
                        color = Chotki.gold,
                        fontSize = 15.sp,
                        modifier = Modifier
                            .clickable { journey = journey.push(Screen.Library) }
                            .padding(16.dp)
                            .semantics { contentDescription = "Open the library" },
                    )
                }

                Screen.Rope -> RopeScreen(state, Modifier.weight(1f))
                Screen.Reading -> ReadingScreen(state, Modifier.weight(1f))
                Screen.Progress -> ProgressScreen(state, Modifier.weight(1f))
                Screen.Settings -> SettingsScreen(state, Modifier.weight(1f))

                is Screen.Terms -> GlossaryScreen(
                    glossary = glossary,
                    modifier = Modifier.weight(1f),
                    openSlug = screen.slug,
                    onOpen = { journey = journey.push(Screen.Terms(it)) },
                    onBack = { journey = journey.back() },
                )
            }
        }

        Row(Modifier.fillMaxWidth().background(Chotki.panel)) {
            val lit = journey.current.place
            for (candidate in Place.entries) {
                val colour = if (candidate == lit) Chotki.gold else Chotki.muted
                Column(
                    Modifier
                        .weight(1f)
                        .clickable { journey = journey.go(candidate) }
                        .padding(vertical = 8.dp)
                        .semantics { contentDescription = "Go to ${candidate.title}" },
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    PlaceIcon(candidate, colour)
                    Text(
                        candidate.title,
                        color = colour,
                        fontSize = 10.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
            }
        }
    }
}
