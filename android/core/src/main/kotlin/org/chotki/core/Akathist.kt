package org.chotki.core

import org.chotki.core.content.Content

/**
 * Which Friday of Great Lent carries the Akathist, and how much of it.
 *
 * Greek and Antiochian practice reads one stasis on each of the first four
 * Fridays, and the whole hymn on the fifth. Russian, Serbian and Bulgarian
 * practice reads the whole hymn on the fifth Friday only. Romanian and
 * Georgian practice is not the one given here; those churches are shown the
 * Orthodox Church in America's appointment, the same fifth Friday.
 * The Fridays follow Pascha, so the old calendar and the new share them.
 *
 * 1..4 is that stasis. 5 is the whole hymn. Null when it is not appointed.
 * The wording is the 1919 English exported from the Swift core.
 */
object Akathist {
    /** Clean Monday is −48. These are the Fridays of weeks 1 through 5. */
    val lentFridays = listOf(-44, -37, -30, -23, -16)

    /** True when this tradition's own appointment is the one given here. */
    fun hasOwnAppointment(tradition: Tradition): Boolean = when (tradition) {
        Tradition.GREEK, Tradition.ANTIOCHIAN, Tradition.RUSSIAN,
        Tradition.SERBIAN, Tradition.BULGARIAN -> true
        Tradition.ROMANIAN, Tradition.GEORGIAN -> false
    }

    fun week(paschaDistance: Int, tradition: Tradition): Int? {
        val index = lentFridays.indexOf(paschaDistance)
        if (index < 0) return null
        val week = index + 1
        val practice = if (hasOwnAppointment(tradition)) tradition else Tradition.RUSSIAN
        val salutations = practice == Tradition.GREEK || practice == Tradition.ANTIOCHIAN
        if (week < 5 && !salutations) return null
        return week
    }

    /**
     * Said once the section is opened, and only when the OCA's appointment is
     * standing in for a church whose own is not given here.
     */
    fun fallbackNote(tradition: Tradition): String? = when (tradition) {
        Tradition.ROMANIAN -> fallbackNote("Romanian Orthodox Church")
        Tradition.GEORGIAN -> fallbackNote("Georgian Orthodox Church")
        Tradition.GREEK, Tradition.ANTIOCHIAN, Tradition.RUSSIAN,
        Tradition.SERBIAN, Tradition.BULGARIAN -> null
    }

    private fun fallbackNote(church: String): String =
        "The $church's own appointment is not the one given here. This is how the Orthodox Church in America keeps it: the whole hymn, on Friday of the fifth week of Great Lent."

    fun heading(week: Int): String = when (week) {
        1 -> "The first part, appointed for this Friday."
        2 -> "The second part, appointed for this Friday."
        3 -> "The third part, appointed for this Friday."
        4 -> "The fourth part, appointed for this Friday."
        else -> "The whole hymn, appointed for this Friday."
    }

    /** The kontakion frames the part. On the fifth Friday the first stanza is read again. */
    fun paragraphs(week: Int): List<String> {
        val text = Content.appointed.akathist
        val body = when (week) {
            5 -> text.stanzas
            in 1..4 -> text.stanzas.subList((week - 1) * 6, week * 6)
            else -> return emptyList()
        }
        return if (week == 5) {
            listOf(text.kontakion) + body + listOf(text.again, text.stanzas.first(), text.kontakion)
        } else {
            listOf(text.kontakion) + body + listOf(text.kontakion)
        }
    }
}
