package org.chotki.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * A border for the pages that carry received text.
 *
 * Ryan's reference is a scanned ornament printed in black on white. On a
 * `#15161C` ground black is nothing at all, so it is redrawn in the app's own
 * parchment at low opacity, which is what "a partially transparent layer"
 * means here. The motif is his: arrowhead, diamond, arrowhead, running between
 * two hairlines, with a knot where the two arms meet.
 *
 * Drawn rather than imported, in the same way and the same weight as the bar's
 * icons. Nothing is bundled, nothing scales badly.
 *
 * **Four corner pieces, not a frame.** That is what the reference is, and it
 * is the better reading: a continuous band closes a page in like a certificate,
 * where corners suggest the border and leave the page open. The rules that run
 * between them fade out at both ends rather than stopping, so nothing butts
 * into the knot.
 *
 * It takes no touches and no screen-reader stops. The text scrolls underneath
 * rather than being inset into it, so a long prayer is never narrowed to make
 * room for decoration.
 */
@Composable
fun VenerationBorder(
    modifier: Modifier = Modifier,
    colour: Color = Chotki.parchment,
    opacity: Float = PRESENT,
) {
    Canvas(modifier.fillMaxSize()) {
        val ink = colour.copy(alpha = opacity)
        val inset = INSET.toPx()
        val arm = ARM.toPx()

        val left = inset
        val top = inset
        val right = size.width - inset
        val bottom = size.height - inset

        // Only draw the arms if there is room for two of them and a gap. On a
        // short screen the corners would otherwise overlap in the middle and
        // read as a solid box.
        val armX = minOf(arm, (right - left) / 2f - 8.dp.toPx())
        val armY = minOf(arm, (bottom - top) / 2f - 8.dp.toPx())
        if (armX <= 0f || armY <= 0f) return@Canvas

        corner(ink, left, top, 1f, 1f, armX, armY)
        corner(ink, right, top, -1f, 1f, armX, armY)
        corner(ink, left, bottom, 1f, -1f, armX, armY)
        corner(ink, right, bottom, -1f, -1f, armX, armY)

        // The rules between the corners, fading in and out so they arrive at
        // the knot rather than crashing into it.
        edge(ink, Offset(left + armX, top), Offset(right - armX, top))
        edge(ink, Offset(left + armX, bottom), Offset(right - armX, bottom))
        edge(ink, Offset(left, top + armY), Offset(left, bottom - armY))
        edge(ink, Offset(right, top + armY), Offset(right, bottom - armY))
    }
}

/** What Ryan chose: present when you look for it, gone while you are reading. */
const val PRESENT = 0.11f

/**
 * How far the ornament sits from the edge of the page.
 *
 * The text is held further in again by its own padding. The first drawing had
 * the two almost touching and Ryan asked for the air back, which is right: an
 * ornament that crowds the words is decorating at the reader's expense.
 */
val INSET: Dp = 14.dp

/** The length of one arm of a corner piece. */
private val ARM: Dp = 74.dp

/** The height of the band, between its two hairlines. */
private val BAND: Dp = 11.dp

/** One repeat of arrowhead, diamond, arrowhead. */
private val TILE: Dp = 16.dp

/** The knot where the two arms meet. */
private val KNOT: Dp = 22.dp

/**
 * One corner, drawn from the page's corner inwards.
 *
 * `sx` and `sy` are +1 or -1 and mirror the whole piece, so the same drawing
 * serves all four without four sets of coordinates to keep in step.
 */
private fun DrawScope.corner(
    ink: Color,
    originX: Float,
    originY: Float,
    sx: Float,
    sy: Float,
    armX: Float,
    armY: Float,
) {
    withTransform({
        translate(originX, originY)
        scale(sx, sy, pivot = Offset.Zero)
    }) {
        arm(ink, armX)
        // The second arm is the first one reflected in the line y = x.
        withTransform({ transform(swapAxes()) }) { arm(ink, armY) }
        knot(ink)
    }
}

/** A matrix that swaps x and y, turning the horizontal arm into the vertical. */
private fun swapAxes() = androidx.compose.ui.graphics.Matrix(
    floatArrayOf(
        0f, 1f, 0f, 0f,
        1f, 0f, 0f, 0f,
        0f, 0f, 1f, 0f,
        0f, 0f, 0f, 1f,
    ),
)

/** One arm: two hairlines with the motif repeating between them. */
private fun DrawScope.arm(ink: Color, length: Float) {
    val band = BAND.toPx()
    val tile = TILE.toPx()
    val start = KNOT.toPx()
    val hair = 0.9.dp.toPx()

    if (length <= start) return

    drawRect(ink, Offset(start, 0f), androidx.compose.ui.geometry.Size(length - start, hair))
    drawRect(
        ink,
        Offset(start, band - hair),
        androidx.compose.ui.geometry.Size(length - start, hair),
    )

    var x = start
    val middle = band / 2f
    while (x + tile <= length) {
        val path = Path().apply {
            // diamond
            moveTo(x + tile / 2f, middle - tile * 0.23f)
            lineTo(x + tile * 0.72f, middle)
            lineTo(x + tile / 2f, middle + tile * 0.23f)
            lineTo(x + tile * 0.28f, middle)
            close()
            // arrowhead pointing back along the arm
            moveTo(x, middle)
            lineTo(x + tile * 0.17f, middle - tile * 0.105f)
            lineTo(x + tile * 0.17f, middle + tile * 0.105f)
            close()
            // arrowhead pointing on
            moveTo(x + tile, middle)
            lineTo(x + tile * 0.83f, middle - tile * 0.105f)
            lineTo(x + tile * 0.83f, middle + tile * 0.105f)
            close()
        }
        drawPath(path, ink)
        x += tile
    }
}

/** The knot: an outlined diamond, a filled one inside it, and a hole at the centre. */
private fun DrawScope.knot(ink: Color) {
    val k = KNOT.toPx()
    val c = k / 2f

    fun diamond(radius: Float) = Path().apply {
        moveTo(c, c - radius)
        lineTo(c + radius, c)
        lineTo(c, c + radius)
        lineTo(c - radius, c)
        close()
    }

    drawPath(diamond(c - 0.6.dp.toPx()), ink, style = Stroke(width = 1.dp.toPx()))
    // An outlined ring rather than a filled diamond with a hole punched in it.
    // `BlendMode.Clear` would have cleared the text underneath as well, this
    // canvas having no layer of its own, and at this opacity the difference is
    // invisible anyway.
    drawPath(diamond(c * 0.58f), ink, style = Stroke(width = 1.6.dp.toPx()))
}

/** A hairline that fades in from nothing and back to nothing. */
private fun DrawScope.edge(ink: Color, from: Offset, to: Offset) {
    val length = (to - from).getDistance()
    if (length <= 0f) return
    drawLine(
        brush = Brush.linearGradient(
            0f to Color.Transparent,
            0.22f to ink,
            0.78f to ink,
            1f to Color.Transparent,
            start = from,
            end = to,
        ),
        start = from,
        end = to,
        strokeWidth = 0.9.dp.toPx(),
    )
}


/**
 * Where scrolling text goes to disappear.
 *
 * The ornament is drawn over the words, so a line of text arriving at the top
 * of the page crossed the border and sat on top of it for a moment before
 * leaving. It should come out from behind it instead.
 *
 * A band of the page's own ground at each end, solid at the very edge and gone
 * by the time it is clear of the band, drawn under the ornament and over the
 * text. Nothing is clipped and nothing reflows: the text still has the full
 * height of the page, it simply dissolves before it reaches the frame.
 */
@Composable
fun EdgeFade(
    modifier: Modifier = Modifier,
    ground: Color = Chotki.ground,
    depth: Dp = FADE,
) {
    Canvas(modifier.fillMaxSize()) {
        val band = depth.toPx()
        if (band <= 0f || size.height < band * 2) return@Canvas

        drawRect(
            brush = Brush.verticalGradient(
                0f to ground,
                0.55f to ground,
                1f to Color.Transparent,
                startY = 0f,
                endY = band,
            ),
            size = androidx.compose.ui.geometry.Size(size.width, band),
        )
        drawRect(
            brush = Brush.verticalGradient(
                0f to Color.Transparent,
                0.45f to ground,
                1f to ground,
                startY = size.height - band,
                endY = size.height,
            ),
            topLeft = Offset(0f, size.height - band),
            size = androidx.compose.ui.geometry.Size(size.width, band),
        )
    }
}

/**
 * How deep the fade runs.
 *
 * Far enough to clear the ornament: the band's inner edge is 25dp in, and the
 * text should already be gone by then rather than arriving at it.
 */
private val FADE: Dp = 40.dp
