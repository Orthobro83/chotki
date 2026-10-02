package org.chotki.app.ui

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.chotki.core.CalendarDate
import kotlin.math.max
import kotlin.math.min

/**
 * The day's picture, and where it comes to rest.
 *
 * The same library and the same motion as the Mac card. A picture is chosen
 * from the civil day, scaled a little larger than the pane, and eased onto
 * the hand-chosen subject — a face, a dome, a cross — then held. Coordinates
 * are fractions of the picture, so the crop survives a different pane.
 *
 * Travel is in the same units as the pane. On the Mac those units are points;
 * pass density-scaled pixels here so the drift stays the same size.
 */
internal data class PanPoint(val x: Float, val y: Float)

internal data class PanSize(val width: Float, val height: Float)

/** Matches `DriftingArtwork.duration`: 2 × 36s, 15% faster, then twice that speed. */
internal const val SAYING_PAN_DURATION_MS: Double = 2.0 * 36.0 / 1.15 / 2.0 * 1000.0

/**
 * One start per picture per day. Leaving the screen, or opening the app again,
 * continues that drift instead of playing it from the beginning.
 */
internal interface PanStartStore {
    fun read(identity: String): Long?
    fun write(identity: String, startedAt: Long)
}

internal class SayingPanTimeline {
    private val sessionStarts = HashMap<String, Long>()

    fun start(dateIso: String, name: String, persist: Boolean, now: Long, store: PanStartStore): Long {
        // pan3 draws the picture at cover size. A day already settled on pan2 plays once more.
        val identity = "pan3-$dateIso-$name"
        sessionStarts[identity]?.let { return it }
        if (persist) {
            store.read(identity)?.let { stored ->
                sessionStarts[identity] = stored
                return stored
            }
        }
        sessionStarts[identity] = now
        if (persist) store.write(identity, now)
        return now
    }
}

/** Process-wide, as on the Mac: another screen in the same launch must not restart the drift. */
internal val sharedSayingPanTimeline = SayingPanTimeline()

internal fun sayingNames(order: String): List<String> =
    order.lineSequence().map { it.trim() }.filter { it.isNotEmpty() }.toList()

internal fun sayingName(names: List<String>, date: CalendarDate): String? {
    if (names.isEmpty()) return null
    val first = CalendarDate.of(date.year, 1, 1) ?: return null
    return names[Math.floorMod(first.daysUntil(date) + 1, names.size)]
}

internal fun imageNumber(name: String): Int =
    name.substringAfterLast('/').substringBeforeLast('.').toIntOrNull() ?: 0

internal fun approvedSayingFocus(json: String): Map<Int, PanPoint> {
    return Json.parseToJsonElement(json).jsonArray.associate { element ->
        val obj = element.jsonObject
        obj.getValue("number").jsonPrimitive.int to PanPoint(
            obj.getValue("focusX").jsonPrimitive.double.toFloat(),
            obj.getValue("focusY").jsonPrimitive.double.toFloat(),
        )
    }
}

internal fun sayingFocus(name: String, approved: Map<Int, PanPoint>): PanPoint {
    val number = imageNumber(name)
    return curatedSayingFocus[number] ?: approved[number] ?: PanPoint(0.5f, 0.45f)
}

/** Eight percent larger than the pane, on whichever side the picture would otherwise leave empty. */
internal fun renderedSize(image: PanSize, viewport: PanSize): PanSize {
    val scale = max(viewport.width / image.width, viewport.height / image.height) * 1.08f
    return PanSize(image.width * scale, image.height * scale)
}

/** Final top-left of the picture. Nothing unpainted is allowed into the pane. */
internal fun restingOrigin(image: PanSize, viewport: PanSize, focus: PanPoint): PanPoint {
    val x = min(0f, max(viewport.width - image.width, viewport.width * 0.5f - focus.x * image.width))
    val y = min(0f, max(viewport.height - image.height, viewport.height * 0.4f - focus.y * image.height))
    return PanPoint(x, y)
}

/**
 * Start near the resting crop. A tall portrait must not sweep its whole height,
 * and a subject that is already centered still moves a little.
 */
internal fun startingOrigin(
    image: PanSize,
    viewport: PanSize,
    resting: PanPoint,
    imageNumber: Int,
    travelX: Float = 14f,
    travelY: Float = 18f,
): PanPoint {
    return PanPoint(
        x = nearby(
            resting.x,
            lower = viewport.width - image.width,
            upper = 0f,
            travel = travelX,
            sign = if (imageNumber % 2 == 0) 1f else -1f,
        ),
        y = nearby(
            resting.y,
            lower = viewport.height - image.height,
            upper = 0f,
            travel = travelY,
            sign = if (imageNumber % 3 == 0) 1f else -1f,
        ),
    )
}

private fun nearby(end: Float, lower: Float, upper: Float, travel: Float, sign: Float): Float {
    val preferredRoom = if (sign > 0f) upper - end else end - lower
    val oppositeRoom = if (sign > 0f) end - lower else upper - end
    val direction = if (preferredRoom >= min(travel, oppositeRoom)) sign else -sign
    return min(upper, max(lower, end + direction * travel))
}

/**
 * Landmarks for the original forty-two, reviewed by hand. Pictures after those
 * take their point from `approved-sources.json`.
 */
internal val curatedSayingFocus: Map<Int, PanPoint> = mapOf(
    1 to PanPoint(0.60f, 0.41f),
    2 to PanPoint(0.67f, 0.40f),
    3 to PanPoint(0.50f, 0.30f),
    4 to PanPoint(0.50f, 0.46f),
    5 to PanPoint(0.52f, 0.48f),
    6 to PanPoint(0.46f, 0.39f),
    7 to PanPoint(0.51f, 0.53f),
    8 to PanPoint(0.50f, 0.33f),
    9 to PanPoint(0.51f, 0.39f),
    10 to PanPoint(0.50f, 0.47f),
    11 to PanPoint(0.50f, 0.34f),
    12 to PanPoint(0.65f, 0.18f),
    13 to PanPoint(0.32f, 0.16f),
    14 to PanPoint(0.50f, 0.43f),
    15 to PanPoint(0.52f, 0.44f),
    16 to PanPoint(0.50f, 0.43f),
    17 to PanPoint(0.50f, 0.37f),
    18 to PanPoint(0.50f, 0.47f),
    19 to PanPoint(0.50f, 0.48f),
    20 to PanPoint(0.50f, 0.27f),
    21 to PanPoint(0.50f, 0.48f),
    22 to PanPoint(0.50f, 0.25f),
    23 to PanPoint(0.50f, 0.35f),
    24 to PanPoint(0.50f, 0.49f),
    25 to PanPoint(0.50f, 0.45f),
    26 to PanPoint(0.50f, 0.23f),
    27 to PanPoint(0.52f, 0.19f),
    28 to PanPoint(0.50f, 0.31f),
    29 to PanPoint(0.50f, 0.30f),
    30 to PanPoint(0.50f, 0.49f),
    31 to PanPoint(0.50f, 0.31f),
    32 to PanPoint(0.50f, 0.41f),
    33 to PanPoint(0.50f, 0.43f),
    34 to PanPoint(0.50f, 0.47f),
    35 to PanPoint(0.50f, 0.48f),
    36 to PanPoint(0.50f, 0.40f),
    37 to PanPoint(0.50f, 0.50f),
    38 to PanPoint(0.50f, 0.50f),
    39 to PanPoint(0.50f, 0.45f),
    40 to PanPoint(0.50f, 0.49f),
    41 to PanPoint(0.50f, 0.27f),
    42 to PanPoint(0.50f, 0.29f),
)
