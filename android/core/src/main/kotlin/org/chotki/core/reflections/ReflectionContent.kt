package org.chotki.core.reflections

import org.chotki.core.Weekday
import org.chotki.core.content.Content

/**
 * The seven reflections, from the Brotherhood of the Narrow Path.
 *
 * **Loaded from generated JSON, not retyped.** The text is someone else's,
 * transcribed once into the Swift core, and a second transcription here would
 * be a second chance to get it wrong. A Swift test writes
 * `resources/content/reflections.json` and fails if what is committed has
 * drifted, so the three platforms cannot say different things.
 *
 * Sunday is the first, running through to Saturday. Saturday's directs the
 * reader to liturgy and confession; its notice is longer than the rest and that
 * is expected.
 *
 * These are seeded on installation and are editable afterwards. Seeding them is
 * not the same as enabling anything: the seven *questions* are the section's
 * content, while the *rule* that answers them stays opt-in from the library,
 * because nothing in this app is enabled by default.
 */
val Reflection.Companion.bundled: List<Reflection>
    get() = bundledCache

private val bundledCache: List<Reflection> by lazy {
    Content.reflections.days
        .map {
            Reflection(
                weekday = Weekday.of(it.weekday),
                question = ReflectionQuestion(it.title, it.notice, it.task),
            )
        }
        .sortedBy { it.weekday.number }
}

/**
 * The bundled wording for one weekday.
 *
 * Total by construction: the seven cover every weekday and [Weekday] has no
 * eighth case. The error guards against someone shortening the list rather than
 * against a bad argument.
 */
fun Reflection.Companion.bundled(weekday: Weekday): Reflection =
    bundled.firstOrNull { it.weekday == weekday }
        ?: error("no bundled reflection for $weekday — the seven are incomplete")

/**
 * What closes the week, shown at the foot of the section.
 *
 * Verbatim, and **not to be reworded**. This is the one piece of fixed copy in
 * the app that tells the reader to do something; it is kept because it names
 * who to ask — a priest, confession — which is what the app is meant to do
 * instead of instructing, and because it is quoted material rather than the
 * app's own voice.
 */
val Reflection.Companion.closingText: List<String>
    get() = Content.reflections.closingText

/** What the section is for, behind the help mark beside its title. Ryan's words. */
val Reflection.Companion.explainer: List<ReflectionParagraph>
    get() = Content.reflections.explainer.map { paragraph ->
        ReflectionParagraph(paragraph.spans.map { ReflectionSpan(it.text, it.url) })
    }

/**
 * The button that puts the rule on, named once so the explainer and the control
 * it names cannot drift apart.
 */
val Reflection.Companion.addAsRuleLabel: String
    get() = Content.reflections.addAsRuleLabel

/** What the library says about it. Short: the long version is one tap away. */
val Reflection.Companion.libraryNote: String
    get() = Content.reflections.libraryNote

/** A run of text, with a link if it carries one. */
data class ReflectionSpan(val text: String, val url: String? = null)

data class ReflectionParagraph(val spans: List<ReflectionSpan>)
