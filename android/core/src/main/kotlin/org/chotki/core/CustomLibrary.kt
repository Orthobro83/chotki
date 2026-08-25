package org.chotki.core

import org.chotki.core.content.Content

/**
 * The rules someone wrote themselves, kept in the library so they can be taken
 * up again.
 *
 * Not a second kind of template. The rule record *is* the entry: removing a rule
 * closes its activations and archives it, and the record with its whole history
 * stays behind. Taking it up again opens a new activation rather than making a
 * new rule, so a practice kept, set down for a season and taken up again reads as
 * one thing with a gap in it — which is what it is — instead of two unrelated
 * rules with the progress split between them.
 *
 * That is the whole point: nobody should have to write out a rule a second time
 * because they set it down for Lent.
 */
object CustomLibrary {

    /**
     * A rule is one's own when the bundled library has nothing by that name.
     *
     * `Rule.source` cannot answer this. It looks like provenance but it is a
     * free-text note about where a rule came from — "my godfather" — that the
     * person edits themselves. The title is what the library already matches on
     * to show "on your rule", so the two agree by construction.
     */
    fun isOwn(rule: Rule): Boolean =
        Content.ruleLibrary.none { it.title.equals(rule.title, ignoreCase = true) }

    /**
     * What the Custom section offers, newest first.
     *
     * Includes rules currently on the rule, which show as taken rather than
     * being hidden — the section is meant to be the whole catalogue of what
     * someone has written, not only the part they are not doing today.
     */
    fun entries(rules: List<Rule>): List<Rule> =
        rules.filter { isOwn(it) && it.hiddenFromLibrary != true }
            .sortedByDescending { it.createdAt }

    /** A rule set aside: out of the library, everything else untouched. */
    fun settingAside(rule: Rule): Rule = rule.copy(hiddenFromLibrary = true)

    /**
     * A rule taken up again — unarchived, and due from the day it is resumed.
     *
     * The caller opens the activation; this only clears the marks, so the two
     * halves of "take it up again" stay in one place each.
     */
    fun takingUp(rule: Rule): Rule = rule.copy(archivedAt = null, hiddenFromLibrary = null)
}
