package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.remember
import org.chotki.core.content.Glossary
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
fun RulePrayers(
    rule: Rule,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    glossary: Glossary = Glossary.SHARED,
    onOpenTerm: (String) -> Unit = {},
) {
    // Scanned across the whole run, not prayer by prayer. A rule is read
    // straight through, so linking "Amen" at the end of all six is noise —
    // the run is the unit the reader lives, not the prayer.
    val prayers = (rule.prayerIDs ?: emptyList())
        .mapNotNull { id -> Content.prayers.firstOrNull { it.id == id } }
    val linked = remember(rule.id, glossary) {
        glossary.scanOnce(prayers.flatMap { it.paragraphs })
    }
    var paragraphIndex = 0

    Column(modifier.fillMaxSize().background(Chotki.ground)) {
        // Outside the border, and above it. The ornament is for the words that
        // were received, not for the app's own furniture: a way out of the
        // page is not part of what is being read, and framing it alongside the
        // prayers says that it is.
        Text(
            "\u2039 The day",
            color = Chotki.gold,
            fontSize = 14.sp,
            modifier = Modifier
                .clickable(onClick = onBack)
                .padding(horizontal = READING_MARGIN, vertical = 14.dp)
                .semantics { contentDescription = "Back to the day" },
        )

        Box(Modifier.fillMaxWidth().weight(1f)) {
    // Room at both ends for the ornament, so nothing sits on the rules.
    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 34.dp, bottom = 38.dp),
    ) {
        item {
            Text(
                rule.title,
                color = Chotki.parchment,
                fontSize = 18.sp,
                modifier = Modifier.padding(horizontal = READING_MARGIN),
            )
            Spacer(Modifier.size(10.dp))
        }

        items(prayers.size, key = { prayers[it].id }) { index ->
            val prayer = prayers[index]
            Column(Modifier.padding(horizontal = READING_MARGIN, vertical = 8.dp)) {
                Text(prayer.title, color = Chotki.gold, fontSize = 13.sp)
                val rubric = prayer.rubric
                if (rubric != null) Text(rubric, color = Chotki.faint, fontSize = 12.sp)
                Spacer(Modifier.size(6.dp))
                for (paragraph in prayer.paragraphs) {
                    TermText(
                        text = paragraph,
                        glossary = glossary,
                        matches = linked.getOrNull(paragraphIndex),
                        colour = Chotki.parchment,
                        size = 17.sp,
                        onOpenTerm = onOpenTerm,
                    )
                    paragraphIndex += 1
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
                modifier = Modifier.padding(horizontal = READING_MARGIN, vertical = 16.dp),
            )
        }
    }

            // Order matters. The fade is over the text and under the
            // ornament, so a line arriving at the top of the page comes out
            // from behind the border rather than across it.
            EdgeFade()
            VenerationBorder()
        }
    }
}

/**
 * How far the words are held from the edge.
 *
 * Wider than the app's usual 16dp because the ornament sits between the two.
 * The inner edge of the band is 25dp in, so this leaves about 19dp of air
 * around the text. Thirty was the first attempt and left five, which Ryan
 * rightly said was still crowding it.
 */
private val READING_MARGIN = 44.dp
