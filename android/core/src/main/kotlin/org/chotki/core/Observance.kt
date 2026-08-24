package org.chotki.core

/**
 * How much a part of the church calendar participates in this person's rule.
 *
 * Three states rather than a boolean, because "I cannot fast" and "I would
 * rather not see it" are different requests, and neither is the same as keeping
 * the fast.
 *
 * People come to this with real constraints: a health condition that makes
 * fasting unsafe, or no parish within reach so a Liturgy on a great feast is not
 * something they can attend. Neither is a failure, and the app must not be able
 * to represent it as one.
 */
enum class Observance {
    /** Not shown anywhere. The calendar looks like an ordinary calendar. */
    HIDDEN,

    /**
     * Shown on the calendar as information, and nothing more. It never creates a
     * task, never triggers a reminder, and is never scored.
     */
    SHOWN,

    /** Part of the rule: liturgical recurrences fire, and are scored. */
    OBSERVED;

    /** Only [OBSERVED] may drive a rule or reach the score. */
    val drivesRules: Boolean get() = this == OBSERVED
    val isVisible: Boolean get() = this != HIDDEN
}

/**
 * Which parts of the church calendar this person takes part in.
 *
 * Defaults to [Observance.SHOWN] rather than observed: the app starts by telling
 * you what the day is, and taking something on is always a deliberate act. That
 * is the same principle as shipping with no rules enabled.
 */
data class ObservanceSettings(
    val fasting: Observance = Observance.SHOWN,
    val feasts: Observance = Observance.SHOWN,
) {
    companion object {
        val DEFAULT = ObservanceSettings()

        /** A calendar with no church annotation at all. */
        val PLAIN = ObservanceSettings(Observance.HIDDEN, Observance.HIDDEN)

        /** What the interface calls the thing that must be observed. */
        fun name(trigger: LiturgicalTrigger): String = when (trigger) {
            is LiturgicalTrigger.GreatFeast -> "feasts"
            else -> "fasting"
        }
    }

    fun settingFor(trigger: LiturgicalTrigger): Observance = when (trigger) {
        is LiturgicalTrigger.GreatFeast -> feasts
        else -> fasting
    }

    fun observing(trigger: LiturgicalTrigger): ObservanceSettings = when (trigger) {
        is LiturgicalTrigger.GreatFeast -> copy(feasts = Observance.OBSERVED)
        else -> copy(fasting = Observance.OBSERVED)
    }
}
