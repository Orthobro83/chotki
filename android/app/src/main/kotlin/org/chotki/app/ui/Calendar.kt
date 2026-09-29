package org.chotki.app.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.CalendarDate
import org.chotki.core.Observance
import kotlin.math.abs
import kotlin.math.min

/**
 * The calendar above the day's rules, in one of two heights.
 *
 * Going back is not an edge case. Someone who kept their evening prayers and
 * forgot to say so should be able to put that right — the record is supposed to
 * describe what happened, and a record that can only be written on the day it
 * happened describes the app's convenience instead.
 *
 * **Opening it is now something you ask for.** It used to fold and unfold on
 * its own, tied to whether the rules below had been scrolled, so reading your
 * rules took the month away and getting it back meant scrolling to the very
 * top. The grip under the grid decides it, and the decision stands until it is
 * changed.
 *
 * The automatic fold survives as one thing only: a legibility floor. A month on
 * a short landscape screen leaves cells too small to draw a date in, and the
 * grid draws as a page of empty boxes. A week always fits.
 */
@Composable
fun Calendar(
    state: AppState,
    expanded: Boolean,
    onToggleExpanded: () -> Unit,
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
    // longer month name — because a calendar that took three-fifths of the
    // screen is how the rules got pushed off it in the first place.
    BoxWithConstraints(modifier.fillMaxWidth().heightIn(max = maxHeight).testTag(TAG)) {
        val forCells = (maxHeight - CHROME).coerceAtLeast(0.dp)
        val widest = (this@BoxWithConstraints.maxWidth - 16.dp) / 7

        val monthCell = min((forCells / weeks).value, widest.value).dp
        val folded = !expanded || monthCell < LEGIBLE

        val rows = if (folded) 1 else weeks
        val cell = min((forCells / rows).value, widest.value).dp

        fun step(by: Int) {
            if (folded) {
                state.selectedDate = state.selectedDate.plusDays(7 * by)
                state.visibleMonth = state.selectedDate
            } else {
                state.visibleMonth =
                    if (by < 0) firstOfMonth.plusDays(-1) else firstOfMonth.plusDays(days)
            }
        }

        Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp)) {
            Navigation(folded, month, weekStart, ::step)

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

            // The whole grid takes the swipe, not a strip of it. Ryan asked for
            // "swiping left or right anywhere on the week", and a gesture that
            // only works on part of a target reads as a gesture that does not
            // work. The arrows stay: they are the larger target and they are
            // what a screen reader reaches.
            Column(
                Modifier
                    .fillMaxWidth()
                    .pointerInput(folded, state.selectedDate, state.visibleMonth) {
                        var travelled = 0f
                        detectHorizontalDragGestures(
                            onDragStart = { travelled = 0f },
                            onDragEnd = {
                                if (abs(travelled) > SWIPE) step(if (travelled < 0) 1 else -1)
                            },
                        ) { change, amount ->
                            change.consume()
                            travelled += amount
                        }
                    },
            ) {
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

            // Hidden when a month could not be drawn legibly anyway, so the
            // control is never offered where pressing it would do nothing.
            if (monthCell >= LEGIBLE) Grip(expanded, onToggleExpanded)
        }
    }
}

const val TAG = "the calendar"

/** How far a finger must travel before it counts as a week rather than a tap. */
private val SWIPE = 48f

/**
 * The month row and its arrows, the initials, and the grip.
 *
 * Measured rather than guessed at: the arrows are 20sp with 4dp above and
 * below inside a row padded 6dp each way, the initials are 11sp, and the grip
 * adds 18dp. An earlier estimate was seven pixels short, and seven pixels short
 * of a cap is not a cap.
 */
private val CHROME = 82.dp

/**
 * The smallest cell that can still hold the date in it.
 *
 * Derived rather than picked: the number is 14sp, which is about 19dp of line,
 * and the cell carries 2dp of padding each side. Below 24dp the digits start
 * being clipped and the grid draws as empty boxes, so a legible week is better
 * than an illegible month.
 */
private val LEGIBLE = 24.dp

/**
 * Folded, the arrows move the selected day by a week rather than moving a
 * month behind it. Moving the week without moving the selection would leave
 * the rules below describing a day no longer on screen.
 */
@Composable
private fun Navigation(
    collapsed: Boolean,
    month: CalendarDate,
    weekStart: CalendarDate,
    step: (Int) -> Unit,
) {
    // A box rather than SpaceBetween. With three flex children the label only
    // lands in the middle when both arrows happen to measure the same, and
    // "September" and "May" do not make that true for long.
    Box(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
        Arrow(
            "‹",
            if (collapsed) "The week before" else "The month before",
            Modifier.align(Alignment.CenterStart),
        ) { step(-1) }

        Text(
            if (collapsed) weekLabel(weekStart) else "${monthName(month.month)} ${month.year}",
            color = Chotki.parchment,
            fontSize = 16.sp,
            modifier = Modifier.align(Alignment.Center),
        )

        Arrow(
            "›",
            if (collapsed) "The week after" else "The month after",
            Modifier.align(Alignment.CenterEnd),
        ) { step(1) }
    }
}

@Composable
private fun Arrow(
    glyph: String,
    description: String,
    modifier: Modifier = Modifier,
    onTap: () -> Unit,
) {
    Text(
        glyph,
        color = Chotki.muted,
        fontSize = 20.sp,
        modifier = modifier
            .clickable(onClick = onTap)
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .semantics { contentDescription = description },
    )
}

/** The handle that opens the month and closes it again. */
@Composable
private fun Grip(expanded: Boolean, onToggle: () -> Unit) {
    val turn by animateFloatAsState(if (expanded) 180f else 0f, tween(320), label = "chevron")
    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(top = 4.dp, bottom = 8.dp)
            .semantics {
                contentDescription = if (expanded) "Show one week" else "Show the whole month"
            },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.width(30.dp).height(2.dp).clip(CircleShape).background(Chotki.line))
        Text(
            "⌄",
            color = Chotki.muted,
            fontSize = 13.sp,
            modifier = Modifier.padding(horizontal = 8.dp).rotate(turn),
        )
        Box(Modifier.width(30.dp).height(2.dp).clip(CircleShape).background(Chotki.line))
    }
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

    // Only what the person has asked to see. Hidden means the calendar looks
    // like an ordinary calendar, which is the whole point of that setting, and
    // a fast day quietly coloured red would be the app overriding it.
    val observances = state.settings.observances
    val day = state.liturgicalDay(date)
    val feast = day?.isGreatFeast == true && observances.feasts != Observance.HIDDEN
    val fast = day?.isFast == true && day.isFastFree == false &&
        observances.fasting != Observance.HIDDEN

    val mark: Color? = when {
        feast -> Chotki.violet
        fast -> Chotki.ochre
        else -> null
    }

    val animatedSize by animateDpAsState(cell, tween(300), label = "cell")

    Box(
        modifier
            .height(animatedSize)
            .padding(2.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(if (selected) Chotki.gold else Color.Transparent)
            .clickable { state.selectedDate = date }
            .semantics {
                contentDescription = buildString {
                    append("Day ${date.day}")
                    if (feast) append(", a great feast")
                    if (fast) append(", a fast day")
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "${date.day}",
                color = when {
                    selected -> Chotki.ground
                    mark != null -> mark
                    hasAnything -> Chotki.parchment
                    else -> Chotki.faint
                },
                fontSize = 14.sp,
            )
            // Quiet marks, never a score. The gold one says a day was seen
            // through and says nothing at all about the days that were not;
            // the coloured one says what the Church is keeping.
            Row(
                Modifier.height(5.dp),
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (mark != null && !selected) Dot(mark)
                if (settled && !selected) Dot(Chotki.goldDim)
            }
        }
    }
}

@Composable
private fun Dot(colour: Color) {
    Box(Modifier.size(4.dp).clip(CircleShape).background(colour))
}

private fun monthName(month: Int) = listOf(
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)[month - 1]

private fun shortMonth(month: Int) = monthName(month).take(3)
