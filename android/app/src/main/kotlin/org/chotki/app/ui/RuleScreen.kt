package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.CalendarDate
import org.chotki.core.ClockStyle
import org.chotki.core.DayEntry
import org.chotki.core.Format
import org.chotki.core.RuleReference
import org.chotki.core.glossarySlug
import org.chotki.core.reference
import org.chotki.core.ropePrayerId

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
    onReadReflections: (org.chotki.core.Weekday) -> Unit = {},
    onEdit: (DayEntry) -> Unit = {},
    onOpenLibrary: () -> Unit = {},
    /** Straight to the rope, already counting the prayer the rule names. */
    onGoToRope: (String) -> Unit = {},
    /** The glossary, opened at the entry that explains this rule. */
    onOpenTerm: (String) -> Unit = {},
) {
    val entries = state.entries(state.selectedDate)
    val list = rememberLazyListState()

    // Held here rather than inside the calendar, and deliberately not derived
    // from the scroll position any more. It used to fold the moment the rules
    // were touched, so reading your rules took the month away and getting it
    // back meant scrolling to the very top; Ryan asked for a control instead.
    // Surviving the composition is the point: following a rule to its prayers
    // and coming back should find the calendar as it was left.
    var monthOpen by rememberSaveable { mutableStateOf(false) }

    BoxWithConstraints(modifier.fillMaxSize().background(Chotki.ground)) {
        // Half, and no more. The calendar used to take whatever it wanted and
        // the rules it sits above were pushed off the bottom of the screen,
        // where nothing could reach them because this column does not scroll.
        val cap = this@BoxWithConstraints.maxHeight / 2

        Column(Modifier.fillMaxSize()) {
            Calendar(
                state,
                expanded = monthOpen,
                onToggleExpanded = { monthOpen = !monthOpen },
                maxHeight = cap,
            )
            DayHeader(state.selectedDate)

            if (entries.isEmpty()) {
                // Takes the room the rules would have had, so the mark sits in
                // the space that is actually free rather than under the bar.
                EmptyDay(onOpenLibrary, Modifier.weight(1f))
            } else {
                // The weight is the fix. Without it this takes whatever height
                // is left over, which can be none, and a list of zero height
                // scrolls nowhere.
                LazyColumn(Modifier.fillMaxWidth().weight(1f), state = list) {
                    items(entries, key = { it.id }) { entry ->
                        EntryRow(
                            entry = entry,
                            clock = state.settings.clockStyle,
                            isPaused = state.isPaused(entry.rule),
                            onToggle = { state.toggleKept(entry) },
                            onReadPrayers = { onReadPrayers(entry) },
                            onReadReading = onReadReading,
                            onReadPsalter = onReadPsalter,
                            // The day this row is on, so the way through lands
                            // on that question rather than at the top of a
                            // seven-day scroll.
                            onReadReflections = { onReadReflections(entry.date.weekday) },
                            onGoToRope = onGoToRope,
                            onOpenTerm = onOpenTerm,
                            onEdit = { onEdit(entry) },
                            onMarkKeptLate = { state.markKeptLate(entry) },
                            onStandDown = { state.standDown(entry) },
                            onPause = { state.pause(entry.rule) },
                            onResume = { state.resume(entry.rule) },
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

/**
 * Nothing due, and the way to change that.
 *
 * The words alone sent someone hunting for a control they had not noticed. The
 * library is named in the sentence, so the library is drawn under it, at a size
 * that reads as the thing to press. The corner icon stays where it is — it is
 * how the library is reached on every other day, and a control that moves
 * depending on whether the day is empty is worse than one that does not.
 */
@Composable
private fun EmptyDay(onOpenLibrary: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("Nothing on the rule for this day.", color = Chotki.muted, fontSize = 14.sp)
        Spacer(Modifier.size(6.dp))
        Text(
            "Take something on from the library when you are ready.",
            color = Chotki.faint,
            fontSize = 13.sp,
        )
        Spacer(Modifier.weight(1f))
        Column(
            Modifier
                .clickable(onClick = onOpenLibrary)
                .padding(14.dp)
                // Not the same label as the icon in the bar. Two controls
                // announcing themselves identically on one screen is a maze
                // for anyone using a screen reader, and it made the test that
                // clicks the bar's icon ambiguous — which is how it was found.
                .semantics { contentDescription = "Take something on from the library" },
        ) {
            LibraryIcon(Chotki.gold, 56.dp)
        }
        Spacer(Modifier.weight(1.4f))
    }
}

@Composable
private fun EntryRow(
    entry: DayEntry,
    clock: ClockStyle,
    isPaused: Boolean,
    onToggle: () -> Unit,
    onReadPrayers: () -> Unit,
    onReadReading: () -> Unit,
    onReadPsalter: () -> Unit,
    onReadReflections: () -> Unit,
    onGoToRope: (String) -> Unit,
    onOpenTerm: (String) -> Unit,
    onEdit: () -> Unit,
    onMarkKeptLate: () -> Unit,
    onStandDown: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }

    Row(
        Modifier
            .fillMaxWidth()
            // Long press is the Mac's right click. On the row itself, so the
            // checkbox and the two icons keep their own gestures — the whole
            // row was a tap target once and it ticked rules off by accident.
            .combinedClickable(
                onClick = {},
                onLongClick = { menuOpen = true },
                // No ripple on the plain tap: nothing happens on a plain tap,
                // and a flash that says otherwise is a lie about the control.
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
            )
            .padding(horizontal = 10.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RuleMenu(
            open = menuOpen,
            entry = entry,
            isPaused = isPaused,
            onDismiss = { menuOpen = false },
            onReadPrayers = onReadPrayers,
            onReadReading = onReadReading,
            onReadPsalter = onReadPsalter,
            onReadReflections = onReadReflections,
            onGoToRope = onGoToRope,
            onToggle = onToggle,
            onMarkKeptLate = onMarkKeptLate,
            onStandDown = onStandDown,
            onEdit = onEdit,
            onPause = onPause,
            onResume = onResume,
        )

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
            // The title carries the glossary only where the rule leads nowhere
            // else. A row with two tap targets a line apart is a row where
            // people hit the wrong one, so the destination wins when there is
            // one and the long press offers the meaning instead.
            val destination = entry.rule.reference
            val slug = entry.rule.glossarySlug
            val titleIsLink = destination == RuleReference.NONE && slug != null

            Text(
                text = entry.rule.title,
                color = if (entry.showsAsSatisfied) Chotki.muted else Chotki.parchment,
                fontSize = 15.sp,
                textDecoration = when {
                    entry.showsAsSatisfied -> TextDecoration.LineThrough
                    titleIsLink -> TextDecoration.Underline
                    else -> null
                },
                modifier = if (titleIsLink) {
                    Modifier
                        .clickable { onOpenTerm(slug!!) }
                        .semantics { contentDescription = "What ${entry.rule.title} means" }
                } else {
                    Modifier
                },
            )

            // Named rather than drawn. This was a "☰" at the far right of the
            // row, which said nothing about where it went and was easy to miss
            // entirely; Ryan asked for the destination in words.
            when (destination) {
                RuleReference.ROPE -> GoTo("Go to rope") {
                    entry.rule.ropePrayerId?.let(onGoToRope)
                }
                RuleReference.PRAYERS -> GoTo("Go to prayer", onReadPrayers)
                RuleReference.READING -> GoTo("Go to reading", onReadReading)
                RuleReference.PSALTER -> GoTo("Go to psalter", onReadPsalter)
                RuleReference.REFLECTIONS -> GoTo("Go to Reflections", onReadReflections)
                RuleReference.NONE -> Unit
            }

            if (entry.rule.givenByPriest == true) {
                GivenByPriest()
            }

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

/**
 * What the Mac's right-click menu offers, in the same order and the same words.
 *
 * Neither mobile platform had any of this. Android could edit a rule through
 * the pencil and nothing else: `standDown` and `remove` existed on `AppState`
 * and were called from nowhere, so a rule once taken on could not be stood down
 * for a day or paused at all.
 */
@Composable
private fun RuleMenu(
    open: Boolean,
    entry: DayEntry,
    isPaused: Boolean,
    onDismiss: () -> Unit,
    onReadPrayers: () -> Unit,
    onReadReading: () -> Unit,
    onReadPsalter: () -> Unit,
    onReadReflections: () -> Unit,
    onGoToRope: (String) -> Unit,
    onToggle: () -> Unit,
    onMarkKeptLate: () -> Unit,
    onStandDown: () -> Unit,
    onEdit: () -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
) {
    DropdownMenu(
        expanded = open,
        onDismissRequest = onDismiss,
        modifier = Modifier.background(Chotki.panel),
    ) {
        fun choosing(action: () -> Unit): () -> Unit = { onDismiss(); action() }

        if (entry.isDispensed) {
            // The Church lifted it. Nothing to mark, nothing to stand down.
            DropdownMenuItem(
                text = { Text("Lifted by the Church today", color = Chotki.muted) },
                onClick = onDismiss,
            )
        } else {
            when (entry.rule.reference) {
                RuleReference.ROPE -> {
                    Item("Go to the rope", choosing { entry.rule.ropePrayerId?.let(onGoToRope) })
                    HorizontalDivider(color = Chotki.lineSoft)
                }
                RuleReference.PRAYERS -> {
                    Item("Read the prayers", choosing(onReadPrayers))
                    HorizontalDivider(color = Chotki.lineSoft)
                }
                RuleReference.READING -> {
                    Item("Read the day\u2019s readings", choosing(onReadReading))
                    HorizontalDivider(color = Chotki.lineSoft)
                }
                RuleReference.PSALTER -> {
                    Item("Read today\u2019s kathisma", choosing(onReadPsalter))
                    HorizontalDivider(color = Chotki.lineSoft)
                }
                RuleReference.REFLECTIONS -> {
                    Item("Open Reflections", choosing(onReadReflections))
                    HorizontalDivider(color = Chotki.lineSoft)
                }
                RuleReference.NONE -> Unit
            }

            Item(
                if (entry.isKept) "Clear this day" else "Mark as kept",
                choosing(onToggle),
            )
            if (!entry.isKept) Item("Mark as kept, late", choosing(onMarkKeptLate))
            Item("Stand down for this day", choosing(onStandDown))
        }

        HorizontalDivider(color = Chotki.lineSoft)
        Item("Edit rule\u2026", choosing(onEdit))
        if (isPaused) {
            Item("Resume this rule", choosing(onResume))
        } else {
            Item("Pause this rule", choosing(onPause))
        }
    }
}

@Composable
private fun Item(label: String, onClick: () -> Unit) {
    DropdownMenuItem(
        text = { Text(label, color = Chotki.parchment, fontSize = 15.sp) },
        onClick = onClick,
    )
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
private fun GoTo(label: String, onTap: () -> Unit) {
    Row(
        Modifier
            .clickable(onClick = onTap)
            .padding(top = 3.dp, bottom = 3.dp, end = 8.dp)
            .semantics { contentDescription = label },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = Chotki.gold, fontSize = 13.sp)
        Text(" \u2192", color = Chotki.gold, fontSize = 13.sp)
    }
}

/**
 * Where a rule came from, when the person said so.
 *
 * Only ever the positive. An earlier drawing carried "not given by a priest"
 * on everything else, which makes a mark on every rule and therefore a mark on
 * none, and tells someone without a spiritual father the same thing on every
 * line of their day.
 */
@Composable
private fun GivenByPriest() {
    Text(
        "GIVEN BY A PRIEST",
        color = Chotki.goldDim,
        fontSize = 9.sp,
        letterSpacing = 0.09.em,
        modifier = Modifier
            .padding(top = 5.dp)
            .border(1.dp, Chotki.line, RoundedCornerShape(3.dp))
            .padding(horizontal = 7.dp, vertical = 3.dp),
    )
}
