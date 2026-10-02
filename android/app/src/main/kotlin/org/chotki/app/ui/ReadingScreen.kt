package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.text.font.FontFamily
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
import org.chotki.core.content.Content
import org.chotki.core.content.SaintLifeJson
import kotlinx.coroutines.flow.first

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
    /** The section a reading rule asked for. Null when the tab itself was opened. */
    focusBand: Int? = null,
    /** Bumps when a rule asks again, so the same section can be requested twice. */
    focusNonce: Int = 0,
    onOpenGlossary: () -> Unit = {},
) {
    // liturgicalDay reads the calendar counter itself, so this redraws when
    // the fortnight ahead arrives.
    val day = state.liturgicalDay(state.selectedDate)
    Column(modifier.fillMaxSize()) {
        if (day == null) {
            // Nothing here scrolls, so a top fade would only let the wash
            // through the message.
            Waiting(
                state,
                Modifier.weight(1f).edgeFade(topBand = 0f).padding(horizontal = 16.dp, vertical = 12.dp),
            )
        } else {
            Readings(
                state,
                day,
                glossary,
                onOpenTerm,
                focusBand,
                focusNonce,
                Modifier.weight(1f),
            )
        }
        GlossaryOfTerms(onOpenGlossary)
    }
}

@Composable
private fun Readings(
    state: AppState,
    day: LiturgicalDay,
    glossary: Glossary,
    onOpenTerm: (String) -> Unit,
    focusBand: Int?,
    focusNonce: Int,
    modifier: Modifier,
) {
    val held = state.entries(state.selectedDate)
        .mapNotNull { ReadingOrder.bandOfTitle(it.rule.title) }
        .toSet()
    val ordered = ReadingOrder.sorted(day.readings, { it.source }) { ReadingOrder.band(it.source) in held }
    val chunks = ordered.groupBy { ReadingOrder.band(it.source) }
    val saintLife = Content.saintLives.firstOrNull {
        it.month == day.observedDate.month && it.day == day.observedDate.day
    }
    var saintExpanded by remember(day.observedDate) { mutableStateOf(true) }
    LaunchedEffect(focusNonce, focusBand) {
        if (focusBand == ReadingOrder.SAINT_LIFE_BAND) saintExpanded = true
    }
    val availableBands = chunks.keys + if (saintLife != null) setOf(ReadingOrder.SAINT_LIFE_BAND) else emptySet()
    val list = rememberLazyListState()
    var scrolled by remember { mutableStateOf(false) }
    var following by remember { mutableStateOf(false) }
    val marked = remember { mutableStateListOf<Int>() }
    LaunchedEffect(focusNonce, focusBand, availableBands.toList()) {
        val band = focusBand ?: return@LaunchedEffect
        if (band !in availableBands) return@LaunchedEffect
        var index = 1
        for ((key, readings) in chunks) {
            if (key == band) break
            index += readings.size + 1
        }
        // The list reports its length after the first layout. Scrolling
        // before that is a no-op, and the section is never reached.
        snapshotFlow { list.layoutInfo.totalItemsCount }.first { it > index }
        following = true
        try {
            list.animateScrollToItem(index)
        } finally {
            following = false
        }
    }
    // A jump to a section is not the reader reaching the end of it.
    LaunchedEffect(list) {
        snapshotFlow { list.isScrollInProgress to following }.collect { (moving, auto) ->
            if (moving && !auto) scrolled = true
        }
    }
    LaunchedEffect(list, scrolled) {
        snapshotFlow { list.layoutInfo.visibleItemsInfo.map { it.key } }
            .collect { keys ->
                if (!scrolled) return@collect
                for (band in availableBands) {
                    if ("end-$band" in keys && band !in marked) {
                        marked.add(band)
                        state.entries(state.selectedDate)
                            .filter { ReadingOrder.bandOfTitle(it.rule.title) == band }
                            .forEach(state::markKept)
                    }
                }
            }
    }

    val top = list.scrolledTopBand()
    LazyColumn(
        modifier.fillMaxWidth().edgeFade(topBand = top).padding(horizontal = 16.dp),
        state = list,
    ) {
        item { Heading(state, day, glossary, onOpenTerm) }
        for ((band, readings) in chunks) {
            items(readings.size, key = { "${band}-${readings[it].display}-${readings[it].source}" }) { index ->
                ReadingBlock(readings[index])
            }
            item(key = "end-$band") { Spacer(Modifier.size(1.dp)) }
        }
        item(key = "saint-life") { SaintLifeBlock(day, saintLife, saintExpanded) { saintExpanded = !saintExpanded } }
        if (saintLife != null && saintExpanded) {
            item(key = "end-${ReadingOrder.SAINT_LIFE_BAND}") { Spacer(Modifier.size(1.dp)) }
        }
        item { Fathers(state, day) }
        item { Spacer(Modifier.size(32.dp)) }
    }
}

@Composable
private fun SaintLifeBlock(day: LiturgicalDay, life: SaintLifeJson?, expanded: Boolean, toggle: () -> Unit) {
    Rule()
    Column(Modifier.padding(vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth().clickable(onClick = toggle), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Life of the Day’s Saint", color = Chotki.gold, fontFamily = Chotki.reading, fontSize = 19.sp)
            Text(if (expanded) "⌃" else "⌄", color = Chotki.gold, fontSize = 19.sp)
        }
        if (expanded && life == null) {
            if (day.saints.isNotEmpty()) {
                Text(day.saints.joinToString(" · "), color = Chotki.muted, fontSize = 13.sp)
            }
            Text("A public-domain English life is not yet available for this day.",
                color = Chotki.faint, fontSize = 13.sp)
        } else if (expanded && life != null) {
            Text(life.title, color = Chotki.parchment, fontFamily = Chotki.reading, fontSize = 18.sp)
            life.paragraphs.forEach { paragraph ->
                Text(paragraph, color = Chotki.parchment, fontFamily = Chotki.reading,
                    fontSize = 17.sp, lineHeight = 17.sp * 1.45f)
            }
            Text(life.source, color = Chotki.faint, fontSize = 12.sp)
        }
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
        Text(
            "${reading.source} · ${reading.display}",
            color = Chotki.muted,
            fontFamily = Chotki.reading,
            fontSize = 13.sp,
        )
        if (reading.text.isNotEmpty()) {
            Spacer(Modifier.size(4.dp))
            Text(
                reading.text,
                color = Chotki.parchment,
                fontFamily = Chotki.reading,
                fontSize = 17.sp,
                lineHeight = 17.sp * 1.45f,
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
                fontFamily = Chotki.reading,
                fontSize = 13.sp,
                modifier = Modifier.semantics { contentDescription = "The reading" },
            )
            Spacer(Modifier.size(6.dp))
            Text(
                patristic.text,
                color = Chotki.parchment,
                fontFamily = Chotki.reading,
                fontSize = 17.sp,
                lineHeight = 17.sp * 1.45f,
            )
            Spacer(Modifier.size(6.dp))
            Text(
                "${patristic.author} · ${patristic.source}",
                color = Chotki.faint,
                fontFamily = FontFamily.SansSerif,
                fontSize = 13.sp,
            )
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
            fontFamily = Chotki.reading,
            fontSize = 13.sp,
        )
        Text(
            when {
                state.isOffline -> "cached"
                state.settings.jurisdiction.reckoning == Reckoning.JULIAN -> "old calendar"
                else -> "new calendar"
            },
            color = Chotki.faint,
            fontFamily = Chotki.reading,
            fontSize = 13.sp,
        )
    }
}

@Composable
private fun Waiting(state: AppState, modifier: Modifier = Modifier) {
    // "It will fill in shortly" is a promise, and the app should not make it
    // when it has never reached the calendar at all.
    val neverFetched = state.hasNoCalendarAtAll
    Column(
        modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "No reading stored for this day yet.",
            color = Chotki.muted,
            fontFamily = Chotki.reading,
            fontSize = 17.sp,
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
            fontFamily = FontFamily.SansSerif,
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
