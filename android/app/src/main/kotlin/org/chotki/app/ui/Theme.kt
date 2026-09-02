package org.chotki.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily

/**
 * The same palette as the macOS app, to the value.
 *
 * Taken from `Theme.swift` rather than approximated: the two are one
 * application, and a person who keeps their rule on both should not feel they
 * have moved house. Dark throughout — the app is opened first thing in the
 * morning and last thing at night, and a white screen at either hour is unkind.
 */
object Chotki {
    val ground = Color(0xFF15161C)
    val panel = Color(0xFF1C1E26)
    val line = Color(0xFF2E2A20)
    val lineSoft = Color(0xFF23252C)

    val gold = Color(0xFFC9A227)
    val goldDim = Color(0xFF8A7220)
    val parchment = Color(0xFFE8DFCD)
    val parchmentDim = Color(0xFFD8CFBD)
    val muted = Color(0xFF8A8578)
    val faint = Color(0xFF5A564C)

    /**
     * The face for anything meant to be read: prayers, psalms, the day's
     * readings, the fathers, glossary entries, reflections.
     *
     * **Android's own serif, not a bundled one.** macOS and iOS read in Iowan
     * Old Style, which is John Downer's, licensed to Apple, and may not be
     * redistributed — so it cannot come here whatever the bundle size. The rule
     * agreed for the ports is that each platform picks the **native face
     * closest to what macOS chose**, and on Android that is the platform serif:
     * present on every device, no licence to check, no megabyte to ship.
     *
     * Charter — the second face in the Apple chain — is freely redistributable
     * and could be bundled if the platform serif is ever judged too far off.
     * That is a decision to take deliberately with the font in front of you,
     * not one to make by default.
     *
     * Chrome keeps the platform sans: the month grid's figures want to be tight
     * and unambiguous, and Roboto is what makes the app look like it belongs on
     * the device.
     */
    val reading = FontFamily.Serif

    val violet = Color(0xFF9A8FC4)
    val ochre = Color(0xFFA63A38)
}

@Composable
fun ChotkiTheme(content: @Composable () -> Unit) {
    // Dark either way. `isSystemInDarkTheme` is read so the intent is explicit
    // rather than accidental: this is not a light theme that happens to be dark.
    @Suppress("UNUSED_EXPRESSION") isSystemInDarkTheme()
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Chotki.gold,
            onPrimary = Chotki.ground,
            background = Chotki.ground,
            onBackground = Chotki.parchment,
            surface = Chotki.panel,
            onSurface = Chotki.parchment,
            error = Chotki.ochre,
        ),
        content = content,
    )
}
