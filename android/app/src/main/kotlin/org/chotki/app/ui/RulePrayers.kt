package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.core.Rule
import org.chotki.core.content.Content

/**
 * The prayers a rule carries, in the order they are said.
 *
 * Reached from the rule itself rather than from the prayers list, because at the
 * moment of praying the question is "what am I saying now", not "which prayer
 * would I like to look at".
 */
@Composable
fun RulePrayers(rule: Rule, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val prayers = (rule.prayerIDs ?: emptyList())
        .mapNotNull { id -> Content.prayers.firstOrNull { it.id == id } }

    LazyColumn(modifier.fillMaxSize().background(Chotki.ground)) {
        item {
            Text(
                "‹ The day",
                color = Chotki.gold,
                fontSize = 14.sp,
                modifier = Modifier
                    .clickable(onClick = onBack)
                    .padding(16.dp)
                    .semantics { contentDescription = "Back to the day" },
            )
            Text(
                rule.title,
                color = Chotki.parchment,
                fontSize = 18.sp,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            Spacer(Modifier.size(10.dp))
        }

        items(prayers.size, key = { prayers[it].id }) { index ->
            val prayer = prayers[index]
            Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                Text(prayer.title, color = Chotki.gold, fontSize = 13.sp)
                val rubric = prayer.rubric
                if (rubric != null) Text(rubric, color = Chotki.faint, fontSize = 12.sp)
                Spacer(Modifier.size(6.dp))
                for (paragraph in prayer.paragraphs) {
                    Text(paragraph, color = Chotki.parchment, fontSize = 17.sp, lineHeight = 26.sp)
                    Spacer(Modifier.size(8.dp))
                }
                Text("Source · ${prayer.source}", color = Chotki.faint, fontSize = 11.sp)
            }
        }

        item {
            // Said plainly, because the difference between "these are the
            // prayers" and "these are some of the prayers" matters to someone
            // learning a rule.
            Text(
                "These are the prayers common to almost every form of this rule. Prayer books " +
                    "differ, and the full rule is settled with your priest or spiritual father.",
                color = Chotki.faint,
                fontSize = 12.sp,
                modifier = Modifier.padding(16.dp),
            )
        }
    }
}
