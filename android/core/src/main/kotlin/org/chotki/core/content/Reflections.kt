package org.chotki.core.content

import kotlinx.serialization.Serializable

/**
 * The shape of `reflections.json`, generated from the Swift core.
 *
 * The text is the Brotherhood of the Narrow Path's, transcribed once there. A
 * Swift test writes this file and fails if what is committed has drifted, so
 * retyping any of it here would be both redundant and a second chance to get it
 * wrong.
 */
@Serializable
data class ReflectionsJson(
    val days: List<ReflectionDayJson>,
    val closingText: List<String>,
    val addAsRuleLabel: String,
    val libraryNote: String,
    val explainer: List<ReflectionParagraphJson>,
)

@Serializable
data class ReflectionDayJson(
    /** 1 is Sunday, matching [org.chotki.core.Weekday]. */
    val weekday: Int,
    val title: String,
    val notice: String,
    val task: String,
)

@Serializable
data class ReflectionParagraphJson(val spans: List<ReflectionSpanJson>)

@Serializable
data class ReflectionSpanJson(val text: String, val url: String? = null)
