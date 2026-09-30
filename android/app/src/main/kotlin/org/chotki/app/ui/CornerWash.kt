package org.chotki.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.withTransform

/**
 * The phone's ground, with the two washes from the mockup.
 *
 * A parchment ellipse sits off the top-left corner and a gold one off the
 * bottom-right. Screens drawn on top of this leave those corners visible.
 */
@Composable
fun ChotkiBackdrop(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier.fillMaxSize().background(Chotki.ground)) {
        CornerWash(Modifier.matchParentSize())
        content()
    }
}

@Composable
fun CornerWash(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        // The mockup's ellipses, four times the area. Centres and fade stops
        // stay where elegant.html put them: parchment off the top left, gold
        // off the lower right.
        // ellipse 120% × 58% at -14%, -10%, parchment falling off at 62%.
        wash(
            center = Offset(size.width * -0.14f, size.height * -0.10f),
            radiusX = size.width * 0.60f * WASH_AREA,
            radiusY = size.height * 0.29f * WASH_AREA,
            color = Chotki.parchment.copy(alpha = 0.26f),
            stop = 0.62f,
        )
        // ellipse 100% × 52% at 114%, 112%, gold falling off at 58%.
        wash(
            center = Offset(size.width * 1.14f, size.height * 1.12f),
            radiusX = size.width * 0.50f * WASH_AREA,
            radiusY = size.height * 0.26f * WASH_AREA,
            color = Chotki.gold.copy(alpha = 0.22f),
            stop = 0.58f,
        )
    }
}

/**
 * Twice √2. Each step doubles the ellipse area (radii × √2), and this is the
 * second doubling, so each wash covers four times the mockup's area.
 */
private const val WASH_AREA = 2f

private fun androidx.compose.ui.graphics.drawscope.DrawScope.wash(
    center: Offset,
    radiusX: Float,
    radiusY: Float,
    color: Color,
    stop: Float,
) {
    if (radiusX <= 0f || radiusY <= 0f) return
    withTransform({
        scale(scaleX = radiusX / radiusY, scaleY = 1f, pivot = center)
    }) {
        drawCircle(
            brush = Brush.radialGradient(
                colorStops = arrayOf(0f to color, stop to Color.Transparent),
                center = center,
                radius = radiusY,
            ),
            radius = radiusY,
            center = center,
        )
    }
}
