package org.chotki.core.content

import kotlinx.serialization.Serializable

/**
 * A run of text, sometimes a link.
 *
 * Held as spans rather than as one string with markup because the interface has
 * to build a real, tappable link out of it, and nothing should be parsing
 * anything to work out where the links are.
 */
@Serializable
data class WelcomeSpanJson(val text: String, val url: String? = null)

@Serializable
data class WelcomeParagraphJson(
    val spans: List<WelcomeSpanJson>,
    /** Set apart from the rest — quieter, and indented behind a rule. */
    val isAside: Boolean = false,
)

@Serializable
data class WelcomeJson(
    val title: String,
    val beginLabel: String,
    val paragraphs: List<WelcomeParagraphJson>,
)

/**
 * Ryan's words, from the shared content, so this and the macOS screen cannot
 * drift apart — which is what happened to several other things in this app.
 */
object Welcome {
    val title: String get() = Content.welcome.title
    val beginLabel: String get() = Content.welcome.beginLabel
    val paragraphs: List<WelcomeParagraphJson> get() = Content.welcome.paragraphs
}
