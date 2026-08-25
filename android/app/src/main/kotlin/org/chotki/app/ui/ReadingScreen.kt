package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.content.Content

/**
 * A passage from the fathers, one a day.
 *
 * Bundled rather than fetched: there is no reliable free source for patristic
 * texts, and a reading that fails to load is worse than a small set that always
 * works. Everything here is public domain — the Ante-Nicene and Nicene and
 * Post-Nicene Fathers, 1885 to 1900.
 *
 * Chosen by the day rather than at random, so the same passage is there if the
 * app is opened twice.
 */
@Composable
fun ReadingScreen(state: AppState, modifier: Modifier = Modifier) {
    val readings = Content.patristicReadings
    val reading = readings[Math.floorMod(state.today.daysSinceEpoch, readings.size)]

    Column(
        modifier
            .fillMaxSize()
            .background(Chotki.ground)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            "From the fathers",
            color = Chotki.gold,
            fontSize = 13.sp,
            modifier = Modifier.semantics { contentDescription = "The reading" },
        )
        Spacer(Modifier.size(12.dp))
        Text(reading.text, color = Chotki.parchment, fontSize = 17.sp, lineHeight = 27.sp)
        Spacer(Modifier.size(14.dp))
        Text(reading.author, color = Chotki.goldDim, fontSize = 14.sp)
        Text(reading.source, color = Chotki.faint, fontSize = 12.sp)
    }
}
