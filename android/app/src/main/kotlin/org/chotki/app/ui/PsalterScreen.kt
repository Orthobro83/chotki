package org.chotki.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.RuleReference
import org.chotki.core.content.Kathisma
import org.chotki.core.content.Psalter
import org.chotki.core.reference

/**
 * The kathismata appointed for the day, and the psalms in them.
 *
 * The Typikon appoints the Psalter across the services of the day rather than
 * as one daily portion, so that is what this shows: what is read, and where in
 * the day it is read. Someone keeping a kathisma a day takes the first of them;
 * the rest is there because it is what the day actually has.
 */
@Composable
fun PsalterScreen(state: AppState, modifier: Modifier = Modifier) {
    val day = state.liturgicalDay(state.selectedDate)
    val season = day?.let { Kathisma.season(it.paschaDistance) } ?: Kathisma.Season.ORDINARY
    val appointed = Kathisma.appointed(state.selectedDate.weekday, season)
    var open by remember { mutableStateOf<Int?>(null) }
    val list = rememberLazyListState()
    PsalterEnd(list, open, state)

    LazyColumn(modifier.fillMaxSize(), state = list) {
        if (appointed.isEmpty()) {
            item {
                Column(Modifier.fillMaxWidth().padding(24.dp)) {
                    Text(
                        "No kathisma is appointed today.",
                        color = Chotki.muted,
                        fontSize = 15.sp,
                        modifier = Modifier.semantics { contentDescription = "The Psalter" },
                    )
                    Text(
                        if (season == Kathisma.Season.BRIGHT_WEEK) {
                            "The Psalter is not read through Bright Week."
                        } else {
                            "Nothing is appointed for this day."
                        },
                        color = Chotki.faint,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
            }
        }

        for (entry in appointed) {
            item(key = "service-${entry.service.name}") {
                Text(
                    entry.service.displayName,
                    color = Chotki.gold,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 2.dp),
                )
            }
            for (number in entry.kathismata) {
                item(key = "kathisma-${entry.service.name}-$number") {
                    KathismaHeader(number, open == number) {
                        open = if (open == number) null else number
                    }
                }
                if (open == number) {
                    item(key = "body-$number") { KathismaPsalms(number) }
                    // After the last verse, not after the list of names.
                    item(key = "psalter-end") { Spacer(Modifier.size(1.dp)) }
                }
            }
        }

        item(key = "source") {
            Text(
                Psalter.source,
                color = Chotki.faint,
                fontSize = 11.sp,
                modifier = Modifier.padding(16.dp),
            )
        }
    }
}

/**
 * The open kathisma, scrolled to its last line.
 *
 * Expanding it is not reading it, and neither is moving the list of names.
 * The scroll has to happen after it is open, and the marker has to be the
 * thing that comes into view.
 */
@Composable
private fun PsalterEnd(list: LazyListState, open: Int?, state: AppState) {
    val day = state.selectedDate
    var scrolled by remember(open, day) { mutableStateOf(false) }
    var marked by remember(open, day) { mutableStateOf(false) }
    LaunchedEffect(list, open, day) {
        snapshotFlow { list.isScrollInProgress }.collect { moving ->
            if (moving) scrolled = true
        }
    }
    LaunchedEffect(list, scrolled, open, day) {
        if (open == null || !scrolled || marked) return@LaunchedEffect
        snapshotFlow { list.layoutInfo.visibleItemsInfo.any { it.key == "psalter-end" } }
            .collect { visible ->
                if (!visible || marked) return@collect
                marked = true
                state.entries(state.selectedDate)
                    .filter { it.rule.reference == RuleReference.PSALTER }
                    .forEach(state::markKept)
            }
    }
}

@Composable
private fun KathismaHeader(number: Int, isOpen: Boolean, onTap: () -> Unit) {
    val range = Kathisma.psalms(number)
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .semantics { contentDescription = "Kathisma $number" },
    ) {
        Text("Kathisma $number", color = Chotki.parchment, fontSize = 15.sp)
        if (range != null) {
            Text(
                if (range.first == range.last) "  Psalm ${range.first}"
                else "  Psalms ${range.first}–${range.last}",
                color = Chotki.muted,
                fontSize = 13.sp,
                modifier = Modifier.weight(1f),
            )
        }
        Text(if (isOpen) "⌃" else "⌄", color = Chotki.goldDim, fontSize = 14.sp)
    }
}

@Composable
private fun KathismaPsalms(number: Int) {
    Column(Modifier.fillMaxWidth()) {
        for (psalm in Psalter.kathisma(number)) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)) {
                Text("Psalm ${psalm.number}", color = Chotki.goldDim, fontSize = 12.sp)
                psalm.superscription?.let {
                    Text(
                        it,
                        color = Chotki.muted,
                        fontSize = 13.sp,
                        fontStyle = FontStyle.Italic,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }
                for (verse in psalm.verses) {
                    Text(
                        "${verse.number}  ${verse.text}",
                        color = Chotki.parchment,
                        fontSize = 14.sp,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}
