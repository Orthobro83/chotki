package org.chotki.core

import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Translated from Swift's "Scripture text and paragraphs". */
class ScriptureTextTest {

    private fun verse(chapter: Int, number: Int, text: String, book: String = "MAT", opens: Boolean = false) =
        ScriptureText.Verse(book, chapter, number, text, opens)

    @Test
    fun `verses run on with a space, and a paragraph opener gets a blank line`() {
        val text = ScriptureText.join(
            listOf(
                verse(1, 1, "One.", opens = true), verse(1, 2, "Two."),
                verse(1, 3, "Three.", opens = true), verse(1, 4, "Four."),
            ),
        )
        assertEquals("One. Two.\n\nThree. Four.", text)
    }

    @Test
    fun `the first verse never gets a break, and an empty list is empty`() {
        assertEquals("Alone.", ScriptureText.join(listOf(verse(5, 1, "Alone.", opens = true))))
        assertEquals("", ScriptureText.join(emptyList()))
    }

    @Test
    fun `separate passages do not run together, but a chapter's last verse flows into the next chapter`() {
        assertEquals("A.\n\nB.", ScriptureText.join(listOf(verse(1, 1, "A."), verse(1, 5, "B."))))
        assertEquals("A. B.", ScriptureText.join(listOf(verse(1, 30, "A."), verse(2, 1, "B."))))
        assertEquals("A.\n\nB.", ScriptureText.join(listOf(verse(1, 1, "A."), verse(1, 2, "B.", book = "MRK"))))
    }

    @Test
    fun `the bundled Bible has every verse, and the paragraph openers its source marks`() {
        assertEquals(36_820, ScriptureText.Bible.verseCount)
        // Matthew 11:28 opens a paragraph in the source; verse 29 does not.
        assertEquals(true, ScriptureText.Bible.verse("MAT", 11, 28)?.opensParagraph)
        assertEquals(false, ScriptureText.Bible.verse("MAT", 11, 29)?.opensParagraph)
        assertTrue(ScriptureText.Bible.verse("MAT", 11, 28)?.text?.startsWith("Come unto me") == true)
    }

    @Test
    fun `no pilcrow reaches the text`() {
        val text = assertNotNull(ScriptureText.text(listOf(PassageRun("LUK", 6, 17, 20))))
        assertFalse(text.contains("¶"))
        assertTrue(text.startsWith("And he came down with them"))
    }

    @Test
    fun `a run with a verse the Bible does not have yields no text, not wrong text`() {
        assertNull(ScriptureText.text(listOf(PassageRun("JHN", 3, 1, 400))))
        assertNull(ScriptureText.text(listOf(PassageRun("XXX", 1, 1, 1))))
        assertNull(ScriptureText.text(emptyList()))
    }

    @Test
    fun `a run is stored as a four-item array`() {
        val element = Json.parseToJsonElement("""[["PRO",10,1,32],["WIS",6,1,25]]""")
        val runs = (element as kotlinx.serialization.json.JsonArray).map(PassageRun::from)
        assertEquals(listOf(PassageRun("PRO", 10, 1, 32), PassageRun("WIS", 6, 1, 25)), runs)
    }

    @Test
    fun `all twenty-two Composite readings resolve to scripture`() {
        val table = ScriptureText.Bible.composites
        assertEquals(22, table.size)
        for ((display, runs) in table) {
            val text = assertNotNull(ScriptureText.text(runs), display)
            assertTrue(text.isNotEmpty())
        }
        // Composite 12 cites 3 [1] Kings 17.1-23, which is 1 Kings in the KJV and is 23 verses.
        assertEquals(listOf(PassageRun("1KI", 17, 1, 23)), table["Composite 12 - 3 [1] Kings 17.1-23"])
        // 3 [1] Kings is not 1 Samuel: an earlier draft resolved it there by mistake.
        assertTrue(table.values.flatten().all { it.book != "1SA" && it.book != "2SA" })
    }
}
