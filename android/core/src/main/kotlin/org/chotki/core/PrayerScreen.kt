package org.chotki.core

import org.chotki.core.content.Content

/**
 * What the prayers screen is showing, and where the count has got to.
 *
 * Held apart from the view because following a word into the glossary — or
 * anything else that rebuilds the screen — would otherwise destroy it. Losing
 * your place in a hundred-knot count because you looked something up would be a
 * poor trade.
 *
 * Immutable, unlike the Swift original's mutating struct: in Compose, state that
 * is replaced rather than mutated is state that reliably recomposes.
 */
data class PrayerScreen(
    /**
     * What is being prayed. Null is the rope on its own, for someone who has the
     * words by heart.
     */
    val selection: String? = "jesus-prayer",
    val count: Int = 0,
    val target: Int = 33,
    /** Null follows the prayer; true or false is the reader's own decision. */
    val ropeOverride: Boolean? = null,
) {
    companion object {
        val targets = listOf(33, 50, 100)

        /**
         * Whether the rope belongs alongside a given selection.
         *
         * Counted prayers bring the rope; rules read through do not. Choosing
         * nothing brings it too.
         *
         * This is what the tradition does, not what anyone must do: the
         * interface lets a person overrule it, because practice varies and the
         * app should not argue.
         */
        fun ropeBelongs(selection: String?): Boolean {
            if (selection.isNullOrEmpty()) return true
            if (Content.prayerSequences.any { it.id == selection }) return false
            val prayer = Content.prayers.firstOrNull { it.id == selection } ?: return true
            return prayer.isForRope
        }
    }

    fun showsRope(): Boolean = ropeOverride ?: ropeBelongs(selection)

    val isComplete: Boolean get() = count >= target

    /**
     * Choosing again returns to following the prayer, so one decision about the
     * rope does not stay stuck to everything chosen afterwards.
     */
    fun choosing(selection: String?): PrayerScreen =
        if (selection == this.selection) this else copy(selection = selection, ropeOverride = null)

    fun showingRope(shown: Boolean): PrayerScreen = copy(ropeOverride = shown)

    /**
     * Advances the count, and says whether that completed the knot — the caller
     * rings the bell, which this layer knows nothing about.
     */
    fun advanced(): Pair<PrayerScreen, Boolean> {
        if (count >= target) return this to false
        val next = copy(count = count + 1)
        return next to next.isComplete
    }

    /**
     * A new target starts the count again: carrying 40 of 50 across to a target
     * of 33 would show a knot already complete without a word said.
     */
    fun aiming(target: Int): PrayerScreen = copy(target = target, count = 0)

    fun startingAgain(): PrayerScreen = copy(count = 0)
}
