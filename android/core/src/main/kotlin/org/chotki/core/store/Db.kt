package org.chotki.core.store

/**
 * The whole of what the store needs from a database.
 *
 * Four methods, so that `:core` can hold the schema, the migrations and every
 * query without depending on a driver — and therefore without depending on
 * Android. The tests implement this over JDBC and Android implements it over its
 * own SQLite, and both run the same SQL.
 *
 * Values are bound as strings throughout, which is what the schema stores: dates
 * are ISO text so they sort lexicographically, and structured fields are JSON.
 */
interface Db {
    fun execute(sql: String)

    fun update(sql: String, args: List<String?> = emptyList())

    fun <T> query(sql: String, args: List<String?> = emptyList(), read: (Row) -> T): List<T>

    /**
     * Runs [body] in a transaction, rolling back if it throws.
     *
     * This is why a three-way edit is atomic. A split that closed the old
     * stretch and failed to open the new one would make a rule silently vanish.
     */
    fun <T> transaction(body: () -> T): T

    fun close()
}

/** One row, read by column index. */
interface Row {
    fun string(index: Int): String?
    fun int(index: Int): Int?
}
