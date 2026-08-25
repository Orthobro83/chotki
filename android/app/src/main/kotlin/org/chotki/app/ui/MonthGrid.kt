package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.CalendarDate

/**
 * The month, so a day can be reached and marked after the fact.
 *
 * Going back is not an edge case. Someone who kept their evening prayers and
 * forgot to say so should be able to put that right — the record is supposed to
 * describe what happened, and a record that can only be written on the day it
 * happened describes the app's convenience instead.
 */
@Composable
fun MonthGrid(state: AppState, modifier: Modifier = Modifier) {
    val month = state.visibleMonth
    val firstOfMonth = CalendarDate.of(month.year, month.month, 1)!!
    val leading = firstOfMonth.weekday.number - 1 // Sunday first, as the church week runs
    val days = month.lastDayOfMonth

    Column(modifier.fillMaxWidth().padding(horizontal = 8.dp)) {
        Row(
            Modifier.fillMaxWidth().padding(vertical = 6.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "‹",
                color = Chotki.muted,
                fontSize = 20.sp,
                modifier = Modifier
                    .clickable { state.visibleMonth = firstOfMonth.plusDays(-1) }
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .semantics { contentDescription = "The month before" },
            )
            Text("${monthName(month.month)} ${month.year}", color = Chotki.parchment, fontSize = 16.sp)
            Text(
                "›",
                color = Chotki.muted,
                fontSize = 20.sp,
                modifier = Modifier
                    .clickable { state.visibleMonth = firstOfMonth.plusDays(days) }
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .semantics { contentDescription = "The month after" },
            )
        }

        Row(Modifier.fillMaxWidth()) {
            for (initial in listOf("s", "m", "t", "w", "t", "f", "s")) {
                Text(
                    initial,
                    color = Chotki.faint,
                    fontSize = 11.sp,
                    modifier = Modifier.weight(1f),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
            }
        }

        var day = 1
        while (day <= days) {
            Row(Modifier.fillMaxWidth()) {
                for (column in 0 until 7) {
                    val cellIsBlank = (day == 1 && column < leading) || day > days
                    if (cellIsBlank) {
                        Box(Modifier.weight(1f).aspectRatio(1f))
                    } else {
                        DayCell(state, CalendarDate.of(month.year, month.month, day)!!, Modifier.weight(1f))
                        day += 1
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(state: AppState, date: CalendarDate, modifier: Modifier) {
    val selected = date == state.selectedDate
    val settled = state.isSettled(date)
    val hasAnything = state.entries(date).isNotEmpty()

    Box(
        modifier
            .aspectRatio(1f)
            .padding(2.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(if (selected) Chotki.gold else androidx.compose.ui.graphics.Color.Transparent)
            .clickable { state.selectedDate = date }
            .semantics { contentDescription = "Day ${date.day}" },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "${date.day}",
                color = when {
                    selected -> Chotki.ground
                    hasAnything -> Chotki.parchment
                    else -> Chotki.faint
                },
                fontSize = 14.sp,
            )
            // A quiet mark, never a score. It says a day was seen through, and
            // says nothing at all about the days that were not.
            if (settled && !selected) {
                Box(Modifier.size(4.dp).clip(CircleShape).background(Chotki.goldDim))
            }
        }
    }
}

private fun monthName(month: Int) = listOf(
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)[month - 1]
