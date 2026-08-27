package org.chotki.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * The bar's icons, drawn rather than imported.
 *
 * The macOS app uses SF Symbols, which cannot come across. Material's extended
 * set is the usual substitute and is enormous — large enough that adding it for
 * six glyphs failed to dex at all — so these are drawn in the app's own line
 * weight, at one stroke width, and take their colour from whatever the bar is
 * tinting them.
 *
 * Each one means what the symbol it replaces meant.
 */
@Composable
fun PlaceIcon(place: Place, tint: Color, size: androidx.compose.ui.unit.Dp = 22.dp) {
    Canvas(Modifier.size(size)) {
        val stroke = Stroke(width = this.size.minDimension * 0.085f)
        when (place) {
            Place.RULE -> calendar(tint, stroke)
            Place.PRAYERS -> rope(tint, stroke)
            Place.READING -> openBook(tint, stroke)
            Place.PROGRESS -> risingLine(tint, stroke)
            Place.GLOSSARY -> closedBook(tint, stroke)
            Place.SETTINGS -> sliders(tint, stroke)
        }
    }
}

/**
 * The library, wherever it is offered — the bar does not carry it, so it is
 * drawn on its own rather than through [PlaceIcon].
 *
 * Standing books, matching the `books.vertical` the iOS build uses and the
 * shelf the Mac shows. The same mark in the corner and in the middle of an
 * empty day, because they open the same thing.
 */
@Composable
fun LibraryIcon(tint: Color, size: androidx.compose.ui.unit.Dp = 22.dp) {
    Canvas(Modifier.size(size)) {
        library(tint, Stroke(width = this.size.minDimension * 0.085f))
    }
}

/** A closed book: the glossary, at the top of the Reading. */
@Composable
fun GlossaryIcon(tint: Color, size: androidx.compose.ui.unit.Dp = 22.dp) {
    Canvas(Modifier.size(size)) {
        closedBook(tint, Stroke(width = this.size.minDimension * 0.085f))
    }
}

/**
 * Three books on a shelf, the last one leaning as they do.
 *
 * Spines, with a band across each the way a bound book has one, and clear air
 * between them. Without the bands and the gaps three outlined rectangles of
 * different heights read as a bar chart, which is the wrong meaning entirely on
 * a screen that also has a progress tab.
 */
private fun DrawScope.library(tint: Color, stroke: Stroke) {
    val w = size.width
    val foot = w * 0.84f

    fun spine(left: Float, top: Float) {
        val wide = w * 0.15f
        drawRect(
            color = tint,
            topLeft = Offset(left, top),
            size = Size(wide, foot - top),
            style = stroke,
        )
        // The band, a third of the way down.
        val band = top + (foot - top) * 0.30f
        drawLine(tint, Offset(left, band), Offset(left + wide, band), stroke.width)
    }

    spine(w * 0.14f, w * 0.28f)
    spine(w * 0.36f, w * 0.18f)

    // One leaning against the others, its band tilted with it.
    val lean = Path().apply {
        moveTo(w * 0.60f, foot)
        lineTo(w * 0.71f, w * 0.24f)
        lineTo(w * 0.85f, w * 0.29f)
        lineTo(w * 0.74f, foot)
        close()
    }
    drawPath(lean, tint, style = stroke)
    drawLine(
        tint,
        Offset(w * 0.665f, w * 0.44f),
        Offset(w * 0.805f, w * 0.49f),
        stroke.width,
    )
}

/** A month, with the two rings a wall calendar hangs from. */
private fun DrawScope.calendar(tint: Color, stroke: Stroke) {
    val w = size.width
    val inset = w * 0.12f
    drawRoundRect(
        color = tint,
        topLeft = Offset(inset, w * 0.22f),
        size = Size(w - inset * 2, w * 0.66f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.08f),
        style = stroke,
    )
    drawLine(tint, Offset(inset, w * 0.42f), Offset(w - inset, w * 0.42f), stroke.width)
    for (x in listOf(0.33f, 0.67f)) {
        drawLine(tint, Offset(w * x, w * 0.1f), Offset(w * x, w * 0.28f), stroke.width)
    }
}

/** A prayer rope: knots round a circle, with the knot where it is joined. */
private fun DrawScope.rope(tint: Color, stroke: Stroke) {
    val centre = Offset(size.width / 2, size.height * 0.54f)
    val radius = size.minDimension * 0.34f
    val knots = 9
    for (index in 0 until knots) {
        val angle = -PI / 2 + index * (2 * PI / knots)
        drawCircle(
            color = tint,
            radius = stroke.width * 0.95f,
            center = Offset(
                centre.x + (radius * cos(angle)).toFloat(),
                centre.y + (radius * sin(angle)).toFloat(),
            ),
        )
    }
    // The tassel, which is what makes it a rope rather than a ring of dots.
    drawLine(
        tint,
        Offset(centre.x, centre.y - radius),
        Offset(centre.x, size.height * 0.08f),
        stroke.width,
    )
}

/** An open book: two pages meeting at the spine. */
private fun DrawScope.openBook(tint: Color, stroke: Stroke) {
    val w = size.width
    val h = size.height
    val path = Path().apply {
        moveTo(w * 0.5f, h * 0.28f)
        cubicTo(w * 0.34f, h * 0.16f, w * 0.2f, h * 0.18f, w * 0.1f, h * 0.22f)
        lineTo(w * 0.1f, h * 0.78f)
        cubicTo(w * 0.24f, h * 0.72f, w * 0.38f, h * 0.74f, w * 0.5f, h * 0.84f)
        cubicTo(w * 0.62f, h * 0.74f, w * 0.76f, h * 0.72f, w * 0.9f, h * 0.78f)
        lineTo(w * 0.9f, h * 0.22f)
        cubicTo(w * 0.8f, h * 0.18f, w * 0.66f, h * 0.16f, w * 0.5f, h * 0.28f)
        close()
    }
    drawPath(path, tint, style = stroke)
    drawLine(tint, Offset(w * 0.5f, h * 0.28f), Offset(w * 0.5f, h * 0.84f), stroke.width)
}

/** Days going by, and a line that rises. */
private fun DrawScope.risingLine(tint: Color, stroke: Stroke) {
    val w = size.width
    val h = size.height
    val path = Path().apply {
        moveTo(w * 0.12f, h * 0.72f)
        lineTo(w * 0.38f, h * 0.46f)
        lineTo(w * 0.56f, h * 0.62f)
        lineTo(w * 0.88f, h * 0.24f)
    }
    drawPath(path, tint, style = stroke)
    drawLine(tint, Offset(w * 0.12f, h * 0.86f), Offset(w * 0.88f, h * 0.86f), stroke.width)
}

/** A closed book, spine to the left. */
private fun DrawScope.closedBook(tint: Color, stroke: Stroke) {
    val w = size.width
    val h = size.height
    drawRoundRect(
        color = tint,
        topLeft = Offset(w * 0.2f, h * 0.14f),
        size = Size(w * 0.62f, h * 0.72f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.06f),
        style = stroke,
    )
    drawLine(tint, Offset(w * 0.34f, h * 0.14f), Offset(w * 0.34f, h * 0.86f), stroke.width)
}

/** Settings: three things that can be set. */
private fun DrawScope.sliders(tint: Color, stroke: Stroke) {
    val w = size.width
    val rows = listOf(0.28f to 0.62f, 0.5f to 0.38f, 0.72f to 0.7f)
    for ((y, knob) in rows) {
        drawLine(tint, Offset(w * 0.14f, size.height * y), Offset(w * 0.86f, size.height * y), stroke.width)
        drawCircle(tint, radius = stroke.width * 1.5f, center = Offset(w * knob, size.height * y))
    }
}
