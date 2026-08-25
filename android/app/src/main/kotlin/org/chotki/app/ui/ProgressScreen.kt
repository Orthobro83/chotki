package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
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
import org.chotki.app.AppState
import org.chotki.core.Practice
import kotlin.math.roundToInt

/**
 * What was kept, said in words first.
 *
 * The prose leads and the figure follows, because "evening prayers slipped
 * twice, both Fridays" is something a person can act on and a percentage is not.
 *
 * Progress stops at yesterday. A day still in progress is not a verdict, and a
 * rule taken on this morning and not yet kept must not count against anyone
 * before they have had the chance.
 */
@Composable
fun ProgressScreen(state: AppState, modifier: Modifier = Modifier) {
    val report = state.report()
    val through = Practice.progressThrough(state.today)

    LazyColumn(modifier.fillMaxSize().background(Chotki.ground)) {
        item {
            Column(Modifier.padding(16.dp)) {
                Text(
                    "Your progress up to ${longDate(through)}",
                    color = Chotki.parchment,
                    fontSize = 16.sp,
                    modifier = Modifier.semantics { contentDescription = "Progress heading" },
                )
                Spacer(Modifier.size(12.dp))
                for (line in report.summary) {
                    Text(line, color = Chotki.parchmentDim, fontSize = 15.sp)
                    Spacer(Modifier.size(6.dp))
                }
                val overall = report.overall
                if (overall != null) {
                    Spacer(Modifier.size(8.dp))
                    Text(
                        "${(overall * 100).roundToInt()}% over the last thirty days",
                        color = Chotki.goldDim,
                        fontSize = 14.sp,
                    )
                }
            }
        }

        val scored = report.perRule.filter { it.hasAnythingDue }
        if (scored.isNotEmpty()) {
            item {
                Text(
                    "By rule",
                    color = Chotki.gold,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(start = 16.dp, top = 8.dp, bottom = 4.dp),
                )
            }
            items(scored.size) { index ->
                val score = scored[index]
                Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)) {
                    Text(score.title, color = Chotki.parchment, fontSize = 15.sp)
                    // Never "missed": the wording says what was kept, and the
                    // rest is arithmetic the reader can do if they want it.
                    Text(
                        buildString {
                            append("${score.kept} kept")
                            if (score.keptLate > 0) append(", ${score.keptLate} a little late")
                            if (score.stoodDown > 0) append(", ${score.stoodDown} stood down")
                        },
                        color = Chotki.faint,
                        fontSize = 13.sp,
                    )
                }
            }
        }
    }
}
