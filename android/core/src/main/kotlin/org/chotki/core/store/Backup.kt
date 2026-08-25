package org.chotki.core.store

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.chotki.core.Activation
import org.chotki.core.AppSettings
import org.chotki.core.InstantSerializer
import org.chotki.core.Occurrence
import org.chotki.core.Rule
import java.time.Instant

/**
 * A portable snapshot of everything, for backup and for moving between phones.
 *
 * Deliberately plain JSON: the record of what someone kept should outlive this
 * application. The same reasoning, and the same fields, as the Swift `Backup`.
 *
 * **It is not interchangeable with a macOS backup**, and deliberately so. The
 * two platforms encode the JSON columns differently — see the note at the top
 * of [Schema] — which was settled when sync was ruled out. A file from a Mac
 * will be refused rather than half-read; [Store.importJson] says so plainly.
 */
@Serializable
data class Backup(
    val version: Int = 1,
    /** Which app wrote it, so a Mac file can be recognised and refused. */
    val platform: String = PLATFORM,
    @Serializable(with = InstantSerializer::class)
    val exportedAt: Instant,
    val rules: List<Rule>,
    val activations: List<Activation>,
    val occurrences: List<Occurrence>,
    /** Optional, so a backup written before settings moved here still restores. */
    val settings: AppSettings? = null,
) {
    companion object {
        const val PLATFORM = "android"
    }
}

/** Thrown with something a person can act on, never a decoder's own words. */
class BackupException(message: String) : Exception(message)

private val backupJson = Json {
    prettyPrint = true
    encodeDefaults = true
    ignoreUnknownKeys = true
}

/**
 * Everything, including archived rules — a backup that quietly dropped the
 * rules someone had stopped keeping would lose exactly the history the app
 * exists to hold.
 */
fun Store.exportBackup(now: Instant = Instant.now()): Backup = Backup(
    exportedAt = now,
    rules = rules(includeArchived = true),
    activations = activations(),
    occurrences = occurrences(),
    settings = loadSettings(),
)

fun Store.exportJson(now: Instant = Instant.now()): String =
    backupJson.encodeToString(Backup.serializer(), exportBackup(now))

/**
 * Merges a backup in. Nothing already here is removed — a restore that silently
 * wiped a month of record would be far worse than a duplicate. Rules are keyed
 * by id, so restoring the same file twice is not destructive either.
 */
fun Store.importBackup(backup: Backup) {
    for (rule in backup.rules) save(rule)
    for (activation in backup.activations) save(activation)
    for (occurrence in backup.occurrences) save(occurrence)
    backup.settings?.let { saveSettings(it) }
}

/**
 * Reads a backup, refusing anything it cannot restore faithfully.
 *
 * A half-applied restore is the worst outcome available here, so every reason
 * to stop is checked before a single row is written.
 */
fun Store.importJson(text: String) {
    val backup = try {
        backupJson.decodeFromString(Backup.serializer(), text)
    } catch (e: Exception) {
        throw BackupException("That file is not a Chotki backup.")
    }
    if (backup.platform != Backup.PLATFORM) {
        throw BackupException(
            "That backup came from Chotki on ${backup.platform}, and the two " +
                "store their rules differently. It cannot be restored here.",
        )
    }
    if (backup.version > 1) {
        throw BackupException(
            "That backup was written by a newer version of Chotki. Update the " +
                "app and try again.",
        )
    }
    importBackup(backup)
}
