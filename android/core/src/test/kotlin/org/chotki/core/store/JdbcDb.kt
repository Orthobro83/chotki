package org.chotki.core.store

import java.sql.Connection
import java.sql.DriverManager

/**
 * A [Db] over JDBC, for the tests.
 *
 * This is why the schema, the migration ladder and every query are exercised on
 * an actual SQLite database on every CI run, without `:core` depending on a
 * driver — and therefore without depending on Android. The Android
 * implementation of this interface is four methods long and contains no logic to
 * get wrong.
 */
class JdbcDb(path: String) : Db {

    private val connection: Connection =
        DriverManager.getConnection("jdbc:sqlite:$path")

    companion object {
        fun inMemory(): JdbcDb = JdbcDb(":memory:")
    }

    override fun execute(sql: String) {
        connection.createStatement().use { statement ->
            // Several statements per migration step, which JDBC will not take in
            // one call.
            for (part in sql.split(';')) {
                if (part.isBlank()) continue
                statement.execute(part)
            }
        }
    }

    override fun update(sql: String, args: List<String?>) {
        connection.prepareStatement(sql).use { statement ->
            args.forEachIndexed { index, value -> statement.setString(index + 1, value) }
            statement.executeUpdate()
        }
    }

    override fun <T> query(sql: String, args: List<String?>, read: (Row) -> T): List<T> {
        connection.prepareStatement(sql).use { statement ->
            args.forEachIndexed { index, value -> statement.setString(index + 1, value) }
            val results = statement.executeQuery()
            val rows = mutableListOf<T>()
            val row = object : Row {
                override fun string(index: Int): String? = results.getString(index + 1)
                override fun int(index: Int): Int? {
                    val value = results.getInt(index + 1)
                    return if (results.wasNull()) null else value
                }
            }
            while (results.next()) rows.add(read(row))
            return rows
        }
    }

    override fun <T> transaction(body: () -> T): T {
        connection.autoCommit = false
        return try {
            val result = body()
            connection.commit()
            result
        } catch (failure: Throwable) {
            connection.rollback()
            throw failure
        } finally {
            connection.autoCommit = true
        }
    }

    override fun close() = connection.close()
}
