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
    onEdit: (DayEntry) -> Unit = {},
) {
    val entries = state.entries(state.selectedDate)

    Column(modifier.fillMaxSize().background(Chotki.ground)) {
        MonthGrid(state)
        DayHeader(state.selectedDate)

        if (entries.isEmpty()) {
            EmptyDay()
        } else {
            LazyColumn(Modifier.fillMaxWidth()) {
                items(entries, key = { it.id }) { entry ->
                    EntryRow(
                        entry = entry,
                        clock = state.settings.clockStyle,
                        onToggle = { state.toggleKept(entry) },
                        onReadPrayers = { onReadPrayers(entry) },
                        onEdit = { onEdit(entry) },
                    )
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

        // The way to the words, which is the point of a prayer rule. Shown only
        // when the rule actually carries prayers, and always when it does.
        if (entry.rule.hasPrayers) {
            Text(
                "☰",
                color = Chotki.goldDim,
                fontSize = 16.sp,
                modifier = Modifier
                    .size(44.dp)
                    .wrapContentSize()
                    .clickable(onClick = onReadPrayers)
                    .semantics { contentDescription = "Read the prayers for ${entry.rule.title}" },
            )
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
