package org.chotki.app.ui

import android.provider.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * The rope and the cross, once per process.
 *
 * A quit, a force-stop, or a reboot starts a new process and plays this.
 * Returning from the background does not, and neither does rotation. The
 * welcome underneath is a separate question, and it is still asked only once.
 *
 * Eleven knots come in from the lower one on the left, around to the lower one
 * on the right. The cross then appears between them. The whole mark eases from
 * 85% to full size over 1.8 seconds, holds, and leaves. The same clock as the
 * Mac opening.
 *
 * The proportions are [knot centres and the cross box] from the shared geometry:
 * twelve knots, the bottom one omitted, loop radius 0.30, centre 0.5 / 0.36.
 */

/**
 * One opening per process.
 *
 * A static, not saved state: the process dying is the quit, and a new process
 * starts with this true again. Rotation and a return from the background keep
 * the process, so they keep it false. Instrumented tests reset it, because
 * they share one process.
 */
internal object ColdOpen {
    var pending = true
}
@Composable
fun OpeningMark(onFinished: () -> Unit) {
    val context = LocalContext.current
    val animates = remember {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) > 0f
    }
    val progress = remember { Animatable(0f) }
    LaunchedEffect(animates) {
        if (!animates) {
            onFinished()
            return@LaunchedEffect
        }
        progress.animateTo(1f, tween(TOTAL_MS, easing = LinearEasing))
        onFinished()
    }

    val ms = progress.value * TOTAL_MS
    val build = (ms / BUILD_MS).coerceIn(0f, 1f)
    val scale = 0.85f + 0.15f * build
    val fade = if (ms < HOLD_END_MS) 1f else (1f - (ms - HOLD_END_MS) / FADE_MS).coerceIn(0f, 1f)

    Box(
        Modifier
            .fillMaxSize()
            .semantics { contentDescription = "The opening" },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(
            Modifier
                .size(220.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    alpha = fade
                },
        ) {
            val side = size.minDimension
            val left = (size.width - side) / 2f
            val top = (size.height - side) / 2f
            for (index in 1 until KNOTS) {
                val alpha = knotAlpha(ms, index)
                if (alpha <= 0f) continue
                val centre = knotCentre(index)
                drawCircle(
                    color = Chotki.gold.copy(alpha = alpha),
                    radius = side * KNOT_RADIUS,
                    center = Offset(left + centre.x * side, top + centre.y * side),
                )
            }
            val crossAlpha = ((ms - (BUILD_MS - 160f)) / 160f).coerceIn(0f, 1f)
            if (crossAlpha > 0f) {
                val box = crossBox()
                drawCross(
                    Offset(left + box.x * side, top + box.y * side),
                    Size(box.width * side, box.height * side),
                    Chotki.gold.copy(alpha = crossAlpha),
                )
            }
        }
    }
}

private const val KNOTS = 12
private const val LOOP_RADIUS = 0.30f
private const val CENTRE_X = 0.5f
private const val CENTRE_Y = 0.36f
private const val KNOT_RADIUS = 0.042f
private const val CROSS_HEIGHT = 0.34f
private const val CROSS_ASPECT = 748f / 1440f
private const val BUILD_MS = 1800f
private const val HOLD_MS = 1500f
private const val FADE_MS = 400f
private const val HOLD_END_MS = BUILD_MS + HOLD_MS
private const val TOTAL_MS = (HOLD_END_MS + FADE_MS).toInt()

private fun knotAlpha(ms: Float, index: Int): Float {
    val start = (index - 1) / (KNOTS - 1f) * (BUILD_MS - 200f)
    return ((ms - start) / 160f).coerceIn(0f, 1f)
}

/** Screen y grows downward, so the sweep from index 1 reads clockwise. */
private fun knotCentre(index: Int): Offset {
    val angle = (PI / 2.0 + index.toDouble() / KNOTS * 2.0 * PI).toFloat()
    return Offset(
        CENTRE_X + LOOP_RADIUS * cos(angle),
        CENTRE_Y + LOOP_RADIUS * sin(angle),
    )
}

private data class BoxFrac(val x: Float, val y: Float, val width: Float, val height: Float)

private fun crossBox(): BoxFrac {
    val width = CROSS_HEIGHT * CROSS_ASPECT
    return BoxFrac(
        CENTRE_X - width / 2f,
        CENTRE_Y + LOOP_RADIUS - KNOT_RADIUS,
        width,
        CROSS_HEIGHT,
    )
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawCross(
    origin: Offset,
    box: Size,
    color: androidx.compose.ui.graphics.Color,
) {
    data class Bar(val x: Float, val y: Float, val w: Float, val h: Float)
    val bars = listOf(
        Bar(0.402f, 0.000f, 0.201f, 1.000f),
        Bar(0.205f, 0.101f, 0.594f, 0.097f),
        Bar(0.000f, 0.299f, 1.000f, 0.097f),
    )
    for (bar in bars) {
        drawRect(
            color,
            Offset(origin.x + bar.x * box.width, origin.y + bar.y * box.height),
            Size(bar.w * box.width, bar.h * box.height),
        )
    }
    // The viewer's left end of the footrest is the higher one.
    val x0 = origin.x + 0.209f * box.width
    val x1 = origin.x + 0.786f * box.width
    val y0 = origin.y + 0.639f * box.height
    val y1 = origin.y + 0.792f * box.height
    val thick = 0.097f * box.height
    drawPath(
        Path().apply {
            moveTo(x0, y0)
            lineTo(x1, y1)
            lineTo(x1, y1 + thick)
            lineTo(x0, y0 + thick)
            close()
        },
        color,
    )
}
