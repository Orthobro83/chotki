package org.chotki.core

import java.time.Instant

/**
 * Where "now" comes from, so that everything downstream of it can be tested.
 *
 * Named for the Swift original. Note it is not `java.time.Clock`; nothing here
 * should import that by accident.
 */
interface Clock {
    val now: Instant
}

class SystemClock : Clock {
    override val now: Instant get() = Instant.now()
}

/** A clock that stands still, and moves only when told to. */
class FixedClock(private var current: Instant) : Clock {
    override val now: Instant
        @Synchronized get() = current

    @Synchronized
    fun set(instant: Instant) {
        current = instant
    }

    @Synchronized
    fun advance(seconds: Long) {
        current = current.plusSeconds(seconds)
    }
}
