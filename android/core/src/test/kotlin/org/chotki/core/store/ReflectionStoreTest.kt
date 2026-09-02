package org.chotki.core.store

import org.chotki.core.CalendarDate
import org.chotki.core.Weekday
import org.chotki.core.reflections.Reflection
import org.chotki.core.reflections.ReflectionArchive
import org.chotki.core.reflections.ReflectionEntry
import org.chotki.core.reflections.ReflectionImportException
import org.chotki.core.reflections.ReflectionQuestion
import org.chotki.core.reflections.bundled
import java.time.Instant
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun d(y: Int, m: Int, day: Int): CalendarDate = CalendarDate.of(y, m, day)!!

class ReflectionStoreTest {

    private val db = JdbcDb.inMemory()
    private val store = SqliteStore(db)

    @AfterTest fun tearDown() = db.close()

    @Test fun `a reflection survives a round trip with every field intact`() {
        val edited = Instant.parse("2026-06-08T12:00:00Z")
        val reflection = Reflection(
            weekday = Weekday.THURSDAY,
            question = ReflectionQuestion("Notice the Pattern", "what keeps showing up", "write it down"),
            editedAt = edited,
        )
        store.save(reflection)

        val back = store.reflections()
        assertEquals(1, back.size)
        assertEquals(Weekday.THURSDAY, back.first().weekday)
        assertEquals(reflection.question, back.first().question)
        assertEquals(edited, back.first().editedAt)
    }

    @Test fun `saving a weekday twice rewrites it rather than adding a second`() {
        val sunday = Reflection.bundled(Weekday.SUNDAY)
        store.save(sunday)
        store.save(sunday.rewritten(ReflectionQuestion("Mine", "n", "t")))

        assertEquals(1, store.reflections().size)
        assertEquals("Mine", store.reflections().first().title)
        assertTrue(store.reflections().first().isEdited)
    }

    @Test fun `they come back in weekday order`() {
        Reflection.bundled.reversed().forEach { store.save(it) }
        assertEquals(Weekday.entries.toList(), store.reflections().map { it.weekday })
    }

    // MARK: seeding

    @Test fun `seeding puts all seven in place`() {
        assertTrue(store.reflections().isEmpty())
        assertEquals(7, store.seedReflections().size)
        assertEquals(7, store.reflections().size)
        assertEquals("Notice the Resistance", store.reflection(Weekday.SUNDAY).title)
    }

    @Test fun `seeding twice adds nothing the second time`() {
        store.seedReflections()
        assertTrue(store.seedReflections().isEmpty())
        assertEquals(7, store.reflections().size)
    }

    /** Seeding runs on every launch, so it must be incapable of undoing an edit. */
    @Test fun `seeding never overwrites a question the user has rewritten`() {
        store.seedReflections()
        store.save(Reflection.bundled(Weekday.FRIDAY)
            .rewritten(ReflectionQuestion("My own Friday", "n", "t")))

        store.seedReflections()

        assertEquals("My own Friday", store.reflection(Weekday.FRIDAY).title)
        assertEquals(7, store.reflections().size)
    }

    @Test fun `seeding fills a gap without touching the rest`() {
        Reflection.bundled.filter { it.weekday != Weekday.TUESDAY }.forEach { store.save(it) }
        assertEquals(listOf(Weekday.TUESDAY), store.seedReflections().map { it.weekday })
        assertEquals(7, store.reflections().size)
    }

    // MARK: answers

    @Test fun `an answer survives a round trip, question and all`() {
        val written = Instant.parse("2026-09-06T20:00:00Z")
        val entry = ReflectionEntry.answering(
            Reflection.bundled(Weekday.SUNDAY), d(2026, 9, 6),
            "It came up first thing.", writtenAt = written)
        store.save(entry)

        val back = store.reflectionEntries()
        assertEquals(1, back.size)
        assertEquals(entry.id, back.first().id)
        assertEquals(Weekday.SUNDAY, back.first().weekday)
        assertEquals(d(2026, 9, 6), back.first().date)
        assertEquals("It came up first thing.", back.first().text)
        assertEquals(Reflection.bundled(Weekday.SUNDAY).question, back.first().question)
        assertEquals(written, back.first().writtenAt)
    }

    /**
     * The snapshot at the storage layer: an answer keeps the words it was
     * written against even after the question is rewritten underneath it.
     */
    @Test fun `rewriting a question does not change an answer already stored`() {
        store.seedReflections()
        val sunday = store.reflection(Weekday.SUNDAY)
        store.save(ReflectionEntry.answering(sunday, d(2026, 9, 6), "then"))

        store.save(sunday.rewritten(ReflectionQuestion("Rewritten", "new", "new")))

        assertEquals("Notice the Resistance",
            store.reflectionEntries(weekday = Weekday.SUNDAY).first().question.title)
        assertEquals("Rewritten", store.reflection(Weekday.SUNDAY).title)
    }

    @Test fun `one answer per weekday per date`() {
        val sunday = Reflection.bundled(Weekday.SUNDAY)
        store.save(ReflectionEntry.answering(sunday, d(2026, 9, 6), "first"))
        store.save(ReflectionEntry.answering(sunday, d(2026, 9, 6), "second"))

        assertEquals(1, store.reflectionEntries().size)
        assertEquals("second", store.reflectionEntries().first().text)
    }

    @Test fun `answers come back newest first`() {
        val sunday = Reflection.bundled(Weekday.SUNDAY)
        listOf(6, 20, 13).forEach {
            store.save(ReflectionEntry.answering(sunday, d(2026, 9, it), "$it"))
        }
        assertEquals(listOf(20, 13, 6), store.reflectionEntries().map { it.date.day })
    }

    @Test fun `they can be narrowed by weekday and by date`() {
        store.save(ReflectionEntry.answering(
            Reflection.bundled(Weekday.SUNDAY), d(2026, 9, 6), "s"))
        store.save(ReflectionEntry.answering(
            Reflection.bundled(Weekday.SUNDAY), d(2026, 9, 13), "s2"))
        store.save(ReflectionEntry.answering(
            Reflection.bundled(Weekday.WEDNESDAY), d(2026, 9, 9), "w"))

        assertEquals(2, store.reflectionEntries(weekday = Weekday.SUNDAY).size)
        assertEquals(1, store.reflectionEntries(weekday = Weekday.WEDNESDAY).size)
        assertEquals(2, store.reflectionEntries(from = d(2026, 9, 9)).size)
        assertEquals(2, store.reflectionEntries(through = d(2026, 9, 9)).size)
        assertEquals(1, store.reflectionEntries(from = d(2026, 9, 7), through = d(2026, 9, 12)).size)
    }

    // MARK: the journal as a file

    @Test fun `export and import round trip`() {
        store.seedReflections()
        store.save(ReflectionEntry.answering(store.reflection(Weekday.SUNDAY), d(2026, 9, 6), "one"))
        store.save(ReflectionEntry.answering(store.reflection(Weekday.FRIDAY), d(2026, 9, 4), "two"))
        val text = store.exportReflectionsJson()

        val freshDb = JdbcDb.inMemory()
        val fresh = SqliteStore(freshDb)
        val result = fresh.importReflectionsJson(text)

        assertEquals(2, result.addedCount)
        assertEquals(0, result.alreadyPresent)
        assertEquals(7, fresh.reflections().size)
        assertEquals(2, fresh.reflectionEntries().size)
        freshDb.close()
    }

    @Test fun `importing the same file twice changes nothing the second time`() {
        store.seedReflections()
        store.save(ReflectionEntry.answering(store.reflection(Weekday.SUNDAY), d(2026, 9, 6), "one"))
        val text = store.exportReflectionsJson()

        val second = store.importReflectionsJson(text)
        assertEquals(0, second.addedCount)
        assertEquals(1, second.alreadyPresent)
        assertEquals(1, store.reflectionEntries().size)
    }

    /**
     * An import is additive. A file from a stale export must never be able to
     * overwrite an answer written since.
     */
    @Test fun `an import never overwrites an answer already held`() {
        store.seedReflections()
        val sunday = store.reflection(Weekday.SUNDAY)
        store.save(ReflectionEntry.answering(sunday, d(2026, 9, 6), "mine"))

        val stale = ReflectionArchive(entries = listOf(
            ReflectionEntry.answering(sunday, d(2026, 9, 6), "theirs"),
            ReflectionEntry.answering(sunday, d(2026, 9, 13), "new one"),
        ))
        val result = store.importReflections(stale)

        assertEquals(1, result.addedCount)
        assertEquals(1, result.alreadyPresent)
        assertEquals("mine",
            store.reflectionEntries(from = d(2026, 9, 6), through = d(2026, 9, 6)).first().text)
    }

    /** An import must not be able to undo an edit either. */
    @Test fun `an import never rewrites a question this record already holds`() {
        store.seedReflections()
        store.save(store.reflection(Weekday.SUNDAY)
            .rewritten(ReflectionQuestion("My own Sunday", "n", "t")))

        store.importReflections(ReflectionArchive(reflections = Reflection.bundled))

        assertEquals("My own Sunday", store.reflection(Weekday.SUNDAY).title)
    }

    // MARK: the web artifact's journal

    /**
     * The artifact's shape: `days` keyed "1"…"7" by position in the cycle,
     * entries carrying no question because on the web the seven were fixed.
     */
    private val legacy = """
        {
          "days": {
            "1": [{"date": "2026-08-30", "text": "It came up first thing."},
                  {"date": "2026-08-23", "text": "Less this week."}],
            "4": [{"date": "2026-08-26", "text": "Put off the call again."}]
          },
          "reflections": [{"date": "2026-08-31", "text": "a pass", "deep": false}],
          "dismissed": false
        }
    """.trimIndent()

    /**
     * On the web the seven were a cycle rather than a week, so an entry is
     * filed under the weekday it was actually written on and keeps the question
     * it actually answered. 30 August 2026 was a Sunday.
     */
    @Test fun `a legacy entry is filed by its date and keeps its question`() {
        store.seedReflections()
        val result = store.importReflectionsJson(legacy)
        assertEquals(3, result.addedCount)

        val aug30 = store.reflectionEntries(from = d(2026, 8, 30), through = d(2026, 8, 30)).first()
        assertEquals(Weekday.SUNDAY, aug30.weekday)
        assertEquals("Notice the Resistance", aug30.question.title)
    }

    @Test fun `blank and unreadable legacy entries are skipped`() {
        val messy = """
            {"days": {"1": [{"date": "2026-08-30", "text": "   "},
                            {"date": "not-a-date", "text": "x"},
                            {"date": "2026-08-23", "text": "kept"}],
                      "9": [{"date": "2026-08-16", "text": "no such day"}]}}
        """.trimIndent()
        store.seedReflections()
        assertEquals(1, store.importReflectionsJson(messy).addedCount)
        assertEquals("kept", store.reflectionEntries().first().text)
    }

    @Test fun `a file that is neither shape is refused and nothing is touched`() {
        store.seedReflections()
        store.save(ReflectionEntry.answering(store.reflection(Weekday.SUNDAY), d(2026, 9, 6), "mine"))

        assertFailsWith<ReflectionImportException> {
            store.importReflectionsJson("""{"something": 1}""")
        }
        assertEquals(1, store.reflectionEntries().size)
    }
}
