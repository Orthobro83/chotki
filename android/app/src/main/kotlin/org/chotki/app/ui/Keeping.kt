package org.chotki.app.ui

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import org.chotki.app.AppState
import org.chotki.core.store.BackupException
import java.time.LocalDate

/**
 * Saving the record somewhere safe, and getting it back.
 *
 * Through the Storage Access Framework rather than a folder of our own: the
 * person chooses where it goes, it survives the app being uninstalled, and it
 * needs no storage permission on any Android version. Chotki turns Android's
 * own backup off, so this file is the only way a record moves to a new phone.
 */
object Keeping {

    /** Dated, because the second copy someone makes should not overwrite the first. */
    fun suggestedName(today: LocalDate = LocalDate.now()): String = "chotki-$today.json"

    /**
     * Both directions report in the same words the app uses elsewhere: a fact,
     * never a scolding, and never a decoder's own message.
     */
    sealed interface Outcome {
        data class Saved(val name: String) : Outcome
        data class Restored(val rules: Int) : Outcome
        data class Failed(val reason: String) : Outcome
    }

    fun save(context: Context, state: AppState, to: Uri): Outcome {
        return try {
            val text = state.exportJson()
            val stream = context.contentResolver.openOutputStream(to, "wt")
                ?: return Outcome.Failed("Could not write to that place.")
            stream.use { it.write(text.toByteArray()) }
            Outcome.Saved(displayName(context, to))
        } catch (e: Exception) {
            Outcome.Failed("Could not save your record there.")
        }
    }

    /**
     * What to call the file when telling someone where their record went.
     *
     * A document URI's last path segment is the provider's own id — `8`, on the
     * emulator — so the obvious thing produces "Saved to 8." The display name
     * has to be asked for.
     */
    private fun displayName(context: Context, uri: Uri): String {
        val name = runCatching {
            context.contentResolver.query(
                uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null,
            )?.use { cursor ->
                val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
            }
        }.getOrNull()
        return name ?: "your chosen file"
    }

    fun restore(context: Context, state: AppState, from: Uri): Outcome {
        return try {
            val text = context.contentResolver.openInputStream(from)?.use { it.readBytes() }
                ?.toString(Charsets.UTF_8)
                ?: return Outcome.Failed("Could not read that file.")
            state.restoreFrom(text)
            Outcome.Restored(state.rules.size)
        } catch (e: BackupException) {
            // The one exception whose own words are meant for a person.
            Outcome.Failed(e.message ?: "That file could not be restored.")
        } catch (e: Exception) {
            Outcome.Failed("Could not read that file.")
        }
    }
}
