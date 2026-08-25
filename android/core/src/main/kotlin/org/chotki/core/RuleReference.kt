package org.chotki.core

/**
 * What text, if any, a rule points at.
 *
 * The point of a rule is the thing itself, and a rule that names a text the app
 * is holding should be one tap from it. Deciding that in core rather than in
 * each interface is what stops the two platforms disagreeing — the reading
 * rules had no way through on either, for the same reason, and were noticed on
 * one.
 *
 * [NONE] is a real answer and not a failure. A rule whose text the app does not
 * hold offers no link, because a link to nothing is worse than none.
 */
enum class RuleReference {
    /** The prayers the rule carries, in order. */
    PRAYERS,

    /** The day's appointed readings and its commemoration. */
    READING,

    /** The kathismata appointed for the day, and the psalms in them. */
    PSALTER,

    NONE,
}

/**
 * How a rule of one's own is recognised as the Psalter rule.
 *
 * Matched on the title because a rule taken from the library carries no link
 * back to its template — that is deliberate, so the rule is the person's own
 * and stays theirs when the library changes underneath it.
 */
const val PSALTER_RULE_TITLE = "A kathisma of the Psalter"

val Rule.reference: RuleReference
    get() = when {
        hasPrayers -> RuleReference.PRAYERS
        // The day's Gospel, the day's Epistle, the life of the day's saint —
        // all three are what the Reading screen already shows.
        category == RuleCategory.READING -> RuleReference.READING
        title == PSALTER_RULE_TITLE -> RuleReference.PSALTER
        else -> RuleReference.NONE
    }
