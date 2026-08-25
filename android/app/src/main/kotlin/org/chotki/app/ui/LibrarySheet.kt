package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.content.Content
import org.chotki.core.content.RuleTemplateJson

/**
 * Rules you can take on, grouped by category.
 *
 * Nothing here is on by default and nothing switches itself on. Taking a rule on
 * copies it, so it becomes yours to rename and retime — the library is a
 * starting point, not a set of obligations.
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
    onTakeOn: (org.chotki.core.Rule) -> Unit = {},
) {
    val grouped = Content.ruleLibrary.groupBy { it.category }
    val custom = state.customEntries

    LazyColumn(modifier.fillMaxWidth().background(Chotki.ground)) {
        item {
            Text(
                "Take on what you are ready for. Two or three is a good beginning.",
                color = Chotki.faint,
                fontSize = 13.sp,
                modifier = Modifier.padding(16.dp),
            )
        }
        for ((category, templates) in grouped) {
            item {
                Text(
                    category.replaceFirstChar { it.uppercase() },
                    color = Chotki.gold,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 4.dp),
                )
            }
            items(templates.size, key = { templates[it].id }) { index ->
                TemplateRow(templates[index], state, onTakeOn)
            }
        }

        // Rules of his own, kept so setting one down for a season does not mean
        // writing it out again.
        if (custom.isNotEmpty()) {
            item {
                Text(
                    "Custom",
                    color = Chotki.gold,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 2.dp),
                )
                Text(
                    "Custom routines are usually taken on the advice of your priest or " +
                        "spiritual father.",
                    color = Chotki.faint,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 2.dp),
                )
            }
            items(custom.size, key = { custom[it].id }) { index ->
                CustomRow(custom[index], state)
            }
        }

        item {
            Text(
                "＋ Write your own rule",
                color = Chotki.gold,
                fontSize = 15.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onWriteYourOwn)
                    .padding(16.dp)
                    .semantics { contentDescription = "Write your own rule" },
            )
        }
    }
}

@Composable
private fun CustomRow(rule: org.chotki.core.Rule, state: AppState) {
    val onTheRule = state.isOnTheRule(rule)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
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
    onTakeOn: (org.chotki.core.Rule) -> Unit,
) {
    val taken = state.isTaken(template.id)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
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
