package org.chotki.app

import androidx.core.net.toUri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.chotki.app.platform.AndroidDb
import org.chotki.app.ui.Keeping
import org.chotki.core.CalendarDate
import org.chotki.core.Activation
import org.chotki.core.Recurrence
import org.chotki.core.Rule
import org.chotki.core.store.SqliteStore
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue

/**
 * The record leaving the phone and coming back, through a real content URI.
 *
 * The core tests cover the format. This covers the part only a device can: that
 * [android.content.ContentResolver] actually opens what the picker returns, and
 * that "wt" truncates rather than leaving the tail of a longer file behind —
 * the failure that turns a second, smaller backup into unreadable JSON.
 */
@RunWith(AndroidJUnit4::class)
class KeepingTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun state(): AppState =
        AppState(SqliteStore(AndroidDb.inMemory())).also { it.load() }

    private fun scratch(name: String): File =
        File(context.cacheDir, name).also { it.delete() }

    @Test fun theRecordSurvivesLeavingThePhoneAndComingBack() {
        val from = state()
        val rule = Rule(title = "Evening prayers", recurrence = Recurrence.Daily)
        from.save(rule)
        from.takeUp(rule)

        val file = scratch("backup.json")
        assertTrue(
            "saving failed",
            Keeping.save(context, from, file.toUri()) is Keeping.Outcome.Saved,
        )
        assertTrue("the file is empty", file.length() > 0)

        val to = state()
        val outcome = Keeping.restore(context, to, file.toUri())
        assertTrue("restoring failed: $outcome", outcome is Keeping.Outcome.Restored)
        assertEquals(listOf("Evening prayers"), to.rules.map { it.title })
    }

    /**
     * A second, shorter backup must not leave the first one's tail behind.
     *
     * Without "wt" the write is a plain overwrite from offset zero, so a
     * smaller file keeps whatever ran past its end — and the result parses as
     * neither the old backup nor the new one.
     */
    @Test fun asmallerBackupDoesNotLeaveTheOldOneTrailingBehindIt() {
        val big = state()
        repeat(12) { big.save(Rule(title = "Rule number $it", recurrence = Recurrence.Daily)) }

        val file = scratch("twice.json")
        Keeping.save(context, big, file.toUri())
        val longLength = file.length()

        val small = state()
        small.save(Rule(title = "Only one", recurrence = Recurrence.Daily))
        Keeping.save(context, small, file.toUri())

        assertTrue("the file did not shrink, so it was not truncated", file.length() < longLength)

        val back = state()
        val outcome = Keeping.restore(context, back, file.toUri())
        assertTrue("the second backup did not parse: $outcome", outcome is Keeping.Outcome.Restored)
        assertEquals(listOf("Only one"), back.rules.map { it.title })
    }

    @Test fun aFileThatIsNotABackupSaysSoInsteadOfCrashing() {
        val file = scratch("rubbish.json")
        file.writeText("this is not a backup")

        val outcome = Keeping.restore(context, state(), file.toUri())
        assertTrue("rubbish was accepted", outcome is Keeping.Outcome.Failed)
        assertEquals("That file is not a Chotki backup.", (outcome as Keeping.Outcome.Failed).reason)
    }
}
