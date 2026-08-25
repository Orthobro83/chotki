package org.chotki.app

import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.click
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.text.LinkAnnotation
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.chotki.app.ui.ChotkiTheme
import org.chotki.app.ui.TermText
import org.chotki.app.ui.linked
import org.chotki.core.content.Glossary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * A linked term has to open.
 *
 * The first version drew the underline and swallowed the tap — ClickableText,
 * deprecated, inside a LazyColumn. It looked completely correct in a
 * screenshot, which is the failure this project keeps meeting.
 */
@RunWith(AndroidJUnit4::class)
class TermLinkTest {

    @get:Rule val compose = createComposeRule()

    private val glossary = Glossary.SHARED

    @Test fun aTermCarriesARealLinkAndNotJustAnUnderline() {
        val text = "A hymn to the Theotokos."
        val annotated = linked(text, glossary.scan(text)) {}

        val links = annotated.getLinkAnnotations(0, text.length)
        assertTrue("no link was built at all", links.isNotEmpty())

        val clickable = links.map { it.item }.filterIsInstance<LinkAnnotation.Clickable>()
        assertTrue("the link is not clickable", clickable.isNotEmpty())
        assertEquals("theotokos", clickable.first().tag)
    }

    @Test fun tappingATermReportsIt() {
        var opened: String? = null
        val text = "A hymn to the Theotokos."

        compose.setContent {
            ChotkiTheme {
                // Not fillMaxSize: that makes the node the whole screen, and
                // the middle of the screen is nowhere near the one line of text.
                TermText(
                    text = text,
                    glossary = glossary,
                    modifier = Modifier.wrapContentSize(),
                    onOpenTerm = { opened = it },
                )
            }
        }

        // The word sits at the end, so the right-hand side of the line is on it.
        compose.onNodeWithText(text).performTouchInput {
            click(androidx.compose.ui.geometry.Offset(width * 0.72f, height * 0.5f))
        }
        compose.waitForIdle()

        assertEquals("theotokos", opened)
    }
}
