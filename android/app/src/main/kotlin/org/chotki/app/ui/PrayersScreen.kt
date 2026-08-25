package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
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
import org.chotki.core.content.PrayerJson

/**
 * The prayers themselves, which is the point of the rule.
 *
 * Every prayer carries where its wording came from, in fine print beneath it.
 * All of it is public domain by construction — Hapgood's *Service Book* of 1906,
 * scripture, or common usage — because modern prayer books remain in copyright
 * however freely they can be read.
 */
@Composable
fun PrayersScreen(modifier: Modifier = Modifier) {
    var openID by remember { mutableStateOf<String?>(null) }
    val open = openID?.let { id -> Content.prayers.firstOrNull { it.id == id } }

    if (open != null) {
        PrayerText(open) { openID = null }
    } else {
        PrayerList(modifier) { openID = it }
    }
}

@Composable
private fun PrayerList(modifier: Modifier, onOpen: (String) -> Unit) {
    LazyColumn(modifier.fillMaxSize().background(Chotki.ground)) {
        item {
            Text(
                "Rules",
                color = Chotki.gold,
                fontSize = 13.sp,
                modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 4.dp),
            )
        }
        items(Content.prayerSequences.size) { index ->
            val sequence = Content.prayerSequences[index]
            Text(
                sequence.title,
                color = Chotki.parchment,
                fontSize = 15.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onOpen(sequence.prayerIDs.first()) }
                    .padding(horizontal = 16.dp, vertical = 10.dp)
                    .semantics { contentDescription = "Open ${sequence.title}" },
            )
        }
        item {
            Text(
                "Prayers",
                color = Chotki.gold,
                fontSize = 13.sp,
                modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 4.dp),
            )
        }
        items(Content.prayers.size) { index ->
            val prayer = Content.prayers[index]
            Text(
                prayer.title,
                color = Chotki.parchment,
                fontSize = 15.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onOpen(prayer.id) }
                    .padding(horizontal = 16.dp, vertical = 10.dp)
                    .semantics { contentDescription = "Open ${prayer.title}" },
            )
        }
    }
}

@Composable
private fun PrayerText(prayer: PrayerJson, onBack: () -> Unit) {
    LazyColumn(Modifier.fillMaxSize().background(Chotki.ground)) {
        item {
            Text(
                "‹ All prayers",
                color = Chotki.gold,
                fontSize = 14.sp,
                modifier = Modifier
                    .clickable(onClick = onBack)
                    .padding(16.dp)
                    .semantics { contentDescription = "Back to the prayers" },
            )
            Column(Modifier.padding(horizontal = 16.dp)) {
                Text(prayer.title, color = Chotki.gold, fontSize = 14.sp)
                val rubric = prayer.rubric
                if (rubric != null) {
                    Text(rubric, color = Chotki.faint, fontSize = 13.sp)
                }
                Spacer(Modifier.size(10.dp))
                for (paragraph in prayer.paragraphs) {
                    Text(paragraph, color = Chotki.parchment, fontSize = 17.sp, lineHeight = 26.sp)
                    Spacer(Modifier.size(10.dp))
                }
                // Fine print, and never omitted: the wording is somebody's work
                // and the reader is entitled to know whose.
                Text("Source · ${prayer.source}", color = Chotki.faint, fontSize = 11.sp)
                Spacer(Modifier.size(24.dp))
            }
        }
    }
}
