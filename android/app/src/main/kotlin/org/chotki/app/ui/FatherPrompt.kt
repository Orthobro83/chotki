package org.chotki.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState

/**
 * Asked on opening, thirty days after the welcome, and again thirty days after
 * "Not yet". Once a name is stored it is not asked again. The name itself is
 * changed later in Settings.
 */
@Composable
fun FatherPrompt(state: AppState) {
    var naming by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }

    Column(
        Modifier
            .fillMaxSize()
            .background(Chotki.ground.copy(alpha = 0.94f))
            .padding(horizontal = 28.dp)
            .semantics { contentDescription = "Spiritual father" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
    ) {
        Text(
            "Chotki is best used in cooperation with a priest or spiritual father. Have you found one yet?",
            color = Chotki.parchment,
            fontFamily = FontFamily.Serif,
            fontSize = 20.sp,
            lineHeight = 28.sp,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.size(22.dp))
        if (!naming) {
            Row(horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(10.dp)) {
                PromptButton("Yes I have") { naming = true }
                PromptButton("Not yet") {
                    state.updateSettings { it.copy(spiritualFatherDeferredOn = state.today) }
                }
            }
        } else {
            TextField(
                value = name,
                onValueChange = { name = it },
                placeholder = { Text("Name", color = Chotki.faint) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Chotki.panel,
                    unfocusedContainerColor = Chotki.panel,
                    focusedTextColor = Chotki.parchment,
                    unfocusedTextColor = Chotki.parchment,
                    cursorColor = Chotki.gold,
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentDescription = "Spiritual father's name" },
            )
            Spacer(Modifier.size(14.dp))
            PromptButton("Save") {
                val trimmed = name.trim()
                if (trimmed.isEmpty()) return@PromptButton
                state.updateSettings { it.copy(spiritualFatherName = trimmed) }
            }
        }
    }
}

@Composable
private fun PromptButton(label: String, onTap: () -> Unit) {
    Text(
        label,
        color = Chotki.ground,
        fontSize = 15.sp,
        modifier = Modifier
            .background(Chotki.gold, RoundedCornerShape(12.dp))
            .clickable(onClick = onTap)
            .padding(horizontal = 18.dp, vertical = 12.dp)
            .semantics { contentDescription = label },
    )
}
