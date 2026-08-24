package org.chotki.app.platform

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.chotki.core.store.Db
import org.chotki.core.store.Row
import java.io.File

/**
 * [Db] over Android's own SQLite.
 *
 * Four methods and no logic, which is the point: the schema, the six-step
 * migration ladder and every query live in `:core`, where they are exercised on
 * a real database in CI without `:core` knowing what a driver is. This is the
 * whole of the Android database layer.
 *
 * No bundled SQLite, so no native library — which also sidesteps the 16 KB
 * page-size alignment requirement newer devices enforce.
 */
class AndroidDb(private val db: SQLiteDatabase) : Db {

    companion object {
        /**
         * The live database, beside the app's own data.
         *
         * WAL is turned on by `:core` rather than here, so both platforms make
         * the same promise about durability — and so a file copy that forgets
         * `-wal` and `-shm` loses recent writes in exactly the same way, which
         * has bitten once already.
         */
        fun open(context: Context, name: String = "chotki.sqlite"): AndroidDb {
            val file = File(context.filesDir, name)
            return AndroidDb(SQLiteDatabase.openOrCreateDatabase(file, null))
        }

        fun inMemory(): AndroidDb = AndroidDb(SQLiteDatabase.create(null))
    }

    override fun execute(sql: String) {
        // Several statements per migration step, which execSQL will not take in
        // one call.
        for (part in sql.split(';')) {
            if (part.isBlank()) continue
            // execSQL refuses anything that returns rows, and `PRAGMA
            // journal_mode=WAL` answers with "wal" — so turning WAL on threw,
            // and took every store operation with it. JDBC tolerates the same
            // statement silently, which is exactly why this had to be run on a
            // device to be found.
            if (part.trimStart().startsWith("PRAGMA", ignoreCase = true)) {
                db.rawQuery(part, null).use { it.moveToFirst() }
            } else {
                db.execSQL(part)
            }
        }
    }

    override fun update(sql: String, args: List<String?>) {
        db.compileStatement(sql).use { statement ->
            args.forEachIndexed { index, value ->
                if (value == null) statement.bindNull(index + 1) else statement.bindString(index + 1, value)
            }
            statement.executeUpdateDelete()
        }
    }

    override fun <T> query(sql: String, args: List<String?>, read: (Row) -> T): List<T> {
        // rawQuery binds everything as a string, which is what the schema
        // stores: dates as ISO text so they sort, structured fields as JSON.
        db.rawQuery(sql, args.toTypedArray()).use { cursor ->
            val rows = mutableListOf<T>()
            val row = object : Row {
                override fun string(index: Int): String? =
                    if (cursor.isNull(index)) null else cursor.getString(index)

                override fun int(index: Int): Int? =
                    if (cursor.isNull(index)) null else cursor.getInt(index)
            }
            while (cursor.moveToNext()) rows.add(read(row))
            return rows
        }
    }

    override fun <T> transaction(body: () -> T): T {
        db.beginTransaction()
        return try {
            val result = body()
            db.setTransactionSuccessful()
            result
        } finally {
            db.endTransaction()
        }
    }

    override fun close() = db.close()
}
