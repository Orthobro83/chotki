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
    /** The rope, already counting the prayer this rule carries. */
    ROPE,

    /** The prayers the rule carries, in order. */
    PRAYERS,

    /** The day's appointed readings and its commemoration. */
    READING,

    /** The kathismata appointed for the day, and the psalms in them. */
    PSALTER,

    /** The Reflections section, and today's question in it. */
    REFLECTIONS,

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

/**
 * How a rule of one's own is recognised as the Reflections rule.
 *
 * Same reasoning as the Psalter's, and the same consequence: rename it and it
 * becomes an ordinary rule with no way through to the section. That is right.
 * It is theirs at that point, not ours.
 */
const val REFLECTION_RULE_TITLE = "Reflection"

/**
 * The prayer the rope should already be counting when this rule is opened.
 *
 * A rule whose whole text is a single counted prayer is not read through: it is
 * said over and over. Sending it to the prayer screen hands the reader one
 * short paragraph and nowhere to keep the count, which is the opposite of what
 * they opened it for. Null for every other rule, and that is what decides
 * [RuleReference.ROPE] below.
 */
val Rule.ropePrayerId: String?
    get() {
        val ids = prayerIDs ?: return null
        if (ids.size != 1) return null
        val prayer = org.chotki.core.content.Content.prayers.firstOrNull { it.id == ids[0] }
        return if (prayer != null && prayer.isForRope) prayer.id else null
    }

val Rule.reference: RuleReference
    get() = when {
        ropePrayerId != null -> RuleReference.ROPE
        hasPrayers -> RuleReference.PRAYERS
        // The day's Gospel, the day's Epistle, the life of the day's saint —
        // all three are what the Reading screen already shows.
        category == RuleCategory.READING -> RuleReference.READING
        title == PSALTER_RULE_TITLE -> RuleReference.PSALTER
        title == REFLECTION_RULE_TITLE -> RuleReference.REFLECTIONS
        else -> RuleReference.NONE
    }

/**
 * The glossary entry that explains what this rule is.
 *
 * Two ways of finding it, in order of trust. A rule taken from the library
 * keeps its template's title, and the template says outright which entry is
 * about it, so that answer is used wherever it can be had. Failing that the
 * title is scanned the way prayer text is scanned, which is what rescues the
 * renamed ones: "The Jesus Prayer, 33 repetitions" is not a template title any
 * more, but it still contains one.
 *
 * Null is a real answer. A rule someone wrote themselves is theirs, and the
 * app has nothing to say about what "Cold plunge" means.
 */
val Rule.glossarySlug: String?
    get() {
        val curated = org.chotki.core.content.Content.ruleLibrary
            .firstOrNull { it.title.equals(title, ignoreCase = true) }
            ?.glossarySlugs
            ?.firstOrNull()
        if (curated != null) return curated
        return org.chotki.core.content.Glossary.SHARED.scan(title).firstOrNull()?.slug
    }
