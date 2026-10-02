package org.chotki.app

import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.onAllNodesWithContentDescription

/**
 * The rope and the cross cover the shell for one process start. Tests that
 * are about what is underneath have to let it finish, and a later test in
 * the same process finds it already spent.
 */
internal fun ComposeContentTestRule.settlePastOpening() {
    waitForIdle()
    val showing = onAllNodesWithContentDescription("The opening")
        .fetchSemanticsNodes().isNotEmpty()
    if (!showing) return
    mainClock.advanceTimeBy(4_000)
    waitForIdle()
}
