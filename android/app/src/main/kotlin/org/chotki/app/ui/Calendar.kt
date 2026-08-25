package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.CalendarDate
import kotlin.math.min

/**
 * The calendar above the day's rules, in one of two heights.
 *
 * Going back is not an edge case. Someone who kept their evening prayers and
 * forgot to say so should be able to put that right — the record is supposed to
 * describe what happened, and a record that can only be written on the day it
 * happened describes the app's convenience instead.
 *
 * But a six-row month on a phone is most of the screen, and it pushed the very
 * rules it sits above off the bottom. So it is capped at half the height it is
 * given, and it folds down to the one week being looked at as soon as the
 * rules are scrolled. Folded, the arrows step by week — stepping by month from
 * a view showing seven days would move the calendar somewhere it cannot show.
 */
@Composable
fun Calendar(
    state: AppState,
    collapsed: Boolean,
    maxHeight: Dp,
    modifier: Modifier = Modifier,
) {
    val month = state.visibleMonth
    val firstOfMonth = CalendarDate.of(month.year, month.month, 1)!!
    val leading = firstOfMonth.weekday.number - 1 // Sunday first, as the church week runs
    val days = month.lastDayOfMonth
    val weeks = ((leading + days) + 6) / 7

    val weekStart = state.selectedDate.plusDays(-(state.selectedDate.weekday.number - 1))

    // The cap is enforced twice: the cells are sized to fit inside it, and the
    // whole thing is clamped to it. The sizing keeps the last week visible; the
    // clamp keeps the promise even if the chrome grows — a large font scale, a
    // longer month name — because a calendar that quietly took three-fifths of
    // the screen is how the rules got pushed off it in the first place.
    BoxWithConstraints(modifier.fillMaxWidth().heightIn(max = maxHeight).testTag(TAG)) {
        // The chrome above the grid — the month and its arrows, then the
        // weekday initials — comes off the top before the cells are sized, or
        // the cap is not a cap.
        val forCells = (maxHeight - CHROME).coerceAtLeast(0.dp)
        val widest = (this@BoxWithConstraints.maxWidth - 16.dp) / 7

        // Folded either because the rules are being read, or because a month
        // will not fit legibly in the height available. In landscape the second
        // one bites hard: half of a short screen, less the chrome, left cells
        // too small to draw the number in, and the calendar became a heading
        // with nothing under it. A week always fits.
        val monthCell = min((forCells / weeks).value, widest.value).dp
        val folded = collapsed || monthCell < LEGIBLE

        val rows = if (folded) 1 else weeks
        val cell = min((forCells / rows).value, widest.value).dp

        Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp)) {
            Navigation(state, folded, month, firstOfMonth, days, weekStart)

            Row(Modifier.fillMaxWidth()) {
                for (initial in listOf("s", "m", "t", "w", "t", "f", "s")) {
                    Text(
                        initial,
                        color = Chotki.faint,
                        fontSize = 11.sp,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                    )
                }
            }

            if (folded) {
                Row(Modifier.fillMaxWidth()) {
                    for (offset in 0 until 7) {
                        DayCell(state, weekStart.plusDays(offset), Modifier.weight(1f), cell)
                    }
                }
            } else {
                var day = 1
                while (day <= days) {
                    Row(Modifier.fillMaxWidth()) {
                        for (column in 0 until 7) {
                            val blank = (day == 1 && column < leading) || day > days
                            if (blank) {
                                Box(Modifier.weight(1f).height(cell))
                            } else {
                                DayCell(
                                    state,
                                    CalendarDate.of(month.year, month.month, day)!!,
                                    Modifier.weight(1f),
                                    cell,
                                )
                                day += 1
                            }
                        }
                    }
                }
            }
        }
    }
}

const val TAG = "the calendar"

/**
 * The month row and its arrows, plus the initials below them.
 *
 * Measured rather than guessed at: the arrows are 20sp with 4dp above and
 * below inside a row padded 6dp each way, and the initials are 11sp. An
 * earlier estimate of 52dp was seven pixels short, and seven pixels short of a
 * cap is not a cap.
 */
private val CHROME = 64.dp

/**
 * Below this a day cell cannot hold a two-digit number at the app's text size,
 * and the grid draws as empty boxes. Better to show one legible week.
 */
private val LEGIBLE = 30.dp

/**
 * Folded, the arrows move the selected day by a week rather than moving a
 * month behind it. Moving the week without moving the selection would leave
 * the rules below describing a day no longer on screen.
 */
@Composable
private fun Navigation(
    state: AppState,
    collapsed: Boolean,
    month: CalendarDate,
    firstOfMonth: CalendarDate,
    days: Int,
    weekStart: CalendarDate,
) {
    fun step(by: Int) {
        if (collapsed) {
            state.selectedDate = state.selectedDate.plusDays(7 * by)
            state.visibleMonth = state.selectedDate
        } else {
            state.visibleMonth =
                if (by < 0) firstOfMonth.plusDays(-1) else firstOfMonth.plusDays(days)
        }
    }

    Row(
        Modifier.fillMaxWidth().padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Arrow("‹", if (collapsed) "The week before" else "The month before") { step(-1) }
        Text(
            if (collapsed) weekLabel(weekStart) else "${monthName(month.month)} ${month.year}",
            color = Chotki.parchment,
            fontSize = 16.sp,
        )
        Arrow("›", if (collapsed) "The week after" else "The month after") { step(1) }
    }
}

@Composable
private fun Arrow(glyph: String, description: String, onTap: () -> Unit) {
    Text(
        glyph,
        color = Chotki.muted,
        fontSize = 20.sp,
        modifier = Modifier
            .clickable(onClick = onTap)
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .semantics { contentDescription = description },
    )
}

/** A week can straddle two months, and saying only one of them would mislead. */
private fun weekLabel(start: CalendarDate): String {
    val end = start.plusDays(6)
    return if (start.month == end.month) {
        "${monthName(start.month)} ${start.year}"
    } else if (start.year == end.year) {
        "${shortMonth(start.month)} – ${shortMonth(end.month)} ${end.year}"
    } else {
        "${shortMonth(start.month)} ${start.year} – ${shortMonth(end.month)} ${end.year}"
    }
}

@Composable
private fun DayCell(state: AppState, date: CalendarDate, modifier: Modifier, cell: Dp) {
    val selected = date == state.selectedDate
    val settled = state.isSettled(date)
    val hasAnything = state.entries(date).isNotEmpty()

    Box(
        modifier
            .height(cell)
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

private fun shortMonth(month: Int) = monthName(month).take(3)
