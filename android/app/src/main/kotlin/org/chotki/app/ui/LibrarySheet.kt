package org.chotki.app.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.Rule
import org.chotki.core.content.Content
import org.chotki.core.content.RuleTemplateJson

/**
 * Rules you can take on, folded into sections.
 *
 * Nothing here is on by default and nothing switches itself on. Taking a rule
 * on copies it, so it becomes yours to rename and retime — the library is a
 * starting point, not a set of obligations.
 *
 * Twenty-four rules in one scroll was a long way to the bottom, and the one
 * control that makes something new lived at the very end of it. The sections
 * fold now, in the order Ryan set: what happens in church first, what you
 * wrote yourself last.
 */
@Composable
fun LibrarySheet(
    state: AppState,
    modifier: Modifier = Modifier,
    onWriteYourOwn: () -> Unit = {},
    /**
     * Taking a template on opens it filled in, so how often can be settled
     * there. Rules of one's own are put back with [AppState.takeUp] instead:
     * that is the same rule returning, and its history follows it.
     */
    onTakeOn: (Rule) -> Unit = {},
) {
    val custom = state.customEntries

    // One at a time. With six sections and a phone screen, letting them all
    // stand open simply rebuilds the scroll the sections were meant to replace.
    var open by rememberSaveable { mutableStateOf<String?>(null) }
    var asking by rememberSaveable { mutableStateOf(false) }
    var hideCaution by rememberSaveable { mutableStateOf(false) }

    LazyColumn(modifier.fillMaxWidth()) {
        item {
            Text(
                "Select a prayer, reading, or discipline to add to your routine.",
                color = Chotki.faint,
                fontSize = 13.sp,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
        }

        for (section in SECTIONS) {
            val templates = Content.ruleLibrary.filter {
                it.category == section.key && it.id != "reflection"
            }
            if (templates.isEmpty()) continue
            item(key = "section-${section.key}") {
                Panel(
                    name = section.name,
                    count = templates.size,
                    isOpen = open == section.key,
                    onToggle = { open = if (open == section.key) null else section.key },
                ) {
                    for (template in templates) TemplateRow(template, state, onTakeOn)
                }
            }
        }

        // Rules of his own, kept so setting one down for a season does not mean
        // writing it out again. The way to make a new one sits under this list.
        item(key = "section-custom") {
            Panel(
                name = "Custom",
                count = custom.size,
                isOpen = open == "custom",
                onToggle = { open = if (open == "custom") null else "custom" },
            ) {
                if (custom.isEmpty()) {
                    Text(
                        "Nothing of your own yet.",
                        color = Chotki.faint,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(start = 18.dp, bottom = 12.dp),
                    )
                } else {
                    for (rule in custom) CustomRow(rule, state)
                }
            }
        }

        item(key = "write-your-own") {
            WriteYourOwn {
                if (state.settings.customCautionDismissed) onWriteYourOwn() else asking = true
            }
        }
    }

    if (asking) {
        AlertDialog(
            onDismissRequest = { asking = false },
            containerColor = Chotki.panel,
            text = {
                Column {
                    Text(
                        CUSTOM_CAUTION,
                        color = Chotki.parchmentDim,
                        fontFamily = FontFamily.SansSerif,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                    )
                    Row(
                        Modifier
                            .padding(top = 16.dp)
                            .clickable { hideCaution = !hideCaution }
                            .semantics { contentDescription = "Don't show again" },
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Box(
                            Modifier
                                .size(18.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(if (hideCaution) Chotki.gold else Chotki.ground)
                                .border(
                                    1.dp,
                                    if (hideCaution) Chotki.gold else Chotki.line,
                                    RoundedCornerShape(4.dp),
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (hideCaution) Text("✓", color = Chotki.ground, fontSize = 12.sp)
                        }
                        Text(
                            "Don't show again",
                            color = Chotki.parchment,
                            fontFamily = FontFamily.SansSerif,
                            fontSize = 14.sp,
                        )
                    }
                }
            },
            confirmButton = {
                Text(
                    "I understand",
                    color = Chotki.gold,
                    fontSize = 16.sp,
                    modifier = Modifier
                        .clickable {
                            if (hideCaution) {
                                state.updateSettings { it.copy(customCautionDismissed = true) }
                            }
                            asking = false
                            onWriteYourOwn()
                        }
                        .padding(horizontal = 8.dp, vertical = 8.dp)
                        .semantics { contentDescription = "I understand" },
                )
            },
        )
    }
}

private const val CUSTOM_CAUTION =
    "This section is for personalized routines aimed at improving your overall " +
        "physical, mental, and spiritual health. It is not intended to enable you " +
        "to manufacture your own Orthodoxy. We strongly recommend that where " +
        "appropriate, custom rules be discussed with your priest or spiritual father. " +
        "If that is not possible, keep these custom rules simple and attainable " +
        "(e.g., jogging, swimming, sobriety)."

/** A circle under the list, not a row between Life and Custom. */
@Composable
private fun WriteYourOwn(onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(top = 28.dp, bottom = 32.dp)
            .semantics { contentDescription = "Write your own rule" },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier
                .size(54.dp)
                .border(1.5.dp, Chotki.goldDim, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text("+", color = Chotki.gold, fontFamily = FontFamily.Serif, fontSize = 30.sp)
        }
        Text(
            "Write your own rule",
            color = Chotki.parchment,
            fontFamily = FontFamily.Serif,
            fontSize = 16.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 10.dp),
        )
    }
}

/** The sections of the library, in the order Ryan set them. */
private data class Section(val key: String, val name: String)

private val SECTIONS = listOf(
    Section("services", "Services"),
    Section("prayer", "Prayer"),
    Section("reading", "Reading"),
    Section("fasting", "Fasting"),
    // Not in Ryan's list of five. It holds reflection, almsgiving, and the
    // prayer for the departed. Placed above Custom rather than folded into
    // Prayer, which none of them quite are.
    Section("life", "Life"),
)

@Composable
private fun Panel(
    name: String,
    count: Int,
    isOpen: Boolean,
    onToggle: () -> Unit,
    body: @Composable () -> Unit,
) {
    val turn by animateFloatAsState(if (isOpen) 90f else 0f, tween(300), label = "chevron")
    Column(Modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onToggle)
                .padding(horizontal = 18.dp, vertical = 15.dp)
                .semantics {
                    contentDescription = if (isOpen) "Close $name" else "Open $name, $count rules"
                },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("›", color = Chotki.muted, fontSize = 15.sp, modifier = Modifier.rotate(turn))
            Text(name, color = Chotki.gold, fontSize = 15.sp, modifier = Modifier.weight(1f))
            Text("$count", color = Chotki.faint, fontSize = 12.sp)
        }
        AnimatedVisibility(
            visible = isOpen,
            enter = expandVertically(tween(320)) + fadeIn(tween(200, delayMillis = 90)),
            exit = shrinkVertically(tween(280)) + fadeOut(tween(120)),
        ) {
            Column(Modifier.fillMaxWidth().padding(bottom = 8.dp)) { body() }
        }
        HorizontalDivider(color = Chotki.lineSoft)
    }
}

@Composable
private fun CustomRow(rule: Rule, state: AppState) {
    val onTheRule = state.isOnTheRule(rule)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 8.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                rule.title,
                color = if (onTheRule) Chotki.muted else Chotki.parchment,
                fontSize = 15.sp,
            )
            Text(
                rule.timeOfDay?.let {
                    org.chotki.core.Format.time(it, state.settings.clockStyle)
                } ?: "All day",
                color = Chotki.faint,
                fontSize = 13.sp,
            )
            val note = rule.note
            if (note != null) Text(note, color = Chotki.faint, fontSize = 12.sp)
            if (rule.givenByPriest == true) {
                Text(
                    state.settings.givenByPriestPhrase() ?: "GIVEN BY A PRIEST",
                    color = Chotki.goldDim,
                    fontSize = 9.sp,
                    modifier = Modifier
                        .padding(top = 4.dp)
                        .border(1.dp, Chotki.line, RoundedCornerShape(3.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }
        }
        if (onTheRule) {
            Text("On your rule", color = Chotki.goldDim, fontSize = 12.sp)
        } else {
            Text(
                "Take on",
                color = Chotki.gold,
                fontSize = 13.sp,
                modifier = Modifier
                    .border(1.dp, Chotki.goldDim, RoundedCornerShape(4.dp))
                    .clickable { state.takeUp(rule) }
                    .padding(horizontal = 10.dp, vertical = 4.dp)
                    .semantics { contentDescription = "Take up ${rule.title}" },
            )
        }
        // Out of this list only. The rule and everything it has kept stay as
        // they are.
        Text(
            "✕",
            color = Chotki.faint,
            fontSize = 14.sp,
            modifier = Modifier
                .clickable { state.setAside(rule) }
                .padding(start = 10.dp, top = 2.dp)
                .semantics { contentDescription = "Set aside ${rule.title}" },
        )
    }
}

@Composable
private fun TemplateRow(
    template: RuleTemplateJson,
    state: AppState,
    onTakeOn: (Rule) -> Unit,
) {
    val taken = state.isTaken(template.id)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 8.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                template.title,
                color = if (taken) Chotki.muted else Chotki.parchment,
                fontSize = 15.sp,
            )
            Text(template.summary, color = Chotki.faint, fontSize = 13.sp)
            // Said here because taking it on and then not seeing it until
            // Saturday reads as a rule that failed to arrive.
            val when_ = template.recurrence.plainly()
            if (when_ != null) Text(when_, color = Chotki.faint, fontSize = 12.sp)
            val note = template.note
            if (note != null && !taken) {
                Text(note, color = Chotki.goldDim, fontSize = 12.sp)
            }
        }
        if (taken) {
            Text("On your rule", color = Chotki.goldDim, fontSize = 12.sp)
        } else {
            Text(
                "Take on",
                color = Chotki.gold,
                fontSize = 13.sp,
                modifier = Modifier
                    .border(1.dp, Chotki.goldDim, RoundedCornerShape(4.dp))
                    .clickable { state.ruleFrom(template.id)?.let(onTakeOn) }
                    .padding(horizontal = 10.dp, vertical = 4.dp)
                    .semantics { contentDescription = "Take on ${template.title}" },
            )
        }
    }
}

/**
 * How often, in words, for the rules whose answer is not "every day".
 *
 * A rule whose day is not today used to look, from the library, like a rule
 * that had not been taken on at all. The library says when to expect it.
 */
private fun RuleTemplateJson.RecurrenceJson.plainly(): String? = when (kind) {
    "weekly" -> days.takeIf { it.isNotEmpty() }
        ?.joinToString(", ") { it.replaceFirstChar { c -> c.uppercase() } + "s" }
    "monthly" -> "Monthly"
    "once" -> "Once"
    "liturgical" -> if (trigger == "akathist") "Fridays of the Akathist in Great Lent" else null
    else -> null
}
