package org.chotki.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Translated from suites "Jurisdiction and tradition" and "Glossary scoping". */
class JurisdictionTest {

    // Reckoning and tradition do not track together, which is the reason they
    // are separate axes at all.
    @Test
    fun `the calendar and the practice family are independent`() {
        val oca = Jurisdiction.KNOWN.first { it.name == "Orthodox Church in America" }
        assertEquals(Reckoning.REVISED_JULIAN, oca.reckoning)
        assertEquals(Tradition.RUSSIAN, oca.tradition, "New Calendar, Russian practice")

        val georgian = Jurisdiction.KNOWN.first { it.name == "Georgian Orthodox Church" }
        assertEquals(Reckoning.JULIAN, georgian.reckoning)
        assertEquals(Tradition.GEORGIAN, georgian.tradition, "Old Calendar, its own usages")
    }

    @Test
    fun `every jurisdiction offered has a name, a calendar and a tradition`() {
        assertTrue(Jurisdiction.KNOWN.size >= 16)
        assertEquals(
            Jurisdiction.KNOWN.size,
            Jurisdiction.KNOWN.map { it.name }.toSet().size,
            "two jurisdictions share a name",
        )
        for (jurisdiction in Jurisdiction.KNOWN) {
            assertTrue(jurisdiction.name.isNotEmpty())
            assertTrue(jurisdiction.practice.notes.isNotEmpty(), jurisdiction.name)
        }
    }

    @Test
    fun `both calendars are represented among the churches offered`() {
        val reckonings = Jurisdiction.KNOWN.map { it.reckoning }.toSet()
        assertEquals(Reckoning.entries.toSet(), reckonings)
    }

    @Test
    fun `a jurisdiction takes its tradition's customary practice`() {
        for (tradition in Tradition.entries) {
            val jurisdiction = Jurisdiction.of("Somewhere", Reckoning.JULIAN, tradition)
            assertEquals(PracticeProfile.customary(tradition), jurisdiction.practice)
            assertTrue(!jurisdiction.confessionNormDiffersFromTradition)
        }
    }

    @Test
    fun `practice can be set away from the tradition's norm`() {
        val adjusted = Jurisdiction.of(
            "My parish", Reckoning.JULIAN, Tradition.RUSSIAN,
            practice = PracticeProfile(confession = ConfessionNorm.PERIODIC),
        )
        assertTrue(adjusted.confessionNormDiffersFromTradition)
    }

    // Descriptive, never instructing: every note says what is customary and
    // where the answer actually comes from.
    @Test
    fun `every practice note points at a priest rather than a rule`() {
        for (tradition in Tradition.entries) {
            val notes = PracticeProfile.customary(tradition).notes.joinToString(" ").lowercase()
            assertTrue(
                notes.contains("priest") || notes.contains("varies"),
                "$tradition asserts practice without saying who decides it",
            )
            for (word in listOf("must", "required to", "you should", "obliged")) {
                assertTrue(!notes.contains(word), "$tradition instructs: $word")
            }
        }
    }

    @Test
    fun `the Slavic traditions are the Slavic ones`() {
        assertTrue(Tradition.RUSSIAN.isSlavic)
        assertTrue(Tradition.SERBIAN.isSlavic)
        assertTrue(Tradition.BULGARIAN.isSlavic)
        assertTrue(!Tradition.GREEK.isSlavic)
        assertTrue(!Tradition.GEORGIAN.isSlavic, "Georgian is Caucasian, not Slavic")
        assertTrue(!Tradition.ROMANIAN.isSlavic, "Romanian is a Latin language")
    }

    @Test
    fun `the two confession norms read as description`() {
        for (norm in ConfessionNorm.entries) {
            assertTrue(norm.summary.startsWith("Confession"))
            assertTrue(!norm.summary.contains("must"))
        }
    }

    // MARK: setting the calendar apart from the church

    @Test
    fun `a known jurisdiction kept as it ships differs from nothing`() {
        for (jurisdiction in Jurisdiction.KNOWN) {
            assertTrue(!jurisdiction.reckoningDiffersFromJurisdiction, jurisdiction.name)
        }
    }

    @Test
    fun `changing only the calendar is recorded as a difference`() {
        val rocor = Jurisdiction.DEFAULT
        assertEquals(Reckoning.JULIAN, rocor.reckoning)

        val moved = rocor.copy(reckoning = Reckoning.REVISED_JULIAN)
        assertTrue(moved.reckoningDiffersFromJurisdiction)
        assertEquals(Tradition.RUSSIAN, moved.tradition, "the practice family is untouched")
    }

    @Test
    fun `setting it back stops it being a difference`() {
        val there = Jurisdiction.DEFAULT.copy(reckoning = Reckoning.REVISED_JULIAN)
        assertTrue(!there.copy(reckoning = Reckoning.JULIAN).reckoningDiffersFromJurisdiction)
    }

    // Someone may name their own parish rather than pick from the list.
    @Test
    fun `a jurisdiction the app does not know differs from nothing`() {
        val mine = Jurisdiction.of(
            "St Nicholas, somewhere", Reckoning.REVISED_JULIAN, Tradition.RUSSIAN,
        )
        assertTrue(!mine.reckoningDiffersFromJurisdiction)
        assertNull(mine.asShipped)
    }

    @Test
    fun `both calendars reach the right orthocal endpoint`() {
        assertEquals("julian", Reckoning.JULIAN.endpointPath)
        assertEquals("gregorian", Reckoning.REVISED_JULIAN.endpointPath)
        assertEquals(2, Reckoning.entries.size)
    }
}

/**
 * The churches and their customary practice, read from the shared content.
 *
 * These were hand-copied into Kotlin once, and the first change to the wording
 * went into Swift alone — the Android app went on saying the old thing until a
 * grep found it. They are generated now, and these are the tests that would have
 * caught it.
 */
class SharedPracticeContentTest {

    @Test
    fun `every tradition has a customary profile in the content`() {
        for (tradition in Tradition.entries) {
            val profile = PracticeProfile.customary(tradition)
            assertTrue(profile.notes.isNotEmpty(), "$tradition has no notes")
        }
    }

    @Test
    fun `the churches come from the content, not from a copy`() {
        assertEquals(16, Jurisdiction.KNOWN.size)
        assertTrue(Jurisdiction.KNOWN.any { it.name == "Georgian Orthodox Church" })
        assertTrue(Jurisdiction.KNOWN.any { it.name == "Orthodox Church in America" })
    }

    // The change that exposed the divergence: practice is settled with a priest
    // *or spiritual father*, and both platforms must say so.
    @Test
    fun `practice notes name the spiritual father as well as the priest`() {
        val mentioning = Tradition.entries
            .flatMap { PracticeProfile.customary(it).notes }
            .filter { it.contains("priest", ignoreCase = true) }

        assertTrue(mentioning.isNotEmpty(), "no note mentions a priest at all")
        for (note in mentioning) {
            assertTrue(
                note.contains("priest or spiritual father"),
                "a note still says priest alone: $note",
            )
        }
    }

    @Test
    fun `the notes describe rather than instruct`() {
        for (tradition in Tradition.entries) {
            val notes = PracticeProfile.customary(tradition).notes.joinToString(" ").lowercase()
            for (word in listOf("you must", "required to", "you should", "obliged")) {
                assertTrue(!notes.contains(word), "$tradition instructs: $word")
            }
        }
    }
}
