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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.CalendarDate
import org.chotki.core.ClockStyle
import org.chotki.core.DayEntry
import org.chotki.core.Format
import org.chotki.core.RuleReference
import org.chotki.core.reference

/**
 * The day, and what is on the rule for it.
 *
 * The one thing carried over from the macOS app deliberately: **only the box
 * marks a rule kept.** Making the whole row the target there fixed an
 * unclickable checkbox and broke everything sitting beside it — the prayers
 * link and the edit control both ticked the rule off. The answer to a small
 * target is padding around it.
 */
@Composable
fun RuleScreen(
    state: AppState,
    modifier: Modifier = Modifier,
    onReadPrayers: (DayEntry) -> Unit = {},
    onReadReading: () -> Unit = {},
    onReadPsalter: () -> Unit = {},
    onEdit: (DayEntry) -> Unit = {},
) {
    val entries = state.entries(state.selectedDate)
    val list = rememberLazyListState()

    // Folded as soon as the rules are moved at all, and unfolded only back at
    // the very top. A threshold in the middle would flap: folding gives the
    // list more room, which moves it, which would unfold it again.
    val collapsed by remember {
        derivedStateOf {
            list.firstVisibleItemIndex > 0 || list.firstVisibleItemScrollOffset > 0
        }
    }

    BoxWithConstraints(modifier.fillMaxSize().background(Chotki.ground)) {
        // Half, and no more. The calendar used to take whatever it wanted and
        // the rules it sits above were pushed off the bottom of the screen,
        // where nothing could reach them because this column does not scroll.
        val cap = this@BoxWithConstraints.maxHeight / 2

        Column(Modifier.fillMaxSize()) {
            Calendar(state, collapsed = collapsed, maxHeight = cap)
            DayHeader(state.selectedDate)

            if (entries.isEmpty()) {
                EmptyDay()
            } else {
                // The weight is the fix. Without it this takes whatever height
                // is left over, which can be none, and a list of zero height
                // scrolls nowhere.
                LazyColumn(Modifier.fillMaxWidth().weight(1f), state = list) {
                    items(entries, key = { it.id }) { entry ->
                        EntryRow(
                            entry = entry,
                            clock = state.settings.clockStyle,
                            onToggle = { state.toggleKept(entry) },
                            onReadPrayers = { onReadPrayers(entry) },
                            onReadReading = onReadReading,
                            onReadPsalter = onReadPsalter,
                            onEdit = { onEdit(entry) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DayHeader(date: CalendarDate) {
    Text(
        text = longDate(date),
        color = Chotki.parchment,
        fontSize = 17.sp,
        modifier = Modifier
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .semantics { contentDescription = "The day" },
    )
}

@Composable
private fun EmptyDay() {
    Column(
        Modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Nothing on the rule for this day.", color = Chotki.muted, fontSize = 14.sp)
        Spacer(Modifier.size(6.dp))
        Text(
            "Take something on from the library when you are ready.",
            color = Chotki.faint,
            fontSize = 13.sp,
        )
    }
}

@Composable
private fun EntryRow(
    entry: DayEntry,
    clock: ClockStyle,
    onToggle: () -> Unit,
    onReadPrayers: () -> Unit,
    onReadReading: () -> Unit,
    onReadPsalter: () -> Unit,
    onEdit: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // The box, and only the box. It draws at 20dp and responds across 44,
        // which is the platform's minimum target and the right answer to a small
        // control — rather than a tap gesture over the whole row.
        Box(
            Modifier
                .size(44.dp)
                .clickable(enabled = !entry.isDispensed, onClick = onToggle)
                .semantics { contentDescription = "Mark ${entry.rule.title} kept" },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                Modifier
                    .size(20.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(if (entry.showsAsSatisfied) Chotki.gold else Chotki.panel),
                contentAlignment = Alignment.Center,
            ) {
                if (entry.showsAsSatisfied) {
                    Text("✓", color = Chotki.ground, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        Column(Modifier.weight(1f).padding(start = 4.dp)) {
            Text(
                text = entry.rule.title,
                color = if (entry.showsAsSatisfied) Chotki.muted else Chotki.parchment,
                fontSize = 15.sp,
                textDecoration = if (entry.showsAsSatisfied) TextDecoration.LineThrough else null,
            )
            val dispensation = entry.dispensation
            if (dispensation != null) {
                // The Church lifted it. Said plainly, so the day teaches
                // something rather than the rule seeming to have broken.
                Text("Not observed during $dispensation", color = Chotki.goldDim, fontSize = 12.sp)
            } else if (entry.isStoodDown) {
                Text("Stood down", color = Chotki.faint, fontSize = 12.sp)
            }
        }

        // "All day" rather than "anytime": a fast is not optional, and
        // "anytime" reads as though it were.
        Text(
            text = entry.rule.timeOfDay?.let { Format.time(it, clock) } ?: "All day",
            color = if (entry.isKept) Chotki.faint else Chotki.muted,
            fontSize = 13.sp,
        )

        // The way to the words, which is the point of the rule. Shown whenever
        // the app holds the text the rule names — the reading rules had no way
        // through for months because this asked only about prayers, and the
        // day's Gospel is no less a text for not being one.
        when (entry.rule.reference) {
            RuleReference.PRAYERS -> Reference(
                "Read the prayers for ${entry.rule.title}",
                onReadPrayers,
            )
            RuleReference.READING -> Reference(
                "Read ${entry.rule.title.replaceFirstChar { it.lowercase() }}",
                onReadReading,
            )
            RuleReference.PSALTER -> Reference("Read today's kathisma", onReadPsalter)
            RuleReference.NONE -> Unit
        }

        Text(
            "✎",
            color = Chotki.faint,
            fontSize = 16.sp,
            modifier = Modifier
                .size(44.dp)
                .wrapContentSize()
                .clickable(onClick = onEdit)
                .semantics { contentDescription = "Edit ${entry.rule.title}" },
        )
    }
}

private val months = listOf(
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)

private val weekdays = listOf(
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
)

internal fun longDate(date: CalendarDate): String =
    "${weekdays[date.weekday.number - 1]} ${date.day} ${months[date.month - 1]}"

/** The three lines that lead to the text, wherever that text lives. */
@Composable
private fun Reference(description: String, onTap: () -> Unit) {
    Text(
        "☰",
        color = Chotki.goldDim,
        fontSize = 16.sp,
        modifier = Modifier
            .size(44.dp)
            .wrapContentSize()
            .clickable(onClick = onTap)
            .semantics { contentDescription = description },
    )
}
