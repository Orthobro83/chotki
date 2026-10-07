package org.chotki.core.liturgical

/**
 * The single seam between this app and the network.
 *
 * Everything above it is testable offline, which is why the whole liturgical
 * suite runs against recorded fixtures and CI never makes a request. It is also
 * why `:core` needs no HTTP library: Android supplies one implementation of this
 * and the tests supply another, exactly as with the database.
 */
fun interface HttpFetching {
    fun data(url: String): String

    companion object {
        /**
         * Says who is asking. orthocal.info is a small service run by one person, and its maintainer
         * is owed a way to tell which app a request came from and where to find it. A public
         * project address, not a personal one.
         */
        const val USER_AGENT = "Chotki (+https://github.com/Orthobro83/chotki)"
    }
}

sealed class HttpException(message: String) : Exception(message) {
    class Status(val code: Int) : HttpException("HTTP $code")
    class Transport(val detail: String) : HttpException(detail)
}
