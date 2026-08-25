package org.chotki.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.Text
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import org.chotki.core.content.Glossary
import org.chotki.core.content.TermMatch

/**
 * Running text with glossary terms made tappable.
 *
 * A newcomer meets a dozen unfamiliar words in the first sentence of a
 * commemoration. Making them tappable where they appear means the explanation
 * is one tap from the word rather than a search away — and the reader is never
 * sent somewhere to look something up.
 *
 * Deliberately for short text only: commemorations, fasting descriptions,
 * titles, prayers. Scanning a whole scripture passage would turn it into a
 * field of links and make it harder to read, not easier.
 */
@Composable
fun TermText(
    text: String,
    glossary: Glossary,
    modifier: Modifier = Modifier,
    colour: Color = Chotki.parchment,
    size: TextUnit = 14.sp,
    italic: Boolean = false,
    /** Pre-scanned, when a run of prayers should link each term only once. */
    matches: List<TermMatch>? = null,
    onOpenTerm: (String) -> Unit,
) {
    val found = matches ?: glossary.scan(text)

    Text(
        text = linked(text, found, onOpenTerm),
        style = TextStyle(
            color = colour,
            fontSize = size,
            fontStyle = if (italic) FontStyle.Italic else FontStyle.Normal,
        ),
        modifier = modifier,
    )
}

/**
 * Underlined rather than coloured.
 *
 * Gold is the app's colour for something chosen or something due; spending it
 * on every unfamiliar noun in a commemoration would drown that out. A quiet
 * underline says "there is more here" without competing.
 *
 * Built with [LinkAnnotation], not `ClickableText`. That is deprecated, and
 * inside a LazyColumn it drew the underline and swallowed the tap — the exact
 * failure this project keeps meeting, a control that looks right and does
 * nothing.
 */
internal fun linked(
    text: String,
    matches: List<TermMatch>,
    onOpenTerm: (String) -> Unit,
): AnnotatedString = buildAnnotatedString {
    val style = SpanStyle(textDecoration = TextDecoration.Underline, color = Chotki.goldDim)
    var at = 0
    for (match in matches.sortedBy { it.range.first }) {
        if (match.range.first < at) continue
        append(text.substring(at, match.range.first))
        withLink(
            LinkAnnotation.Clickable(
                tag = match.slug,
                styles = TextLinkStyles(style = style),
                linkInteractionListener = { onOpenTerm(match.slug) },
            ),
        ) {
            append(text.substring(match.range.first, match.range.last + 1))
        }
        at = match.range.last + 1
    }
    if (at < text.length) append(text.substring(at))
}
