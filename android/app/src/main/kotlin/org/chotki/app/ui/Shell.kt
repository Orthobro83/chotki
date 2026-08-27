package org.chotki.app.ui

import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
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

/**
 * The bar across the top: where you are, and the one thing you can do from here.
 *
 * Slim on purpose. A phone has little enough height, and this exists to carry a
 * single control — the library, or on the Reading the glossary — not to be a
 * header.
 */
@Composable
private fun TopBar(screen: Screen, onLibrary: () -> Unit, onGlossary: () -> Unit) {
    val readingHere = screen.place == Place.READING
    Row(
        Modifier.fillMaxWidth().padding(start = 16.dp, end = 6.dp, top = 6.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            if (screen == Screen.Day) "Chotki" else screen.place.title,
            color = Chotki.parchment,
            fontSize = 17.sp,
            modifier = Modifier.weight(1f),
        )
        Column(
            Modifier
                .clickable(onClick = if (readingHere) onGlossary else onLibrary)
                .padding(10.dp)
                .semantics {
                    contentDescription =
                        if (readingHere) "Open the glossary" else "Open the library"
                },
        ) {
            if (readingHere) {
                GlossaryIcon(Chotki.gold, 24.dp)
            } else {
                LibraryIcon(Chotki.gold, 24.dp)
            }
        }
    }
}

/** The way back out of a screen that was pushed rather than chosen. */
@Composable
private fun BackLink(onBack: () -> Unit) {
    Text(
        "‹ The day",
        color = Chotki.gold,
        fontSize = 15.sp,
        modifier = Modifier
            .clickable(onClick = onBack)
            .padding(16.dp)
            .semantics { contentDescription = "Back to the day" },
    )
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

    // Honoured, not assumed.
    //
    // "Remove animations" in accessibility, and the developer animation scale,
    // both land here as a scale of zero — and people turn it off precisely on
    // the older, slower phones this has to keep working on. Compose does not
    // consult it for `AnimatedContent`, so the app has to.
    val animates = remember {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) > 0f
    }

    val readiness = remember(journey) { ReminderReadiness.of(context) }
    val dismissals = remember { BannerDismissals(context) }
    var dismissed by remember(readiness) { mutableStateOf(dismissals.isDismissed(readiness)) }

    // Back goes back one screen, and only leaves the app from the day itself.
    // Without this it fell through to Android's default at every depth: three
    // fields into the editor, back closed Chotki.
    BackHandler(enabled = journey.canGoBack) { journey = journey.back() }

    // First run, before anything else. Nothing on it can be reached until it is
    // read, which is the point of it.
    if (!state.settings.hasCompletedFirstRun) {
        WelcomeScreen(state, Modifier.fillMaxSize())
        return
    }

    // The status bar is the app's to clear now. The bottom bar clears the
    // navigation bar itself, further down, so its background still runs to the
    // bottom of the screen while its labels sit above the gesture pill.
    Column(Modifier.fillMaxSize().background(Chotki.ground).statusBarsPadding()) {
        if (!dismissed) {
            ReadinessBanner(readiness) {
                dismissals.dismiss(readiness)
                dismissed = true
            }
        }

        // Always in the corner, wherever you are — except on the Reading,
        // where the glossary takes its place. The library used to be a word at
        // the foot of the day and nowhere else, so it was invisible from every
        // other screen and easy to miss on the one that had it.
        TopBar(
            screen = journey.current,
            onLibrary = { journey = journey.push(Screen.Library) },
            onGlossary = { journey = journey.push(Screen.Terms()) },
        )

        Box(Modifier.weight(1f)) {
            AnimatedContent(
                targetState = journey,
                transitionSpec = {
                    // Going deeper slides in from the right; coming back slides
                    // in from the left. The stack depth says which, so nothing
                    // has to be remembered about how we got here.
                    val deeper = targetState.stack.size >= initialState.stack.size
                    val from = if (deeper) 1 else -1

                    if (!animates) {
                        EnterTransition.None togetherWith ExitTransition.None
                    } else {
                        // A sixth of the width, not the whole width. A full
                        // slide reads as a page turn and is slow on a cheap
                        // phone; a short one reads as continuity and costs
                        // almost nothing to draw.
                        (
                            slideInHorizontally(tween(220)) { it / 6 * from } +
                                fadeIn(tween(180))
                            ) togetherWith fadeOut(tween(120))
                    }.using(SizeTransform(clip = false))
                },
                label = "screen",
            ) { destination ->
                Column(Modifier.fillMaxSize()) {
                    when (val screen = destination.current) {
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
                            BackLink { journey = journey.back() }
                            PsalterScreen(state, Modifier.weight(1f))
                        }

                        Screen.Library -> {
                            BackLink { journey = journey.back() }
                            LibrarySheet(
                                state = state,
                                modifier = Modifier.weight(1f),
                                onWriteYourOwn = { journey = journey.push(Screen.Editor(null)) },
                                onTakeOn = {
                                    journey = journey.push(Screen.Editor(null, startingFrom = it))
                                },
                            )
                        }

                        Screen.Day -> RuleScreen(
                            state = state,
                            modifier = Modifier.weight(1f),
                            onReadPrayers = { journey = journey.push(Screen.RulePrayers(it.rule.id)) },
                            // The day's readings already have a place of their own.
                            onReadReading = { journey = journey.go(Place.READING) },
                            onReadPsalter = { journey = journey.push(Screen.Psalter) },
                            onEdit = { journey = journey.push(Screen.Editor(it.rule)) },
                            onOpenLibrary = { journey = journey.push(Screen.Library) },
                        )

                        Screen.Rope -> RopeScreen(
                            state = state,
                            modifier = Modifier.weight(1f),
                            glossary = glossary,
                            onOpenTerm = { journey = journey.push(Screen.Terms(it)) },
                        )

                        Screen.Reading -> ReadingScreen(
                            state = state,
                            modifier = Modifier.weight(1f),
                            glossary = glossary,
                            onOpenTerm = { journey = journey.push(Screen.Terms(it)) },
                        )

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
            }
        }

        Row(
            Modifier
                .fillMaxWidth()
                .background(Chotki.panel)
                .navigationBarsPadding(),
        ) {
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
