package org.chotki.app.ui

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.core.CalendarDate
import org.chotki.core.content.PatristicReadings

/**
 * The saying for this civil day, on the picture chosen for the same day.
 *
 * The picture is a fraction of the date, so it does not change between launches.
 * The crop keeps the lower part of the image, and the words sit on a gradient
 * there rather than in a box — that is where vestments and ground are, not faces.
 */
@Composable
fun SayingCard(date: CalendarDate, modifier: Modifier = Modifier) {
    val saying = PatristicReadings.forDay(date) ?: return
    val context = LocalContext.current
    val names = remember {
        runCatching {
            context.assets.open("sayings/order.txt").bufferedReader().readLines()
                .map { it.trim() }
                .filter { it.isNotEmpty() }
        }.getOrDefault(emptyList())
    }
    if (names.isEmpty()) return
    val path = names[dayOfYear(date) % names.size]
    val image = remember(path) {
        runCatching {
            context.assets.open(path).use { stream ->
                val bytes = stream.readBytes()
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                val longest = maxOf(bounds.outWidth, bounds.outHeight).coerceAtLeast(1)
                var sample = 1
                while (longest / sample > 1400) sample *= 2
                val opts = BitmapFactory.Options().apply { inSampleSize = sample }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)?.asImageBitmap()
            }
        }.getOrNull()
    } ?: return

    Box(modifier.fillMaxWidth().height(220.dp)) {
        Image(
            bitmap = image,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            alignment = Alignment.BottomCenter,
            modifier = Modifier.fillMaxWidth().height(220.dp),
        )
        Box(
            Modifier
                .fillMaxWidth()
                .height(220.dp)
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

private fun dayOfYear(date: CalendarDate): Int {
    var total = date.day
    for (month in 1 until date.month) {
        total += CalendarDate.daysInMonth(date.year, month)
    }
    return total
}
