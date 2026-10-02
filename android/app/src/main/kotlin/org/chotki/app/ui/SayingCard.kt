package org.chotki.app.ui

import android.content.Context
import android.graphics.BitmapFactory
import android.provider.Settings
import android.util.LruCache
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt
import org.chotki.core.CalendarDate
import org.chotki.core.content.PatristicReadings

/**
 * The saying for this civil day, on that day's picture.
 *
 * The picture is drawn a little larger than the card and clipped to it, then
 * eases onto its subject and holds. Today's drift is remembered, so leaving
 * Home and coming back does not play it again. With animations turned off, the
 * picture is simply shown at rest. The words stay at the foot, on the gradient,
 * and do not move with the picture.
 */
@Composable
fun SayingCard(
    date: CalendarDate,
    modifier: Modifier = Modifier,
    persistMotion: Boolean = false,
) {
    val saying = PatristicReadings.forDay(date) ?: return
    val context = LocalContext.current
    val names = remember {
        runCatching {
            context.assets.open("sayings/order.txt").bufferedReader().use { it.readText() }
        }.getOrDefault("")
            .let(::sayingNames)
    }
    val approved = remember {
        runCatching {
            context.assets.open("sayings/approved-sources.json").bufferedReader().use { it.readText() }
        }.map(::approvedSayingFocus).getOrDefault(emptyMap())
    }
    val path = sayingName(names, date) ?: return
    val image = remember(path) { SayingBitmaps.get(context, path) } ?: return
    val store = remember(context) { PrefPanStore(context.applicationContext) }
    val animates = remember {
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f,
        ) > 0f
    }
    val startedAt = remember(date.iso, path, persistMotion) {
        sharedSayingPanTimeline.start(
            date.iso,
            path,
            persistMotion,
            System.currentTimeMillis(),
            store,
        )
    }
    val progress = remember(startedAt, animates) {
        val fraction = if (!animates) {
            1f
        } else {
            ((System.currentTimeMillis() - startedAt) / SAYING_PAN_DURATION_MS).toFloat()
        }
        Animatable(fraction.coerceIn(0f, 1f))
    }
    LaunchedEffect(startedAt, animates) {
        if (!animates || progress.value >= 1f) {
            progress.snapTo(1f)
            return@LaunchedEffect
        }
        val remaining = ((1f - progress.value) * SAYING_PAN_DURATION_MS).toInt().coerceAtLeast(1)
        progress.animateTo(1f, tween(durationMillis = remaining, easing = PanEasing))
    }

    val density = LocalDensity.current
    val travelX = with(density) { 14.dp.toPx() }
    val travelY = with(density) { 18.dp.toPx() }
    val focus = sayingFocus(path, approved)

    val fraction = progress.value
    Box(modifier.fillMaxWidth().height(220.dp).clipToBounds()) {
        // Cover size, clipped to the card. A child view would be forced down to the card and leave the words uncovered.
        Canvas(Modifier.fillMaxSize()) {
            val viewport = PanSize(size.width, size.height)
            if (viewport.width <= 0f || viewport.height <= 0f) return@Canvas
            val rendered = renderedSize(
                PanSize(image.width.toFloat(), image.height.toFloat()),
                viewport,
            )
            val end = restingOrigin(rendered, viewport, focus)
            val start = startingOrigin(
                rendered,
                viewport,
                end,
                imageNumber(path),
                travelX,
                travelY,
            )
            val originX = start.x + (end.x - start.x) * fraction
            val originY = start.y + (end.y - start.y) * fraction
            drawImage(
                image,
                dstOffset = IntOffset(originX.roundToInt(), originY.roundToInt()),
                dstSize = IntSize(
                    rendered.width.roundToInt().coerceAtLeast(1),
                    rendered.height.roundToInt().coerceAtLeast(1),
                ),
                filterQuality = FilterQuality.Medium,
            )
        }
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        0.35f to Color.Transparent,
                        1f to Color(0xE615161C),
                    ),
                ),
        )
        Column(
            Modifier
                .align(Alignment.BottomStart)
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            Text(
                "Sayings of the church fathers",
                color = Chotki.parchment,
                fontSize = 11.sp,
                style = TextStyle(shadow = Shadow(Color.Black, blurRadius = 6f)),
            )
            Text(
                saying.text,
                color = Chotki.parchment,
                fontFamily = FontFamily.Serif,
                fontSize = 15.sp,
                lineHeight = 21.sp,
                textAlign = TextAlign.Start,
                style = TextStyle(shadow = Shadow(Color.Black, blurRadius = 8f)),
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                "${saying.author} · ${saying.source}",
                color = Chotki.parchmentDim,
                fontSize = 12.sp,
                style = TextStyle(shadow = Shadow(Color.Black, blurRadius = 6f)),
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

private val PanEasing = CubicBezierEasing(0.42f, 0f, 0.58f, 1f)

private object SayingBitmaps {
    private val cache = LruCache<String, ImageBitmap>(3)

    fun get(context: Context, path: String): ImageBitmap? {
        cache.get(path)?.let { return it }
        val decoded = decode(context, path) ?: return null
        cache.put(path, decoded)
        return decoded
    }

    private fun decode(context: Context, path: String): ImageBitmap? {
        return runCatching {
            val bytes = context.assets.open(path).use { it.readBytes() }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            val longest = maxOf(bounds.outWidth, bounds.outHeight).coerceAtLeast(1)
            var sample = 1
            while (longest / sample > 1400) sample *= 2
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)?.asImageBitmap()
        }.getOrNull()
    }
}

private class PrefPanStore(context: Context) : PanStartStore {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override fun read(identity: String): Long? {
        if (prefs.getString(KEY_IMAGE, null) != identity) return null
        if (!prefs.contains(KEY_START)) return null
        return prefs.getLong(KEY_START, 0L)
    }

    override fun write(identity: String, startedAt: Long) {
        prefs.edit().putString(KEY_IMAGE, identity).putLong(KEY_START, startedAt).apply()
    }

    private companion object {
        const val PREFS = "chotki.sayingPan"
        const val KEY_IMAGE = "chotki.sayingPan.image"
        const val KEY_START = "chotki.sayingPan.startedAt"
    }
}
