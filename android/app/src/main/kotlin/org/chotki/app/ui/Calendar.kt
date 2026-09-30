package org.chotki.app.ui

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt
import kotlinx.coroutines.delay
import org.chotki.app.AppState
import org.chotki.core.CalendarDate
import org.chotki.core.Observance
import org.chotki.core.Weekday
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
 *
 * Folded, the week is a strip that follows the finger, the way the commitment
 * cards do. Today — or whichever day is selected — sits in the middle. Dragging
 * does not select. A tap does. A drag that is never followed by a tap returns
 * to that day, centered, after half a minute.
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
        // The selected day's center, in window pixels. The grip uses it so its
        // vertex sits on that centerline rather than on the column's own middle.
        var dayCenterX by remember { mutableStateOf<Float?>(null) }
        val reportDay: (LayoutCoordinates) -> Unit = { coords ->
            dayCenterX = coords.positionInWindow().x + coords.size.width / 2f
        }

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

            if (folded) {
                WeekStrip(state, reportDay)
            } else {
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
                // The month still takes a swipe as a page. The week above it,
                // when it is showing, follows the finger instead.
                Column(
                    Modifier
                        .fillMaxWidth()
                        .pointerInput(state.visibleMonth) {
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
                                        reportDay,
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
            if (monthCell >= LEGIBLE) Grip(expanded, onToggleExpanded, dayCenterX)
        }
    }
}

const val TAG = "the calendar"

/** How far a finger must travel before a month counts as turned. */
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

/** One day in the strip. The mockup's chip, not a cell stretched to the width. */
private val CHIP = 44.dp
private val CHIP_HEIGHT = 56.dp

/** A browse that never becomes a tap comes back after this long. */
private const val RETURN_AFTER_MS = 30_000L

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
            fontFamily = Chotki.reading,
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

/**
 * Days in a row, dragged like the commitment cards.
 *
 * The selected day is centered. Dragging looks at other days and does not
 * choose one. Choosing is a tap. If the strip is left somewhere else, it
 * comes back to the selected day — today, until a day is tapped — after
 * [RETURN_AFTER_MS].
 */
@Composable
private fun WeekStrip(state: AppState, onDayPlaced: (LayoutCoordinates) -> Unit) {
    val today = state.today
    val selected = state.selectedDate
    val span = remember(today, selected) {
        val start = earlier(today.plusDays(-420), selected.plusDays(-30))
        val end = later(today.plusDays(420), selected.plusDays(30))
        buildList {
            var day = start
            while (day <= end) {
                add(day)
                day = day.plusDays(1)
            }
        }
    }
    val initial = span.indexOf(selected).coerceAtLeast(0)
    // Start on the selected day. The first placement jumps to the centre,
    // rather than flying in from the first day or sliding in from the edge.
    val list = rememberLazyListState(initialFirstVisibleItemIndex = initial)
    var generation by remember { mutableIntStateOf(0) }
    var centering by remember { mutableStateOf(false) }
    var placed by remember { mutableStateOf(false) }
    val density = LocalDensity.current
    // One query for the whole strip, before a finger can drag across it.
    // A miss is remembered, so a later day does not open the database.
    LaunchedEffect(span.first().iso, span.last().iso, state.calendarVersion) {
        state.warmCalendar(span.first(), span.last())
    }

    BoxWithConstraints(Modifier.fillMaxWidth().testTag("the week")) {
        val viewport = with(density) { maxWidth.roundToPx() }
        val chip = with(density) { CHIP.roundToPx() }

        suspend fun centerOn(date: CalendarDate, animate: Boolean) {
            val index = span.indexOf(date)
            if (index < 0 || viewport <= 0) return
            centering = true
            try {
                val offset = -((viewport - chip) / 2)
                val distance = kotlin.math.abs(list.firstVisibleItemIndex - index)
                if (!animate || distance > 10) list.scrollToItem(index, offset)
                else list.animateScrollToItem(index, offset)
            } finally {
                centering = false
            }
        }

        LaunchedEffect(selected, span, viewport) {
            generation = 0
            centerOn(selected, animate = placed)
            placed = true
        }

        LaunchedEffect(list) {
            var drifted = false
            snapshotFlow { list.isScrollInProgress to centering }.collect { (moving, programmatic) ->
                if (programmatic) {
                    drifted = false
                    return@collect
                }
                if (moving) drifted = true
                else if (drifted) {
                    drifted = false
                    generation++
                }
            }
        }

        LaunchedEffect(generation) {
            if (generation == 0) return@LaunchedEffect
            delay(RETURN_AFTER_MS)
            centerOn(state.selectedDate, animate = true)
        }

        LazyRow(
            state = list,
            modifier = Modifier.fillMaxWidth().height(CHIP_HEIGHT),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            contentPadding = PaddingValues(horizontal = 2.dp),
        ) {
            items(span, key = { it.iso }) { date ->
                WeekChip(state, date, onDayPlaced)
            }
        }
    }
}

/** The handle under the week. A shallow gold chevron, turned over when open. */
@Composable
private fun Grip(expanded: Boolean, onToggle: () -> Unit, dayCenterX: Float?) {
    val turn by animateFloatAsState(if (expanded) 180f else 0f, tween(500), label = "chevron")
    var originX by remember { mutableStateOf(0f) }
    var widthPx by remember { mutableIntStateOf(0) }
    // The week's centered chip is not the same pixel as this box's center.
    // The vertex follows the day that was actually measured.
    val shift = if (dayCenterX != null && widthPx > 0) {
        dayCenterX - (originX + widthPx / 2f)
    } else {
        0f
    }
    Box(
        Modifier
            .fillMaxWidth()
            .onGloballyPositioned {
                originX = it.positionInWindow().x
                widthPx = it.size.width
            }
            .clickable(onClick = onToggle)
            .padding(top = 2.dp, bottom = 8.dp)
            .semantics {
                contentDescription = if (expanded) "Show one week" else "Show the whole month"
            },
        contentAlignment = Alignment.Center,
    ) {
        // The mockup's mark: viewBox 0 0 48 10, drawn 52 by 12, gold and dim.
        // The point of the chevron is the horizontal center of this canvas.
        Canvas(
            Modifier
                .size(52.dp, 12.dp)
                .offset { IntOffset(shift.roundToInt(), 0) }
                .rotate(turn),
        ) {
            val stroke = Stroke(
                width = 1.4.dp.toPx(),
                cap = StrokeCap.Round,
                join = androidx.compose.ui.graphics.StrokeJoin.Round,
            )
            val sx = size.width / 48f
            val sy = size.height / 10f
            drawLine(
                color = Chotki.goldDim,
                start = Offset(2f * sx, 2.5f * sy),
                end = Offset(24f * sx, 8f * sy),
                strokeWidth = stroke.width,
                cap = StrokeCap.Round,
            )
            drawLine(
                color = Chotki.goldDim,
                start = Offset(24f * sx, 8f * sy),
                end = Offset(46f * sx, 2.5f * sy),
                strokeWidth = stroke.width,
                cap = StrokeCap.Round,
            )
        }
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

private val chipShape = RoundedCornerShape(14.dp)

@Composable
private fun WeekChip(
    state: AppState,
    date: CalendarDate,
    onDayPlaced: (LayoutCoordinates) -> Unit,
) {
    val selected = date == state.selectedDate
    val (feast, fast, mark) = marks(state, date)
    val showFast = fast && !feast
    val letter = listOf("s", "m", "t", "w", "t", "f", "s")[date.weekday.number - 1]

    Column(
        Modifier
            .onGloballyPositioned { if (selected) onDayPlaced(it) }
            .width(CHIP)
            .height(CHIP_HEIGHT)
            .clip(chipShape)
            .background(
                when {
                    selected -> Color(0xFF17160F)
                    showFast -> Color(0xFF3A3454)
                    else -> Color(0xFF12131A)
                },
            )
            .then(
                if (selected) Modifier.border(1.5.dp, Chotki.gold, chipShape) else Modifier,
            )
            .clickable {
                state.selectedDate = date
                state.visibleMonth = date
            }
            .semantics { contentDescription = describe(date, feast, fast) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(letter, color = Chotki.faint, fontFamily = Chotki.reading, fontSize = 10.sp)
        Text(
            "${date.day}",
            color = when {
                mark != null -> mark
                else -> Chotki.parchmentDim
            },
            fontFamily = Chotki.reading,
            fontSize = 16.sp,
        )
    }
}

@Composable
private fun DayCell(
    state: AppState,
    date: CalendarDate,
    modifier: Modifier,
    cell: Dp,
    onDayPlaced: (LayoutCoordinates) -> Unit,
) {
    val selected = date == state.selectedDate
    val settled = state.isSettled(date)
    val hasAnything = state.entries(date).isNotEmpty()
    val (feast, fast, mark) = marks(state, date)
    val showFast = fast && !feast

    val animatedSize by animateDpAsState(cell, tween(300), label = "cell")

    Box(
        modifier
            .onGloballyPositioned { if (selected) onDayPlaced(it) }
            .height(animatedSize)
            .padding(2.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(
                when {
                    selected -> Color(0xFF17160F)
                    showFast -> Color(0xFF3A3454)
                    else -> Color.Transparent
                },
            )
            .then(
                if (selected) Modifier.border(1.5.dp, Chotki.gold, RoundedCornerShape(8.dp))
                else Modifier,
            )
            .clickable {
                state.selectedDate = date
                state.visibleMonth = date
            }
            .semantics { contentDescription = describe(date, feast, fast) },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                "${date.day}",
                color = when {
                    mark != null -> mark
                    hasAnything -> Chotki.parchment
                    else -> Chotki.faint
                },
                fontFamily = Chotki.reading,
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

/** Feast, then fast, then the colour a number wears. Feast gold outranks both. */
private fun marks(state: AppState, date: CalendarDate): Triple<Boolean, Boolean, Color?> {
    val observances = state.settings.observances
    val day = state.liturgicalDay(date)
    val feast = day?.isGreatFeast == true && observances.feasts != Observance.HIDDEN
    val fast = day?.isFast == true && day.isFastFree == false &&
        observances.fasting != Observance.HIDDEN
    val showFast = fast && !feast
    val mark: Color? = when {
        feast -> Chotki.gold
        date.weekday == Weekday.SUNDAY -> Chotki.ochre
        showFast -> Chotki.violet
        else -> null
    }
    return Triple(feast, fast, mark)
}

private fun describe(date: CalendarDate, feast: Boolean, fast: Boolean) = buildString {
    append("Day ${date.iso}")
    if (feast) append(", a great feast")
    if (fast) append(", a fast day")
}

@Composable
private fun Dot(colour: Color) {
    Box(Modifier.size(4.dp).clip(CircleShape).background(colour))
}

private fun earlier(a: CalendarDate, b: CalendarDate) = if (a <= b) a else b
private fun later(a: CalendarDate, b: CalendarDate) = if (a >= b) a else b

private fun monthName(month: Int) = listOf(
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)[month - 1]

private fun shortMonth(month: Int) = monthName(month).take(3)
