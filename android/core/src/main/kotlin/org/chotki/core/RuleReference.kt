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

    NONE,
}

val Rule.reference: RuleReference
    get() = when {
        hasPrayers -> RuleReference.PRAYERS
        // The day's Gospel, the day's Epistle, the life of the day's saint —
        // all three are what the Reading screen already shows.
        category == RuleCategory.READING -> RuleReference.READING
        else -> RuleReference.NONE
    }
