package org.chotki.core

import kotlinx.serialization.Serializable

/**
 * Which calendar a jurisdiction reckons fixed feasts by.
 *
 * Note what this does *not* affect: days of the week, and the movable cycle.
 * Nearly every Orthodox church computes Pascha on the Julian reckoning, so Great
 * Lent, Pascha and Pentecost fall on the same civil days under both. Only fixed
 * feasts differ, by 13 days — which is why disagreement clusters around the
 * Nativity and Theophany rather than spreading through the year.
 */
@Serializable
enum class Reckoning(val displayName: String, val endpointPath: String) {
    /**
     * Old Calendar. The default, on adherent numbers: roughly 110 million
     * against roughly 47 million.
     */
    JULIAN("Old Calendar (Julian)", "julian"),

    /** New Calendar, also called Revised Julian. orthocal calls it "gregorian". */
    REVISED_JULIAN("New Calendar (Revised Julian)", "gregorian"),
}

/**
 * The practice family a jurisdiction belongs to.
 *
 * Separate from [Reckoning] because the two do not track together: the OCA is
 * Russian in tradition but keeps the New Calendar, and the Georgian Church is
 * Julian but has its own usages. Reckoning decides dates; tradition decides
 * terminology and expectation.
 */
@Serializable
enum class Tradition(val displayName: String) {
    RUSSIAN("Russian"),
    GREEK("Greek"),
    ANTIOCHIAN("Antiochian"),
    ROMANIAN("Romanian"),
    SERBIAN("Serbian"),
    BULGARIAN("Bulgarian"),
    GEORGIAN("Georgian");

    /** Traditions that share Slavic usage and terminology. */
    val isSlavic: Boolean get() = this == RUSSIAN || this == SERBIAN || this == BULGARIAN
}

/**
 * How often confession is customarily made before receiving communion.
 *
 * This is the single practice difference newcomers trip over most, because it is
 * genuinely different between traditions rather than a matter of strictness.
 */
@Serializable
enum class ConfessionNorm(val summary: String) {
    /**
     * Russian and Serbian usage: confession before each communion, usually at
     * the evening service the night before.
     */
    BEFORE_EACH_COMMUNION("Confession is customarily made before each communion."),

    /**
     * Greek and Antiochian usage more commonly: confession regularly, but not
     * tied to each reception.
     */
    PERIODIC("Confession is made regularly, but is not usually tied to each communion."),
}

/**
 * What a jurisdiction customarily expects, so the app can describe practice
 * accurately instead of assuming one tradition's norms are universal.
 *
 * Everything here is **descriptive**. The app reports what is customary and says
 * who to ask; it never tells anyone what they must do. Individual practice is
 * settled with a priest, and every surface built on this must say so.
 */
@Serializable
data class PracticeProfile(
    val confession: ConfessionNorm,
    /** Total abstention from food and drink from midnight before communion. */
    val eucharisticFastFromMidnight: Boolean = true,
    /** Canons and an akathist customarily read the evening before communion. */
    val preparatoryCanons: Boolean = false,
    /** Shown in settings so the described practice is attributable, not asserted. */
    val notes: List<String> = emptyList(),
) {
    companion object {
        /**
         * Read from the shared content rather than written out here.
         *
         * These notes were hand-copied from the Swift core once, and the first
         * change to the wording went into Swift alone — the Android app went on
         * saying the old thing. Content that lives in two places diverges the
         * moment anyone edits it.
         */
        fun customary(tradition: Tradition): PracticeProfile {
            val row = org.chotki.core.content.Content.practiceProfiles
                .first { it.tradition.equals(tradition.name, ignoreCase = true) }
            return PracticeProfile(
                confession = ConfessionNorm.entries
                    .first { it.name.replace("_", "").equals(row.confession, ignoreCase = true) },
                eucharisticFastFromMidnight = row.eucharisticFastFromMidnight,
                preparatoryCanons = row.preparatoryCanons,
                notes = row.notes,
            )
        }
    }
}

/**
 * The church a person belongs to.
 *
 * Carries three things: which calendar it reckons fixed feasts by, which
 * practice family it belongs to, and what that family customarily expects. Every
 * date-aware and practice-aware surface reads through this, so choosing a church
 * is one setting.
 */
@Serializable
data class Jurisdiction(
    val name: String,
    val reckoning: Reckoning,
    val tradition: Tradition,
    /**
     * Defaults to the customary profile for the tradition, and can be adjusted —
     * a parish sometimes differs from its jurisdiction's norm.
     */
    val practice: PracticeProfile,
) {
    companion object {
        fun of(
            name: String,
            reckoning: Reckoning,
            tradition: Tradition,
            practice: PracticeProfile? = null,
        ) = Jurisdiction(name, reckoning, tradition, practice ?: PracticeProfile.customary(tradition))

        val DEFAULT = of(
            "Russian Orthodox Church Outside Russia", Reckoning.JULIAN, Tradition.RUSSIAN,
        )

        /**
         * Offered in settings. Reckoning and practice can still be set directly:
         * a parish sometimes differs from its jurisdiction's norm, so this is a
         * starting point, never an authority.
         */
        /** The churches offered, from the shared content. */
        val KNOWN: List<Jurisdiction> by lazy {
            org.chotki.core.content.Content.jurisdictions.map { row ->
                of(
                    name = row.name,
                    reckoning = Reckoning.entries.first {
                        it.name.replace("_", "").equals(row.reckoning, ignoreCase = true)
                    },
                    tradition = Tradition.entries.first {
                        it.name.equals(row.tradition, ignoreCase = true)
                    },
                )
            }
        }
    }

    /** This jurisdiction as the app ships it, when the name is one it knows. */
    val asShipped: Jurisdiction? get() = KNOWN.firstOrNull { it.name == name }

    /**
     * True when the calendar has been set away from the one this jurisdiction
     * customarily keeps.
     *
     * Not an error and not a warning. Jurisdictions are not uniform: parishes
     * within one sometimes keep a different calendar from the body they belong
     * to, and a convert may be attached to a parish rather than to a
     * jurisdiction's norm. The app records what is actually kept and says
     * plainly that it differs, rather than correcting anyone.
     */
    val reckoningDiffersFromJurisdiction: Boolean
        get() = asShipped?.let { it.reckoning != reckoning } ?: false

    /**
     * True when this jurisdiction's practice has been adjusted away from its
     * tradition's norm.
     */
    val confessionNormDiffersFromTradition: Boolean
        get() = practice.confession != PracticeProfile.customary(tradition).confession
}
