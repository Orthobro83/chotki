package org.chotki.core.content

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class VerseJson(
    /** A string because Brenton splits a few — "4a", "4b". */
    val number: String,
    val text: String,
)

@Serializable
data class PsalmJson(
    val number: Int,
    /**
     * The title, where the psalm has one. Counted as verse 1 in the Septuagint,
     * which is why those psalms begin their body at verse 2.
     */
    val superscription: String? = null,
    val verses: List<VerseJson>,
)

@Serializable
data class PsalterJson(
    val source: String,
    @SerialName("sourceURL") val sourceUrl: String,
    val numbering: String,
    val psalms: List<PsalmJson>,
)

/**
 * The Psalter the app carries.
 *
 * Brenton's Septuagint of 1851, in the public domain, taken from the proofread
 * machine-readable text at eBible.org rather than from a scan — an OCR error in
 * a psalm is an error in a psalm, not a typo. Nothing was retyped.
 */
object Psalter {

    val all: List<PsalmJson> get() = Content.psalter.psalms
    val source: String get() = Content.psalter.source
    val sourceUrl: String get() = Content.psalter.sourceUrl

    fun psalm(number: Int): PsalmJson? = all.firstOrNull { it.number == number }

    /** The psalms of a kathisma, in order. */
    fun kathisma(number: Int): List<PsalmJson> =
        Kathisma.psalms(number)?.mapNotNull(::psalm) ?: emptyList()
}
