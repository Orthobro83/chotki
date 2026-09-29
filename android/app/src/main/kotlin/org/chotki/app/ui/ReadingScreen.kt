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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.LiturgicalDay
import org.chotki.core.Reading
import org.chotki.core.ReadingOrder
import org.chotki.core.Reckoning
import org.chotki.core.content.Glossary
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
fun ReadingScreen(
    state: AppState,
    modifier: Modifier = Modifier,
    glossary: Glossary = Glossary.SHARED,
    onOpenTerm: (String) -> Unit = {},
) {
    // liturgicalDay reads the calendar counter itself, so this redraws when
    // the fortnight ahead arrives.
    val day = state.liturgicalDay(state.selectedDate)
    if (day == null) {
        Column(
            modifier.fillMaxSize().background(Chotki.ground).padding(horizontal = 16.dp, vertical = 12.dp),
        ) { Waiting(state) }
        return
    }
    Readings(state, day, glossary, onOpenTerm, modifier)
}

@Composable
private fun Readings(
    state: AppState,
    day: LiturgicalDay,
    glossary: Glossary,
    onOpenTerm: (String) -> Unit,
    modifier: Modifier,
) {
    val held = state.entries(state.selectedDate)
        .mapNotNull { ReadingOrder.bandOfTitle(it.rule.title) }
        .toSet()
    val ordered = ReadingOrder.sorted(day.readings, { it.source }) { ReadingOrder.band(it.source) in held }
    val chunks = ordered.groupBy { ReadingOrder.band(it.source) }
    val list = rememberLazyListState()
    var scrolled by remember { mutableStateOf(false) }
    val marked = remember { mutableStateListOf<Int>() }
    LaunchedEffect(list) {
        snapshotFlow { list.firstVisibleItemIndex to list.firstVisibleItemScrollOffset }
            .collect { (index, offset) -> if (index > 0 || offset > 8) scrolled = true }
    }
    LaunchedEffect(list, scrolled) {
        snapshotFlow { list.layoutInfo.visibleItemsInfo.map { it.key } }
            .collect { keys ->
                if (!scrolled) return@collect
                for (band in chunks.keys) {
                    if ("end-$band" in keys && band !in marked) {
                        marked.add(band)
                        state.entries(state.selectedDate)
                            .filter { ReadingOrder.bandOfTitle(it.rule.title) == band }
                            .forEach(state::markKept)
                    }
                }
            }
    }

    LazyColumn(
        modifier.fillMaxSize().background(Chotki.ground).padding(horizontal = 16.dp),
        state = list,
    ) {
        item { Heading(state, day, glossary, onOpenTerm) }
        for ((band, readings) in chunks) {
            items(readings.size, key = { "${band}-${readings[it].display}-${readings[it].source}" }) { index ->
                ReadingBlock(readings[index])
            }
            item(key = "end-$band") { Spacer(Modifier.size(1.dp)) }
        }
        item { Fathers(state, day) }
        item { Spacer(Modifier.size(32.dp)) }
    }
}

@Composable
private fun Heading(
    state: AppState,
    day: LiturgicalDay,
    glossary: Glossary,
    onOpenTerm: (String) -> Unit,
) {
    val title = day.title
    if (title != null) {
        // Never re-cased, and centered. The Church's own line, not a label we restyle.
        TermText(
            text = title,
            glossary = glossary,
            colour = Chotki.muted,
            size = 13.sp,
            textAlign = TextAlign.Center,
            onOpenTerm = onOpenTerm,
            modifier = Modifier.padding(top = 8.dp),
        )
    }
    TermText(
        text = day.summaryTitle,
        glossary = glossary,
        colour = Chotki.gold,
        size = 19.sp,
        textAlign = TextAlign.Center,
        onOpenTerm = onOpenTerm,
        modifier = Modifier
            .padding(top = 6.dp, bottom = 10.dp)
            .semantics { contentDescription = "The day in the church calendar" },
    )
}

@Composable
private fun ReadingBlock(reading: Reading) {
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
}

@Composable
private fun Fathers(state: AppState, day: LiturgicalDay) {
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
        Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 12.dp),
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
