package org.chotki.core.content

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.chotki.core.CalendarDate
import org.chotki.core.FastingSeason
import org.chotki.core.LiturgicalTrigger
import org.chotki.core.Recurrence
import org.chotki.core.RuleCategory
import org.chotki.core.ShortMonthPolicy
import org.chotki.core.TimeOfDay
import org.chotki.core.Tradition
import org.chotki.core.Weekday
import org.chotki.core.scheduling.ReminderLead
import org.chotki.core.scheduling.RuleReminders

/**
 * The bundled content: prayers, glossary, rule library, patristic readings.
 *
 * Generated from the Swift core rather than retyped. Three of the four are
 * liturgical text, where a transcription error is a real error and not a typo,
 * and the Swift files carry the provenance in their comments — Hapgood 1906,
 * ANF and NPNF, which prayers are counted on a rope and why. A Swift test
 * writes these files and fails if what is committed has drifted, so the two
 * platforms cannot say different things.
 *
 * The shape is designed for this purpose. Swift's own encoding of a recurrence
 * is `{"liturgical":{"_0":{"season":{"_0":"greatLent"}}}}` — and worse, that is
 * the shape already written into every existing database, so it could not be
 * changed even if it were pleasant to read.
 */
object Content {

    private val json = Json { ignoreUnknownKeys = true }

    private fun load(name: String): String =
        Content::class.java.getResourceAsStream("/content/$name.json")
            ?.bufferedReader()?.readText()
            ?: error("bundled content missing: $name.json")

    val glossary: List<GlossaryEntryJson> by lazy {
        json.decodeFromString(load("glossary"))
    }
    val prayers: List<PrayerJson> by lazy { json.decodeFromString(load("prayers")) }
    val prayerSequences: List<PrayerSequenceJson> by lazy {
        json.decodeFromString(load("prayer-sequences"))
    }
    val ruleLibrary: List<RuleTemplateJson> by lazy {
        json.decodeFromString(load("rule-library"))
    }
    val patristicReadings: List<PatristicReadingJson> by lazy {
        json.decodeFromString(load("patristic-readings"))
    }
    val prayerSources: List<PrayerSourceJson> by lazy {
        json.decodeFromString(load("prayer-sources"))
    }
}

// MARK: the wire shapes

@Serializable
data class GlossaryEntryJson(
    val slug: String,
    val term: String,
    val aliases: List<String> = emptyList(),
    val pronunciation: String? = null,
    val short: String,
    val full: String,
    val category: String,
    val related: List<String> = emptyList(),
    val traditions: List<String> = emptyList(),
)

@Serializable
data class PrayerJson(
    val id: String,
    val title: String,
    val rubric: String? = null,
    val paragraphs: List<String>,
    val source: String,
    val sourceURL: String? = null,
    val isForRope: Boolean = false,
    val traditions: List<String> = emptyList(),
)

@Serializable
data class PrayerSequenceJson(
    val id: String,
    val title: String,
    val prayerIDs: List<String>,
)

@Serializable
data class PatristicReadingJson(
    val id: String,
    val text: String,
    val author: String,
    val source: String,
)

@Serializable
data class PrayerSourceJson(
    val title: String,
    val organisation: String,
    val url: String,
)

@Serializable
data class RuleTemplateJson(
    val id: String,
    val title: String,
    val summary: String,
    val note: String? = null,
    val recurrence: RecurrenceJson,
    val timeOfDay: String? = null,
    val category: String,
    val reminders: RemindersJson,
    val traditions: List<String> = emptyList(),
    val glossarySlugs: List<String> = emptyList(),
    val prayerIDs: List<String> = emptyList(),
) {
    @Serializable
    data class RemindersJson(val enabled: Boolean = true, val leads: List<String> = emptyList())

    @Serializable
    data class RecurrenceJson(
        val kind: String,
        val date: String? = null,
        val days: List<String> = emptyList(),
        val day: Int? = null,
        val whenShort: String? = null,
        val trigger: String? = null,
        val season: String? = null,
    )
}

// MARK: turning the wire shapes into the model

private fun tradition(name: String): Tradition =
    Tradition.entries.first { it.name.equals(name, ignoreCase = true) }

private fun weekday(name: String): Weekday =
    Weekday.entries.first { it.name.equals(name, ignoreCase = true) }

private fun season(name: String): FastingSeason = when (name) {
    "greatLent" -> FastingSeason.GREAT_LENT
    "nativityFast" -> FastingSeason.NATIVITY_FAST
    "apostlesFast" -> FastingSeason.APOSTLES_FAST
    "dormitionFast" -> FastingSeason.DORMITION_FAST
    else -> error("unknown season: $name")
}

private fun lead(name: String): ReminderLead = when (name) {
    "atTheTime" -> ReminderLead.AT_THE_TIME
    "tenMinutes" -> ReminderLead.TEN_MINUTES
    "thirtyMinutes" -> ReminderLead.THIRTY_MINUTES
    "oneHour" -> ReminderLead.ONE_HOUR
    "twoHours" -> ReminderLead.TWO_HOURS
    "theEveningBefore" -> ReminderLead.THE_EVENING_BEFORE
    else -> error("unknown reminder lead: $name")
}

private fun category(name: String): RuleCategory =
    RuleCategory.entries.first { it.name.equals(name, ignoreCase = true) }

val RuleTemplateJson.RecurrenceJson.model: Recurrence
    get() = when (kind) {
        "daily" -> Recurrence.Daily
        "once" -> Recurrence.Once(
            CalendarDate.parse(date ?: error("once with no date")) ?: error("bad date: $date"),
        )
        "weekly" -> Recurrence.Weekly(days.map(::weekday).toSet())
        "monthly" -> Recurrence.Monthly(
            day ?: error("monthly with no day"),
            if (whenShort == "skip") ShortMonthPolicy.SKIP else ShortMonthPolicy.LAST_DAY,
        )
        "liturgical" -> Recurrence.Liturgical(
            when (trigger) {
                "fastDay" -> LiturgicalTrigger.FastDay
                "greatFeast" -> LiturgicalTrigger.GreatFeast
                "season" -> LiturgicalTrigger.Season(
                    season(season ?: error("season with no season")),
                )
                else -> error("unknown trigger: $trigger")
            },
        )
        else -> error("unknown recurrence: $kind")
    }

val RuleTemplateJson.modelTimeOfDay: TimeOfDay?
    get() = timeOfDay?.split(':')?.let { TimeOfDay.of(it[0].toInt(), it[1].toInt()) }

val RuleTemplateJson.modelCategory: RuleCategory get() = category(category)

val RuleTemplateJson.modelReminders: RuleReminders
    get() = RuleReminders(reminders.enabled, reminders.leads.map(::lead))

val RuleTemplateJson.modelTraditions: Set<Tradition> get() = traditions.map(::tradition).toSet()

val PrayerJson.modelTraditions: Set<Tradition> get() = traditions.map(::tradition).toSet()

val GlossaryEntryJson.modelTraditions: Set<Tradition> get() = traditions.map(::tradition).toSet()
