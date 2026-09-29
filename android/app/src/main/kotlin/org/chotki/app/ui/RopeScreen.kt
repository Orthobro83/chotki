package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.app.platform.Sounds
import org.chotki.core.PrayerScreen
import org.chotki.core.content.Glossary
import org.chotki.core.content.Content
import org.chotki.core.ropePrayerId
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer

/**
 * The prayer rope: a count, the knots, and the words beneath.
 *
 * The rope follows the prayer. One traditionally counted on a rope brings it;
 * a rule read straight through does not; choosing nothing brings it too, for
 * someone who has the words by heart and only wants somewhere to keep the count.
 * All of that is decided by `PrayerScreen` in `:core`, so both platforms answer
 * it the same way — and a person can always overrule it, because the marking
 * says what the tradition generally does rather than what anyone must do.
 *
 * The chime marks completion and the tick only confirms a press landed. Never
 * both at once: with your eyes closed they would run together.
 */
@Composable
fun RopeScreen(
    state: AppState,
    modifier: Modifier = Modifier,
    glossary: Glossary = Glossary.SHARED,
    onOpenTerm: (String) -> Unit = {},
) {
    // Held on the state, not remembered here.
    //
    // `remember` dies with the composition, so switching to the Reading and
    // back lost the count — a hundred-knot rule restarted at nought because
    // you looked something up. iOS had the identical fault and for the
    // identical reason: the screen's state was kept in the view rather than
    // beside it.
    var screen by state.prayers
    val showsRope = screen.showsRope()

    val prayer = screen.selection?.let { id -> Content.prayers.firstOrNull { it.id == id } }
    val sequence = screen.selection?.let { id -> Content.prayerSequences.firstOrNull { it.id == id } }

    Column(modifier.fillMaxSize().background(Chotki.ground)) {
        // Choosing goes through `choosing`, which is what clears an earlier
        // decision about the rope rather than leaving it stuck to everything
        // picked afterwards.
        ChooserRow(screen) { chosen -> screen = screen.choosing(chosen) }

        if (showsRope) {
            Text(
                "${screen.count}",
                color = Chotki.gold,
                fontSize = 56.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
                    .semantics { contentDescription = "The count" },
            )
            Text(
                if (screen.isComplete) "the knot is complete" else "of ${screen.target}",
                color = if (screen.isComplete) Chotki.goldDim else Chotki.muted,
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )

            Knots(screen, Modifier.padding(horizontal = 20.dp, vertical = 12.dp))

            Text(
                "Count",
                color = Chotki.ground,
                fontSize = 17.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(Chotki.gold)
                    .clickable {
                        val (next, completed) = screen.advanced()
                        if (next.count != screen.count) {
                            screen = next
                            // The chime marks completion; the tick only confirms
                            // a press landed. Never both at once — with your eyes
                            // closed they would run together.
                            if (completed) {
                                if (state.settings.chimeOnCompletion) Sounds.playBell()
                                // Only the Jesus Prayer, and only while it is the prayer open.
                                if (screen.selection == "jesus-prayer") {
                                    state.entries(state.selectedDate)
                                        .filter {
                                            it.rule.ropePrayerId == "jesus-prayer" ||
                                                it.rule.title == "The Jesus Prayer"
                                        }
                                        .forEach(state::markKept)
                                }
                            } else if (state.settings.tickEachKnot) {
                                Sounds.playTick()
                            }
                        }
                    }
                    .padding(vertical = 14.dp)
                    .semantics { contentDescription = "Count a knot" },
            )

            Row(
                Modifier.fillMaxWidth().padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                for (target in PrayerScreen.targets) {
                    Text(
                        "$target",
                        color = if (screen.target == target) Chotki.ground else Chotki.muted,
                        fontSize = 13.sp,
                        modifier = Modifier
                            .background(
                                if (screen.target == target) Chotki.gold else Chotki.panel,
                                RoundedCornerShape(4.dp),
                            )
                            .clickable { screen = screen.aiming(target) }
                            .padding(horizontal = 14.dp, vertical = 6.dp)
                            .semantics { contentDescription = "Count to $target" },
                    )
                }
                Text(
                    "Start again",
                    color = Chotki.muted,
                    fontSize = 13.sp,
                    modifier = Modifier
                        .clickable { screen = screen.startingAgain() }
                        .padding(8.dp)
                        .semantics { contentDescription = "Start again" },
                )
            }
        }

        // The words. A rope prayer keeps them under the count. A rule that is
        // read fades at the edges, and reaching the last line marks it.
        val paragraphs = when {
            sequence != null -> sequence.prayerIDs
                .mapNotNull { id -> Content.prayers.firstOrNull { it.id == id } }
            prayer != null -> listOf(prayer)
            else -> emptyList()
        }

        if (paragraphs.isNotEmpty()) {
            // Scanned across the whole run, not prayer by prayer. A rule is
            // read straight through, so linking "Amen" at the end of every
            // prayer in it turns a text meant to be prayed into a page of
            // references.
            val linked = remember(screen.selection, glossary) {
                glossary.scanOnce(paragraphs.flatMap { it.paragraphs })
            }
            // Where each prayer's paragraphs begin in that flattened run.
            val firstOf = remember(screen.selection, glossary) {
                paragraphs.runningFold(0) { at, each -> at + each.paragraphs.size }
            }

            Box(Modifier.fillMaxWidth().padding(top = 8.dp).size(1.dp).background(Chotki.lineSoft))
            val prayerList = rememberLazyListState()
            if (!showsRope) {
                PrayerEnd(prayerList, screen.selection, state)
            }
            LazyColumn(
                Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .then(if (showsRope) Modifier else Modifier.edgeFade()),
                state = prayerList,
            ) {
                items(paragraphs.size, key = { paragraphs[it].id }) { index ->
                    val each = paragraphs[index]
                    Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                        Text(each.title, color = Chotki.gold, fontSize = 13.sp)
                        val rubric = each.rubric
                        if (rubric != null) {
                            Text(rubric, color = Chotki.faint, fontSize = 12.sp)
                        }
                        Spacer(Modifier.size(4.dp))
                        for ((line, paragraph) in each.paragraphs.withIndex()) {
                            TermText(
                                text = paragraph,
                                glossary = glossary,
                                matches = linked.getOrNull(firstOf[index] + line),
                                colour = Chotki.parchment,
                                size = 17.sp,
                                onOpenTerm = onOpenTerm,
                            )
                            Spacer(Modifier.size(8.dp))
                        }
                        Text("Source · ${each.source}", color = Chotki.faint, fontSize = 11.sp)
                    }
                }
                item(key = "prayer-end") { Spacer(Modifier.size(24.dp)) }
            }
        } else {
            Spacer(Modifier.weight(1f))
        }
    }
}

/**
 * What is being prayed. Grouped, because a rule said through and a prayer
 * repeated are different things done with the same screen.
 */
@Composable
private fun ChooserRow(screen: PrayerScreen, onChoose: (String?) -> Unit) {
    var open by remember { mutableStateOf(false) }
    // The rope on its own is not a choice. A rope prayer brings the rope;
    // a rule that is read does not.
    val label = screen.selection?.let { selection ->
        Content.prayerSequences.firstOrNull { it.id == selection }?.title
            ?: Content.prayers.firstOrNull { it.id == selection }?.title
    } ?: "Prayers"

    Column(Modifier.fillMaxWidth()) {
        // The chevron is what says this is a menu. Without it the title read as
        // a heading, and there was nothing to suggest the other prayers were
        // one tap away.
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 10.dp)
                .border(1.dp, Chotki.line, RoundedCornerShape(4.dp))
                .clickable { open = !open }
                .padding(horizontal = 14.dp, vertical = 10.dp)
                .semantics { contentDescription = "Choose what to pray" },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(label, color = Chotki.parchment, fontSize = 15.sp)
            Text(if (open) "⌃" else "⌄", color = Chotki.gold, fontSize = 15.sp)
        }

        if (open) {
            LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                item {
                    Text("Rules", color = Chotki.gold, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
                }
                items(Content.prayerSequences.size) { index ->
                    val sequence = Content.prayerSequences[index]
                    Option(sequence.title) { onChoose(sequence.id); open = false }
                }
                item {
                    Text("On the rope", color = Chotki.gold, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
                }
                val onRope = Content.prayers.filter { it.isForRope }
                items(onRope.size) { index ->
                    Option(onRope[index].title) { onChoose(onRope[index].id); open = false }
                }
                item {
                    Text("Read", color = Chotki.gold, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp))
                }
                val read = Content.prayers.filterNot { it.isForRope }
                items(read.size) { index ->
                    Option(read[index].title) { onChoose(read[index].id); open = false }
                }
            }
        }
    }
}

@Composable
private fun PrayerEnd(
    list: androidx.compose.foundation.lazy.LazyListState,
    selection: String?,
    state: AppState,
) {
    var scrolled by remember(selection) { mutableStateOf(false) }
    var marked by remember(selection) { mutableStateOf(false) }
    LaunchedEffect(list, selection) {
        snapshotFlow { list.firstVisibleItemIndex to list.firstVisibleItemScrollOffset }
            .collect { (index, offset) -> if (index > 0 || offset > 8) scrolled = true }
    }
    LaunchedEffect(list, scrolled, selection) {
        if (!scrolled || marked) return@LaunchedEffect
        snapshotFlow { list.layoutInfo.visibleItemsInfo.any { it.key == "prayer-end" } }
            .collect { visible ->
                if (!visible || marked) return@collect
                val title = when (selection) {
                    "morning" -> "Morning prayers"
                    "evening" -> "Evening prayers"
                    else -> return@collect
                }
                marked = true
                state.entries(state.selectedDate)
                    .filter { it.rule.title == title }
                    .forEach(state::markKept)
            }
    }
}

private fun Modifier.edgeFade(): Modifier = graphicsLayer {
    compositingStrategy = CompositingStrategy.Offscreen
}.drawWithContent {
    drawContent()
    drawRect(
        brush = Brush.verticalGradient(
            0f to Color.Transparent,
            0.1f to Color.Black,
            0.9f to Color.Black,
            1f to Color.Transparent,
        ),
        blendMode = BlendMode.DstIn,
    )
}

@Composable
private fun Option(label: String, onPick: () -> Unit) {
    Text(
        label,
        color = Chotki.parchment,
        fontSize = 15.sp,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onPick)
            .padding(vertical = 10.dp)
            .semantics { contentDescription = "Pray $label" },
    )
}

/** One dot per knot, filling as it goes. */
@Composable
private fun Knots(screen: PrayerScreen, modifier: Modifier = Modifier) {
    val perRow = minOf(screen.target, 10)
    Column(modifier.fillMaxWidth()) {
        var index = 0
        while (index < screen.target) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                for (column in 0 until perRow) {
                    if (index < screen.target) {
                        val filled = index < screen.count
                        Box(
                            Modifier
                                .weight(1f)
                                .size(9.dp)
                                .clip(CircleShape)
                                .background(if (filled) Chotki.gold else Chotki.panel),
                        )
                        index += 1
                    } else {
                        Box(Modifier.weight(1f))
                    }
                }
            }
            Spacer(Modifier.size(6.dp))
        }
    }
}
