package org.chotki.app.ui

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.ui.res.painterResource
import org.chotki.app.R
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import org.chotki.app.AppState
import org.chotki.core.content.Welcome
import org.chotki.core.content.WelcomeParagraphJson

/**
 * First run, once and never again.
 *
 * Android had no first-run screen at all — `hasCompletedFirstRun` has been in
 * the shared settings the whole time and nothing here read it. The words come
 * from core, so this and the macOS screen say the same thing.
 *
 * It scrolls. The text runs to about two phone screens and shrinking it to fit
 * would make a wall nobody reads.
 */
@Composable
fun WelcomeScreen(state: AppState, modifier: Modifier = Modifier) {
    var name by remember { mutableStateOf(state.settings.displayName) }
    // The whole stack sits in the middle. When the text is taller than the
    // phone it still scrolls, rather than pinning Continue to the bottom.
    BoxWithConstraints(
        modifier
            .fillMaxSize()
            .background(Chotki.ground)
            .safeDrawingPadding(),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .heightIn(min = maxHeight)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
        ) {
            Text(
                Welcome.title,
                color = Chotki.parchment,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Medium,
                fontSize = 26.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentDescription = "The welcome" },
            )
            Spacer(Modifier.size(16.dp))

            for (paragraph in Welcome.paragraphs) {
                Paragraph(paragraph)
                Spacer(Modifier.size(14.dp))
            }

            Text(
                "What should we call you?",
                color = Chotki.parchment,
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Medium,
                fontSize = 26.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
            )
            TextField(
                value = name,
                onValueChange = { name = it },
                placeholder = { Text("First name or Baptismal name.", color = Chotki.faint) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
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
                    .padding(top = 12.dp)
                    .semantics { contentDescription = "What should we call you?" },
            )
            Spacer(Modifier.size(18.dp))
            Text(
                Welcome.beginLabel,
                color = Chotki.ground,
                fontSize = 16.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Chotki.gold, RoundedCornerShape(14.dp))
                    .clickable {
                        val trimmed = name.trim()
                        state.updateSettings {
                            it.copy(
                                hasCompletedFirstRun = true,
                                displayName = trimmed,
                                firstRunOn = it.firstRunOn ?: state.today,
                            )
                        }
                    }
                    .padding(vertical = 14.dp)
                    .semantics { contentDescription = Welcome.beginLabel },
            )
        }
    }
}

@Composable
private fun Paragraph(paragraph: WelcomeParagraphJson) {
    val context = LocalContext.current

    val text = buildAnnotatedString {
        for (span in paragraph.spans) {
            val url = span.url
            if (url == null) {
                append(span.text)
            } else {
                // A real link rather than a coloured word: the two of them are
                // the only places Chotki sends anyone else's way.
                withLink(
                    LinkAnnotation.Url(
                        url,
                        TextLinkStyles(
                            SpanStyle(
                                color = Chotki.gold,
                                textDecoration = TextDecoration.Underline,
                            ),
                        ),
                    ) {
                        val target = (it as LinkAnnotation.Url).url
                        runCatching {
                            context.startActivity(
                                Intent(Intent.ACTION_VIEW, target.toUri())
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        }
                    },
                ) { append(span.text) }
            }
        }
    }

    Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
        if (paragraph.isAside) {
            // Full height of the paragraph beside it, which needs the row to
            // measure its children first — without that it drew as nothing.
            Box(Modifier.width(2.dp).fillMaxHeight().background(Chotki.line))
            Spacer(Modifier.size(11.dp))
        }
        Text(
            text,
            color = if (paragraph.isAside) Chotki.faint else Chotki.parchment,
            fontSize = if (paragraph.isAside) 13.sp else 14.5.sp,
            lineHeight = if (paragraph.isAside) 19.sp else 22.sp,
            fontStyle = if (paragraph.isAside) FontStyle.Italic else FontStyle.Normal,
        )
    }
}
