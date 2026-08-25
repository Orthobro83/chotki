package org.chotki.core.content

import org.chotki.core.Tradition
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * The glossary, as macOS has always had it.
 *
 * Android listed every entry in file order, scoped to nothing, linked from
 * nowhere — so a term that was present could not be found, and the report was
 * that it was missing.
 */
class GlossaryTest {

    private val glossary = Glossary.SHARED

    @Test fun `every bundled term is there`() {
        assertEquals(Content.glossary.size, glossary.entries.size)
        assertNotNull(glossary.entry("theotokos"), "Theotokos is not in the glossary")
    }

    @Test fun `the list is alphabetical, not the order of the file`() {
        val terms = glossary.entries.map { it.term.lowercase() }
        assertEquals(terms.sorted(), terms, "the glossary is in file order")
    }

    @Test fun `every entry lands in a category, and the categories are ordered`() {
        val grouped = glossary.byCategory
        assertEquals(glossary.entries.size, grouped.sumOf { it.second.size }, "an entry has no category")
        val known = grouped.map { it.first }.filter { it in Glossary.CATEGORY_ORDER }
        assertEquals(known.sortedBy(Glossary.CATEGORY_ORDER::indexOf), known)
    }

    @Test fun `scoping keeps the universal terms and drops what belongs elsewhere`() {
        val georgian = Glossary.shared(Tradition.GEORGIAN)
        assertNotNull(georgian.entry("theotokos"), "a universal term was scoped away")
        assertTrue(georgian.entries.size <= glossary.entries.size)

        // Nothing may point at an entry the reader cannot open.
        val slugs = georgian.entries.map { it.slug }.toSet()
        for (entry in georgian.entries) {
            for (slug in entry.related) {
                assertTrue(slug in slugs, "${entry.term} links to $slug, which is scoped out")
            }
        }
    }

    @Test fun `a term is found in running text`() {
        val found = glossary.scan("A hymn to the Theotokos.")
        assertTrue(found.any { it.slug == "theotokos" }, "found ${found.map { it.slug }}")
    }

    /**
     * "Major Feast of the Theotokos" is an alias of Great Feast, and it is
     * longer than "Theotokos", so the phrase wins whole. That is right — the
     * phrase is the thing being named — and it is worth pinning, because the
     * first version of the test above used that very sentence and read the
     * correct behaviour as a failure to find Theotokos.
     */
    @Test fun `a phrase beats the word inside it`() {
        val found = glossary.scan("The Major Feast of the Theotokos falls this week.")
        assertEquals(listOf("great-feast"), found.map { it.slug })
    }

    /** "Great Feast" must win over "Feast", or the longer term never appears. */
    @Test fun `the longest term wins`() {
        val found = glossary.scan("A Great Feast today.")
        val matched = found.map { it.matchedText.lowercase() }
        assertTrue(matched.any { it == "great feast" }, "matched $matched")
    }

    /** Matches sit on word boundaries, or every "so" inside "person" links. */
    @Test fun `a term inside a longer word is not a match`() {
        assertTrue(glossary.scan("Theotokoses").none { it.matchedText.length < "Theotokoses".length })
        assertTrue(glossary.scan("xxtonexx").isEmpty(), "matched inside a word")
    }

    @Test fun `matches never overlap`() {
        for (text in listOf("Great Feast of the Theotokos", "Vespers and Matins", "the Divine Liturgy")) {
            val ranges = glossary.scan(text).map { it.range }
            for (a in ranges.indices) for (b in a + 1 until ranges.size) {
                val one = ranges[a]; val two = ranges[b]
                assertTrue(one.last < two.first || two.last < one.first, "overlap in \"$text\"")
            }
        }
    }

    /** A rule is read straight through, so a term links once across the run. */
    @Test fun `a term is linked once across a run of prayers`() {
        val runs = glossary.scanOnce(
            listOf("Glory to the Theotokos.", "Again, the Theotokos.", "And the Theotokos."),
        )
        assertEquals(1, runs.sumOf { paragraph -> paragraph.count { it.slug == "theotokos" } })
    }
}
