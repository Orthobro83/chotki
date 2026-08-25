package org.chotki.app.platform

import org.chotki.core.liturgical.HttpException
import org.chotki.core.liturgical.HttpFetching
import java.net.HttpURLConnection
import java.net.URL

/**
 * The one place this app touches the network.
 *
 * `HttpURLConnection` rather than a library: this makes one kind of request to
 * one host and reads JSON back. A dependency would be more code to keep current,
 * not less code to write.
 *
 * Never called on the main thread — [org.chotki.app.AppState] refreshes the
 * calendar on a background thread, and Android would throw
 * `NetworkOnMainThreadException` if it did otherwise.
 */
class AndroidHttp(private val timeoutMillis: Int = 20_000) : HttpFetching {

    override fun data(url: String): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = timeoutMillis
            readTimeout = timeoutMillis
            setRequestProperty("User-Agent", "chotki")
        }
        try {
            val code = connection.responseCode
            if (code !in 200..299) throw HttpException.Status(code)
            return connection.inputStream.bufferedReader().readText()
        } catch (failure: HttpException) {
            throw failure
        } catch (failure: Exception) {
            throw HttpException.Transport(failure.message ?: failure.toString())
        } finally {
            connection.disconnect()
        }
    }
}
