package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.LiturgicalDay
import org.chotki.core.Reckoning
import org.chotki.core.content.PatristicReadings

/**
 * The day as the Church has it: what is commemorated, what the calendar marks,
 * the appointed readings, and a passage from the fathers.
 *
 * Reported, never prescribed. It says what the calendar marks and what is
 * customarily set aside; it does not tell anyone what to eat or what to do. That
 * distinction is the whole reason the wording is careful here.
 */
@Composable
fun ReadingScreen(state: AppState, modifier: Modifier = Modifier) {
    // liturgicalDay reads the calendar counter itself, so this redraws when
    // the fortnight ahead arrives.
    val day = state.liturgicalDay(state.selectedDate)

    Column(
        modifier
            .fillMaxSize()
            .background(Chotki.ground)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        if (day == null) Waiting(state) else Content(state, day)
    }
}

@Composable
private fun Content(state: AppState, day: LiturgicalDay) {
    val title = day.title
    if (title != null) {
        // Never re-cased. "Wednesday of the 12th week after Pentecost" is how the
        // Church writes it, and lowercasing it made the app look careless.
        Text(title, color = Chotki.muted, fontSize = 13.sp)
    }
    Text(
        day.summaryTitle,
        color = Chotki.gold,
        fontSize = 19.sp,
        lineHeight = 26.sp,
        modifier = Modifier
            .padding(top = 6.dp, bottom = 10.dp)
            .semantics { contentDescription = "The day in the church calendar" },
    )

    if (state.settings.observances.fasting.isVisible && day.isFast) {
        // What the calendar marks, and what is customarily set aside — not an
        // instruction to the reader.
        Text(
            "The calendar marks this as ${day.fastDescription}.",
            color = Chotki.violet,
            fontSize = 13.sp,
        )
        if (day.abstentions.isNotEmpty()) {
            Text(
                "Customarily set aside: ${day.abstentions.joinToString(", ")}.",
                color = Chotki.faint,
                fontSize = 13.sp,
            )
        }
        Spacer(Modifier.size(10.dp))
    }

    Rule()

    for ((index, reading) in day.readings.withIndex()) {
        Column(Modifier.padding(vertical = 10.dp)) {
            Text("${reading.source} · ${reading.display}", color = Chotki.muted, fontSize = 13.sp)
            if (reading.text.isNotEmpty()) {
                Spacer(Modifier.size(4.dp))
                Text(
                    reading.text,
                    color = Chotki.parchmentDim,
                    fontSize = 15.sp,
                    lineHeight = 23.sp,
                )
            }
        }
        if (index < day.readings.size - 1) Rule(soft = true)
    }

    PatristicReadings.forDay(state.selectedDate)?.let { patristic ->
        Rule()
        Column(Modifier.padding(vertical = 10.dp)) {
            Text(
                "From the fathers",
                color = Chotki.muted,
                fontSize = 13.sp,
                modifier = Modifier.semantics { contentDescription = "The reading" },
            )
            Spacer(Modifier.size(6.dp))
            Text(patristic.text, color = Chotki.parchmentDim, fontSize = 16.sp, lineHeight = 25.sp)
            Spacer(Modifier.size(6.dp))
            Text("${patristic.author} · ${patristic.source}", color = Chotki.faint, fontSize = 13.sp)
        }
    }

    Rule()
    Row(
        Modifier.fillMaxWidth().padding(top = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            buildString {
                append("${day.paschaDistance} days since Pascha")
                day.tone?.let { append(" · tone $it") }
            },
            color = Chotki.faint,
            fontSize = 13.sp,
        )
        // "cached" rather than an error: a failed refresh is a state the app
        // reflects, not something to show where text should be.
        Text(
            when {
                state.isOffline -> "cached"
                state.settings.jurisdiction.reckoning == Reckoning.JULIAN -> "old calendar"
                else -> "new calendar"
            },
            color = Chotki.faint,
            fontSize = 13.sp,
        )
    }
    Spacer(Modifier.size(32.dp))
}

@Composable
private fun Waiting(state: AppState) {
    // "It will fill in shortly" is a promise, and the app should not make it
    // when it has never reached the calendar at all.
    val neverFetched = state.hasNoCalendarAtAll
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "No reading stored for this day yet.",
            color = Chotki.muted,
            fontSize = 15.sp,
            modifier = Modifier.semantics { contentDescription = "The reading" },
        )
        Spacer(Modifier.size(6.dp))
        Text(
            if (neverFetched) {
                "The church calendar has not been fetched yet. It is the only thing " +
                    "Chotki asks the network for, and it will fill in when it can reach it."
            } else {
                "Readings are fetched a fortnight ahead and kept, so this fills in shortly."
            },
            color = Chotki.faint,
            fontSize = 13.sp,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun Rule(soft: Boolean = false) {
    Box(
        Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(if (soft) Chotki.lineSoft else Chotki.line),
    )
}
