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
import androidx.compose.foundation.lazy.LazyListScope
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
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.Akathist
import org.chotki.core.LiturgicalDay
import org.chotki.core.Reading
import org.chotki.core.ReadingOrder
import org.chotki.core.Reckoning
import org.chotki.core.content.Content
import org.chotki.core.content.Glossary
import org.chotki.core.content.PatristicReadings
import org.chotki.core.content.SaintLifeJson
import org.chotki.core.content.SaintLifeSpanJson
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
    val scripture = chunks.map { (band, readings) -> band to readings.size }
    val saintLife = Content.saintLife(day.observedDate.month, day.observedDate.day)
    val showDeparted = state.settings.jurisdiction.tradition.isSlavic ||
        ReadingOrder.DEPARTED_BAND in held
    val akathistWeek = Akathist.week(day.paschaDistance, state.settings.jurisdiction.tradition)
    val trailing = buildList {
        add(ReadingOrder.SAINT_LIFE_BAND)
        if (showDeparted) add(ReadingOrder.DEPARTED_BAND)
        if (akathistWeek != null) add(ReadingOrder.AKATHIST_BAND)
    }
    // A rule opens its own section. The tab itself opens with every section
    // closed, because the four readings together are a book, not a page.
    var expanded by remember(day.observedDate) { mutableStateOf(emptySet<Int>()) }
    val present = chunks.keys + trailing.toSet()
    val availableBands = chunks.keys + buildSet {
        if (saintLife != null) add(ReadingOrder.SAINT_LIFE_BAND)
        if (showDeparted) add(ReadingOrder.DEPARTED_BAND)
        if (akathistWeek != null) add(ReadingOrder.AKATHIST_BAND)
    }
    val list = rememberLazyListState()
    var scrolled by remember { mutableStateOf(false) }
    var following by remember { mutableStateOf(false) }
    val marked = remember { mutableStateListOf<Int>() }
    LaunchedEffect(focusNonce, focusBand, day.observedDate) {
        val open = if (focusBand != null && focusBand in present) setOf(focusBand) else emptySet()
        expanded = open
        val band = focusBand ?: return@LaunchedEffect
        val index = ReadingOrder.headerIndex(band, scripture, open, trailing)
        if (index < 0) return@LaunchedEffect
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
            item(key = "head-$band") {
                SectionHeader(ReadingOrder.sectionTitle(band, readings.map { it.source }), band in expanded) {
                    expanded = if (band in expanded) expanded - band else expanded + band
                }
            }
            if (band in expanded) {
                items(readings.size, key = { "${band}-${readings[it].display}-${readings[it].source}" }) { index ->
                    ReadingBlock(readings[index])
                }
                item(key = "end-$band") { Spacer(Modifier.size(1.dp)) }
            }
        }
        item(key = "saint-life") {
            SectionHeader(
                ReadingOrder.sectionTitle(ReadingOrder.SAINT_LIFE_BAND),
                ReadingOrder.SAINT_LIFE_BAND in expanded,
            ) {
                expanded = if (ReadingOrder.SAINT_LIFE_BAND in expanded) {
                    expanded - ReadingOrder.SAINT_LIFE_BAND
                } else {
                    expanded + ReadingOrder.SAINT_LIFE_BAND
                }
            }
        }
        if (ReadingOrder.SAINT_LIFE_BAND in expanded) {
            item(key = "saint-life-body") { SaintLifeBody(day, saintLife) }
            item(key = "end-${ReadingOrder.SAINT_LIFE_BAND}") { Spacer(Modifier.size(1.dp)) }
        }
        if (showDeparted) {
            val departed = Content.appointed.departed
            appointedSection(
                ReadingOrder.DEPARTED_BAND,
                expanded,
                { expanded = it },
                departed.rubric,
                departed.paragraphs,
                departed.source,
                departed.sourceURL,
            )
        }
        if (akathistWeek != null) {
            val hymn = Content.appointed.akathist
            appointedSection(
                ReadingOrder.AKATHIST_BAND,
                expanded,
                { expanded = it },
                Akathist.heading(akathistWeek),
                Akathist.paragraphs(akathistWeek),
                hymn.source,
                hymn.sourceURL,
                note = Akathist.fallbackNote(state.settings.jurisdiction.tradition),
                linkTerms = true,
                glossary = glossary,
                onOpenTerm = onOpenTerm,
            )
        }
        item { Fathers(state, day) }
        item { Spacer(Modifier.size(32.dp)) }
    }
}

@Composable
private fun SectionHeader(title: String, expanded: Boolean, toggle: () -> Unit) {
    Rule()
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = toggle)
            .padding(vertical = 14.dp)
            .semantics { contentDescription = if (expanded) "Collapse $title" else "Expand $title" },
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = Chotki.gold, fontFamily = Chotki.reading, fontSize = 19.sp, modifier = Modifier.weight(1f))
        Text(if (expanded) "⌃" else "⌄", color = Chotki.gold, fontSize = 19.sp)
    }
}

private fun LazyListScope.appointedSection(
    band: Int,
    expanded: Set<Int>,
    onExpanded: (Set<Int>) -> Unit,
    heading: String,
    paragraphs: List<String>,
    source: String,
    sourceURL: String,
    note: String? = null,
    linkTerms: Boolean = false,
    glossary: Glossary? = null,
    onOpenTerm: (String) -> Unit = {},
) {
    val title = ReadingOrder.sectionTitle(band)
    item(key = "head-$band") {
        SectionHeader(title, band in expanded) {
            onExpanded(if (band in expanded) expanded - band else expanded + band)
        }
    }
    if (band in expanded) {
        item(key = "body-$band") {
            AppointedBody(heading, paragraphs, source, sourceURL, note, linkTerms, glossary, onOpenTerm)
        }
        item(key = "end-$band") { Spacer(Modifier.size(1.dp)) }
    }
}

@Composable
private fun AppointedBody(
    heading: String,
    paragraphs: List<String>,
    source: String,
    sourceURL: String,
    note: String? = null,
    linkTerms: Boolean = false,
    glossary: Glossary? = null,
    onOpenTerm: (String) -> Unit = {},
) {
    val links = LocalUriHandler.current
    val linked = if (linkTerms && glossary != null) glossary.scanOnce(paragraphs) else null
    Column(Modifier.padding(bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(heading, color = Chotki.muted, fontSize = 13.sp)
        if (note != null && glossary != null) {
            TermText(note, glossary, colour = Chotki.muted, size = 13.sp, onOpenTerm = onOpenTerm)
        } else if (note != null) {
            Text(note, color = Chotki.muted, fontSize = 13.sp)
        }
        paragraphs.forEachIndexed { index, paragraph ->
            if (linked != null && glossary != null) {
                TermText(
                    paragraph,
                    glossary,
                    colour = Chotki.parchment,
                    size = 17.sp,
                    matches = linked[index],
                    onOpenTerm = onOpenTerm,
                )
            } else {
                Text(
                    paragraph,
                    color = Chotki.parchment,
                    fontFamily = Chotki.reading,
                    fontSize = 17.sp,
                    lineHeight = 17.sp * 1.45f,
                )
            }
        }
        Text(
            source,
            color = Chotki.faint,
            fontSize = 12.sp,
            modifier = Modifier.clickable { links.openUri(sourceURL) },
        )
    }
}

@Composable
private fun SaintLifeBody(day: LiturgicalDay, life: SaintLifeJson?) {
    Column(Modifier.padding(bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (life == null) {
            if (day.saints.isNotEmpty()) {
                Text(day.saints.joinToString(" · "), color = Chotki.muted, fontSize = 13.sp)
            }
            Text("No life is stored for this day.", color = Chotki.faint, fontSize = 13.sp)
            return
        }
        // The page's own date line. It names the old-calendar day and the
        // new-calendar day, and it is not reworded.
        Text(life.dates, color = Chotki.gold, fontFamily = Chotki.reading, fontSize = 18.sp)
        life.preface?.let {
            Text(it, color = Chotki.parchment, fontFamily = Chotki.reading, fontSize = 17.sp)
        }
        for (section in life.sections) {
            Text(section.heading, color = Chotki.parchment, fontFamily = Chotki.reading, fontSize = 17.sp)
            for (block in section.blocks) {
                when (block.kind) {
                    "heading" -> Text(
                        block.text.orEmpty(),
                        color = Chotki.parchment,
                        fontFamily = Chotki.reading,
                        fontSize = 16.sp,
                    )
                    "lines" -> Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        for (row in block.rows.orEmpty()) {
                            SpanText(row)
                        }
                    }
                    else -> SpanText(block.spans.orEmpty())
                }
            }
        }
        Citation(life)
    }
}

@Composable
private fun SpanText(spans: List<SaintLifeSpanJson>) {
    Text(
        buildAnnotatedString {
            for (span in spans) {
                withStyle(
                    SpanStyle(
                        fontStyle = if (span.italic) FontStyle.Italic else FontStyle.Normal,
                        fontWeight = if (span.bold) FontWeight.Medium else FontWeight.Normal,
                    ),
                ) { append(span.text) }
            }
        },
        color = Chotki.parchment,
        fontFamily = Chotki.reading,
        fontSize = 17.sp,
        lineHeight = 17.sp * 1.45f,
    )
}

@Composable
private fun Citation(life: SaintLifeJson) {
    val links = LocalUriHandler.current
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            life.source,
            color = Chotki.faint,
            fontSize = 12.sp,
            modifier = Modifier.clickable { links.openUri(life.sourceURL) },
        )
        Text(life.licenseNote, color = Chotki.faint, fontSize = 12.sp)
        Text(
            life.license,
            color = Chotki.faint,
            fontSize = 12.sp,
            modifier = Modifier.clickable { links.openUri(life.licenseURL) },
        )
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
