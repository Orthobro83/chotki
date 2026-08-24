package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Phase 1 only: that the toolchain builds, and builds the right thing. */
class ScaffoldTest {

    @Test
    fun `the module compiles and tests run`() {
        assertTrue(Chotki.SPECIFICATION.isNotEmpty())
    }

    /**
     * Reads the major version out of this module's own compiled bytecode.
     *
     * `:core` becomes a dependency of an Android module at phase 9, and Android
     * will not load classes built for a newer JVM than it accepts. Compiling on
     * whatever JDK happens to be installed would pass here and fail there —
     * months later, in the one phase that is hardest to debug. 61 is Java 17.
     */
    @Test
    fun `bytecode targets Java 17`() {
        val classFile = Chotki::class.java
            .getResourceAsStream("/${Chotki::class.java.name.replace('.', '/')}.class")
            ?.readBytes()
        requireNotNull(classFile) { "could not read the compiled class" }

        // magic (4 bytes), minor (2), major (2)
        val major = ((classFile[6].toInt() and 0xFF) shl 8) or (classFile[7].toInt() and 0xFF)
        assertEquals(61, major, "expected Java 17 bytecode, got major version $major")
    }
}
