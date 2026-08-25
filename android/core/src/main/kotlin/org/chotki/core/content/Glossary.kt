package org.chotki.core.content

import org.chotki.core.Tradition

/** Where a term sits in running text. */
data class TermMatch(val range: IntRange, val slug: String, val matchedText: String)

/**
 * The terms, scoped to a tradition and findable in running text.
 *
 * A direct translation of the Swift `Glossary`, and held to it by
 * `GlossaryParityTest`. The Android app had none of this: it listed all 111
 * entries in the order they happen to sit in the file, scoped to nothing and
 * linked from nowhere. Everything was present and nothing could be found, which
 * is why the report was that Theotokos was missing.
 */
class Glossary(entries: List<GlossaryEntryJson> = Content.glossary) {

    /** Alphabetical, which is the order a list of terms wants to be in. */
    val entries: List<GlossaryEntryJson> = entries.sortedBy { it.term.lowercase() }

    private val bySlug: Map<String, GlossaryEntryJson> = entries.associateBy { it.slug }

    private val byNeedle: Map<String, String> = buildMap {
        for (entry in entries) {
            for (name in listOf(entry.term) + entry.aliases) {
                // First writer wins, so a term is never stolen by another
                // entry's alias.
                putIfAbsent(name.lowercase(), entry.slug)
            }
        }
    }

    /** Longest first, so "Great Feast" wins over "Feast". */
    private val needlesByLength: List<String> =
        byNeedle.keys.sortedWith(compareByDescending<String> { it.length }.thenByDescending { it })

    fun entry(slug: String): GlossaryEntryJson? = bySlug[slug]

    /**
     * Universal terms are always kept; tradition-specific ones appear only for
     * the traditions they belong to.
     *
     * Cross-references are pruned to what survives, so nothing can link to an
     * entry the reader cannot open.
     */
    fun scoped(tradition: Tradition): Glossary {
        val kept = entries.filter { it.modelTraditions.isEmpty() || tradition in it.modelTraditions }
        val keptSlugs = kept.map { it.slug }.toSet()
        return Glossary(kept.map { it.copy(related = it.related.filter(keptSlugs::contains)) })
    }

    /** Grouped for display, in the order the categories are declared. */
    val byCategory: List<Pair<String, List<GlossaryEntryJson>>>
        get() = CATEGORY_ORDER.mapNotNull { category ->
            entries.filter { it.category.equals(category, ignoreCase = true) }
                .takeIf { it.isNotEmpty() }
                ?.let { category to it }
        } + entries.filter { entry ->
            CATEGORY_ORDER.none { it.equals(entry.category, ignoreCase = true) }
        }.groupBy { it.category }.toList()

    fun related(to: GlossaryEntryJson): List<GlossaryEntryJson> = to.related.mapNotNull(bySlug::get)

    /**
     * Every term appearing in a piece of running text, longest first and never
     * overlapping.
     */
    fun scan(text: String): List<TermMatch> {
        val claimed = mutableListOf<IntRange>()
        val found = mutableListOf<TermMatch>()

        for (needle in needlesByLength) {
            val slug = byNeedle[needle] ?: continue
            var from = 0
            while (from < text.length) {
                val at = text.indexOf(needle, from, ignoreCase = true)
                if (at < 0) break
                val range = at until (at + needle.length)
                from = range.last + 1

                if (!sitsOnWordBoundaries(range, text)) continue
                if (claimed.any { it.first <= range.last && range.first <= it.last }) continue

                claimed += range
                found += TermMatch(range, slug, text.substring(range.first, range.last + 1))
            }
        }
        return found.sortedBy { it.range.first }
    }

    /**
     * A run of paragraphs, keeping each term only the first time it appears.
     *
     * A rule is read straight through, so linking "Amen" at the end of all six
     * prayers is noise. The run, not the paragraph, is what the reader lives.
     */
    fun scanOnce(paragraphs: List<String>): List<List<TermMatch>> {
        val seen = mutableSetOf<String>()
        return paragraphs.map { paragraph -> scan(paragraph).filter { seen.add(it.slug) } }
    }

    private fun sitsOnWordBoundaries(range: IntRange, text: String): Boolean {
        fun isWord(c: Char) = c.isLetterOrDigit() || c == '\''
        val before = range.first - 1
        val after = range.last + 1
        if (before >= 0 && isWord(text[before])) return false
        if (after < text.length && isWord(text[after])) return false
        return true
    }

    companion object {
        /** The order the categories are shown in, matching the Swift side. */
        val CATEGORY_ORDER = listOf("services", "prayer", "fasting", "people", "things", "time")

        val SHARED: Glossary by lazy { Glossary() }

        private val scopedCache = mutableMapOf<Tradition, Glossary>()

        /**
         * Built once and kept. Scoping filters every entry, prunes every
         * cross-reference and rebuilds the indexes; doing that inside a
         * composable — which is where the linked text needs it — would repeat
         * all of it on every recomposition.
         */
        fun shared(tradition: Tradition): Glossary = synchronized(scopedCache) {
            scopedCache.getOrPut(tradition) { SHARED.scoped(tradition) }
        }
    }
}
