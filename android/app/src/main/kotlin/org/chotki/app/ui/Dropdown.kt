package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * A labelled line that opens its choices, rather than showing all of them.
 *
 * The chips are still right for a handful of side-by-side options; this is for
 * the lists long enough to push everything below them off a phone.
 */
@Composable
fun Dropdown(
    label: String,
    chosen: String,
    options: List<String>,
    /** The editor sets its own fields flush; Settings insets everything by 16. */
    inset: Dp = 0.dp,
    onChoose: (Int) -> Unit,
) {
    var open by remember { mutableStateOf(false) }

    // Inset to match the lines around it. Flush to the screen edge it read as
    // a different kind of thing from everything else on the pane.
    Text(
        label,
        color = Chotki.gold,
        fontSize = 13.sp,
        modifier = Modifier.padding(start = inset, end = inset, top = 4.dp),
    )
    Box(Modifier.padding(horizontal = inset)) {
        Row(
            Modifier
                .fillMaxWidth()
                .border(1.dp, Chotki.goldDim, RoundedCornerShape(4.dp))
                .clickable { open = true }
                .padding(horizontal = 12.dp, vertical = 10.dp)
                .semantics { contentDescription = "$label — $chosen" },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(chosen, color = Chotki.parchment, fontSize = 15.sp, modifier = Modifier.weight(1f))
            Text(if (open) "⌃" else "⌄", color = Chotki.goldDim, fontSize = 14.sp)
        }

        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
            modifier = Modifier.background(Chotki.panel),
        ) {
            options.forEachIndexed { index, option ->
                DropdownMenuItem(
                    text = {
                        Text(
                            option,
                            color = if (option == chosen) Chotki.gold else Chotki.parchment,
                            fontSize = 15.sp,
                        )
                    },
                    onClick = { onChoose(index); open = false },
                    modifier = Modifier.semantics { contentDescription = "Choose $option" },
                )
            }
        }
    }
}
