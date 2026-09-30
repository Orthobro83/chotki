package org.chotki.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.core.content.Glossary
import org.chotki.core.content.GlossaryEntryJson

/**
 * The terms, in alphabetical order, narrowed by what has been typed so far.
 *
 * A tap opens the explanation under the term. The same tap again closes it.
 * Arriving from a word in a prayer or a reading opens that term already.
 */
@Composable
fun GlossaryScreen(
    modifier: Modifier = Modifier,
    openSlug: String? = null,
    /** Scoped to the reader's tradition, as macOS has always done. */
    glossary: Glossary = Glossary.SHARED,
) {
    var query by remember { mutableStateOf("") }
    var expanded by remember(openSlug) { mutableStateOf(setOfNotNull(openSlug)) }
    val shown = if (query.isBlank()) glossary.entries else matches(query, glossary)
    val list = rememberLazyListState()
    LaunchedEffect(openSlug) {
        val index = shown.indexOfFirst { it.slug == openSlug }
        if (index >= 0) list.scrollToItem(index)
    }

    Column(modifier.fillMaxSize()) {
        TextField(
            value = query,
            onValueChange = { query = it },
            placeholder = {
                Text("Search terms", color = Chotki.faint, fontFamily = Chotki.reading, fontSize = 17.sp)
            },
            textStyle = TextStyle(
                color = Chotki.parchment,
                fontFamily = Chotki.reading,
                fontSize = 17.sp,
            ),
            singleLine = true,
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Chotki.panel,
                unfocusedContainerColor = Chotki.panel,
                focusedTextColor = Chotki.parchment,
                unfocusedTextColor = Chotki.parchment,
                cursorColor = Chotki.gold,
                focusedIndicatorColor = Chotki.goldDim,
                unfocusedIndicatorColor = Chotki.line,
            ),
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
                .semantics { contentDescription = "Search terms" },
        )

        LazyColumn(Modifier.fillMaxSize(), state = list) {
            items(shown, key = { it.slug }) { entry ->
                val open = entry.slug in expanded
                TermRow(entry, open) {
                    expanded = if (open) expanded - entry.slug else expanded + entry.slug
                }
            }
        }
    }
}

/**
 * Terms whose own name, or another name they go by, begins with what was typed.
 *
 * "theo" finds Theotokos. "okos" does not: the match is the leading characters,
 * not a word buried in the middle or in the explanation.
 */
internal fun matches(
    query: String,
    glossary: Glossary = Glossary.SHARED,
): List<GlossaryEntryJson> {
    val needle = query.trim().lowercase()
    if (needle.isEmpty()) return glossary.entries
    return glossary.entries.filter { entry ->
        entry.term.lowercase().startsWith(needle) ||
            entry.aliases.any { it.lowercase().startsWith(needle) }
    }
}

/** Smaller than the prayers, serif, and set to the left. */
@Composable
fun GlossaryOfTerms(onOpen: () -> Unit, modifier: Modifier = Modifier) {
    Text(
        "Glossary of terms",
        color = Chotki.gold,
        fontFamily = Chotki.reading,
        fontSize = 10.2.sp,
        textAlign = TextAlign.Start,
        modifier = modifier
            .fillMaxWidth()
            .clickable(onClick = onOpen)
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .semantics { contentDescription = "Glossary of terms" },
    )
}

@Composable
private fun TermRow(entry: GlossaryEntryJson, open: Boolean, onTap: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .semantics { contentDescription = entry.term },
    ) {
        Text(
            entry.term,
            color = Chotki.parchment,
            fontFamily = Chotki.reading,
            fontSize = 17.sp,
            lineHeight = 17.sp * 1.45f,
        )
        if (open) {
            val pronunciation = entry.pronunciation
            if (pronunciation != null) {
                Text(
                    pronunciation,
                    color = Chotki.faint,
                    fontFamily = Chotki.reading,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            Spacer(Modifier.size(6.dp))
            Text(
                entry.full,
                color = Chotki.parchment,
                fontFamily = Chotki.reading,
                fontSize = 17.sp,
                lineHeight = 17.sp * 1.45f,
            )
        }
    }
}
