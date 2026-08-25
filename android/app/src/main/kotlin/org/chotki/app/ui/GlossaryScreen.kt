package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.core.content.Content
import org.chotki.core.content.GlossaryEntryJson

/**
 * The terms, searchable.
 *
 * It exists because the calendar this app displays is full of language a
 * newcomer has no way to decode — "Major Feast of the Theotokos", "Leavetaking",
 * "Tone 2" — and looking each one up elsewhere breaks the thing you were doing.
 */
@Composable
fun GlossaryScreen(
    modifier: Modifier = Modifier,
    openSlug: String? = null,
    onOpen: (String) -> Unit = {},
    onBack: () -> Unit = {},
) {
    var query by remember { mutableStateOf("") }
    val open = openSlug?.let { slug -> Content.glossary.firstOrNull { it.slug == slug } }

    if (open != null) {
        TermDetail(open, onBack)
        return
    }

    Column(modifier.fillMaxSize().background(Chotki.ground)) {
        TextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("Search terms", color = Chotki.faint) },
            singleLine = true,
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Chotki.panel,
                unfocusedContainerColor = Chotki.panel,
                focusedTextColor = Chotki.parchment,
                unfocusedTextColor = Chotki.parchment,
            ),
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
                .semantics { contentDescription = "Search terms" },
        )

        val matching = matches(query)
        LazyColumn(Modifier.fillMaxSize()) {
            items(matching.size, key = { matching[it].slug }) { index ->
                val entry = matching[index]
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clickable { onOpen(entry.slug) }
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                        .semantics { contentDescription = "Open ${entry.term}" },
                ) {
                    Text(entry.term, color = Chotki.parchment, fontSize = 15.sp)
                    Text(entry.short, color = Chotki.faint, fontSize = 13.sp)
                }
            }
        }
    }
}

/**
 * Ranked the way someone actually searches: the exact word first, then what
 * begins with it, then an alias, then anything that merely mentions it.
 */
internal fun matches(query: String): List<GlossaryEntryJson> {
    val needle = query.trim().lowercase()
    if (needle.isEmpty()) return Content.glossary

    fun rank(entry: GlossaryEntryJson): Int? {
        val term = entry.term.lowercase()
        return when {
            term == needle -> 0
            term.startsWith(needle) -> 1
            entry.aliases.any { it.lowercase().startsWith(needle) } -> 2
            term.contains(needle) -> 3
            entry.aliases.any { it.lowercase().contains(needle) } -> 4
            entry.short.lowercase().contains(needle) -> 5
            entry.full.lowercase().contains(needle) -> 6
            else -> null
        }
    }

    return Content.glossary.mapNotNull { entry -> rank(entry)?.let { entry to it } }
        .sortedWith(compareBy({ it.second }, { it.first.term }))
        .map { it.first }
}

@Composable
private fun TermDetail(entry: GlossaryEntryJson, onBack: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize().background(Chotki.ground)) {
        item {
            Text(
                "‹ All terms",
                color = Chotki.gold,
                fontSize = 14.sp,
                modifier = Modifier
                    .clickable(onClick = onBack)
                    .padding(16.dp)
                    .semantics { contentDescription = "Back to all terms" },
            )
            Column(Modifier.padding(horizontal = 16.dp)) {
                Text(entry.term, color = Chotki.gold, fontSize = 22.sp)
                val pronunciation = entry.pronunciation
                if (pronunciation != null) {
                    Text(pronunciation, color = Chotki.faint, fontSize = 13.sp)
                }
                Spacer(Modifier.size(12.dp))
                Text(entry.full, color = Chotki.parchmentDim, fontSize = 15.sp, lineHeight = 23.sp)
                Spacer(Modifier.size(24.dp))
            }
        }
    }
}
