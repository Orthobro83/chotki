import Foundation

/// Where a term is found in a piece of text, so the interface can make it tappable.
public struct TermMatch: Sendable, Hashable {
    public let range: Range<String.Index>
    public let slug: String
    public let matchedText: String
}

/// The explained-terms index.
///
/// Bundled, offline, and searchable. It exists because the calendar this app
/// displays is full of language a newcomer has no way to decode — "Major Feast
/// of the Theotokos", "Leavetaking", "Tone 2" — and looking each one up
/// elsewhere breaks the thing you were doing.
public struct Glossary: Sendable {

    public let entries: [GlossaryEntry]

    private let bySlug: [String: GlossaryEntry]
    /// Lowercased term and alias, to slug.
    private let byNeedle: [String: String]
    /// Longest first, so "Great Feast" wins over "Feast".
    private let needlesByLength: [String]

    public static let shared = Glossary()

    private static let scopedLock = NSLock()
    nonisolated(unsafe) private static var scopedCache: [Tradition: Glossary] = [:]

    /// The bundled glossary narrowed to one tradition, built once and kept.
    ///
    /// `scoped(to:)` filters every entry, prunes cross-references and rebuilds
    /// the slug index. Doing that inside a view body — which is where it was
    /// being called, for every linked term on screen — repeated all of it on
    /// each render.
    public static func shared(for tradition: Tradition) -> Glossary {
        scopedLock.lock()
        defer { scopedLock.unlock() }
        if let cached = scopedCache[tradition] { return cached }
        let built = shared.scoped(to: tradition)
        scopedCache[tradition] = built
        return built
    }

    public init(entries: [GlossaryEntry] = Glossary.bundled) {
        self.entries = entries.sorted { $0.term.lowercased() < $1.term.lowercased() }
        self.bySlug = Dictionary(uniqueKeysWithValues: entries.map { ($0.slug, $0) })

        var needles: [String: String] = [:]
        for entry in entries {
            for name in entry.matchable {
                // First writer wins, so a term is never stolen by another
                // entry's alias.
                let key = name.lowercased()
                if needles[key] == nil { needles[key] = entry.slug }
            }
        }
        self.byNeedle = needles
        self.needlesByLength = needles.keys.sorted { ($0.count, $0) > ($1.count, $1) }
    }

    // MARK: lookup

    public func entry(slug: String) -> GlossaryEntry? { bySlug[slug] }

    /// A glossary scoped to one tradition. Universal terms are always kept;
    /// tradition-specific ones appear only for the traditions they belong to.
    ///
    /// Cross-references are pruned to what survives, so the education pane can
    /// never link to an entry the reader cannot open.
    public func scoped(to tradition: Tradition) -> Glossary {
        let kept = entries.filter { $0.appliesTo(tradition) }
        let keptSlugs = Set(kept.map(\.slug))
        return Glossary(entries: kept.map { entry in
            GlossaryEntry(
                slug: entry.slug, term: entry.term, aliases: entry.aliases,
                pronunciation: entry.pronunciation, short: entry.short, full: entry.full,
                category: entry.category,
                related: entry.related.filter { keptSlugs.contains($0) },
                traditions: entry.traditions
            )
        })
    }

    public func entry(forTerm term: String) -> GlossaryEntry? {
        byNeedle[term.lowercased()].flatMap { bySlug[$0] }
    }

    public func entries(in category: GlossaryCategory) -> [GlossaryEntry] {
        entries.filter { $0.category == category }
    }

    public func related(to entry: GlossaryEntry) -> [GlossaryEntry] {
        entry.related.compactMap { bySlug[$0] }
    }

    /// Grouped for browsing.
    public var byCategory: [(GlossaryCategory, [GlossaryEntry])] {
        GlossaryCategory.allCases.compactMap { category in
            let found = entries(in: category)
            return found.isEmpty ? nil : (category, found)
        }
    }

    // MARK: search

    /// Ranked: an exact term first, then a term that starts with the query, then
    /// an alias, then anything matching in the summary or body.
    public func search(_ query: String) -> [GlossaryEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return entries }

        func rank(_ entry: GlossaryEntry) -> Int? {
            let term = entry.term.lowercased()
            if term == needle { return 0 }
            if term.hasPrefix(needle) { return 1 }
            if entry.aliases.contains(where: { $0.lowercased().hasPrefix(needle) }) { return 2 }
            if term.contains(needle) { return 3 }
            if entry.aliases.contains(where: { $0.lowercased().contains(needle) }) { return 4 }
            if entry.short.lowercased().contains(needle) { return 5 }
            if entry.full.lowercased().contains(needle) { return 6 }
            return nil
        }

        return entries
            .compactMap { entry in rank(entry).map { (entry, $0) } }
            .sorted { ($0.1, $0.0.term) < ($1.1, $1.0.term) }
            .map(\.0)
    }

    // MARK: scanning running text

    /// Finds explained terms in a piece of text so the interface can link them.
    ///
    /// Longest match wins, matches never overlap, and a match must sit on word
    /// boundaries — otherwise "Fast" would light up inside "Breakfast" and
    /// "Tone" inside "Antone".
    public func scan(_ text: String) -> [TermMatch] {
        var claimed: [Range<String.Index>] = []
        var matches: [TermMatch] = []

        for needle in needlesByLength {
            guard let slug = byNeedle[needle] else { continue }
            var searchFrom = text.startIndex

            while searchFrom < text.endIndex,
                  let found = text.range(
                      of: needle,
                      options: [.caseInsensitive, .diacriticInsensitive],
                      range: searchFrom..<text.endIndex
                  ) {
                searchFrom = found.upperBound

                guard Self.sitsOnWordBoundaries(found, in: text) else { continue }
                guard !claimed.contains(where: { $0.overlaps(found) }) else { continue }

                claimed.append(found)
                matches.append(
                    TermMatch(range: found, slug: slug, matchedText: String(text[found]))
                )
            }
        }

        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Scans a run of paragraphs, keeping each term only the first time it
    /// appears.
    ///
    /// Running text takes `scan` and lights up every occurrence, which is right
    /// for a one-line commemoration. A prayer is different: "Holy Spirit" can
    /// appear four times in the Creed, and underlining all four turns a text
    /// meant to be prayed into a page of hyperlinks. The first one is the one
    /// that helps; the rest are noise the reader has to look past.
    ///
    /// Paragraphs are scanned as a group rather than one at a time, so a term
    /// explained in the first paragraph is not linked again in the third.
    public func scanOnce(_ paragraphs: [String]) -> [[TermMatch]] {
        var seen: Set<String> = []
        return paragraphs.map { paragraph in
            scan(paragraph).filter { match in
                seen.insert(match.slug).inserted
            }
        }
    }

    /// The same, over several prayers read as one sitting.
    ///
    /// A rule is read straight through. Scanning each prayer separately links
    /// "Amen" at the end of all six of them, which is exactly the noise
    /// `scanOnce` exists to avoid — the run, not the prayer, is the unit the
    /// reader experiences.
    public func scanOnce(across groups: [[String]]) -> [[[TermMatch]]] {
        var seen: Set<String> = []
        return groups.map { paragraphs in
            paragraphs.map { paragraph in
                scan(paragraph).filter { seen.insert($0.slug).inserted }
            }
        }
    }

    private static func sitsOnWordBoundaries(_ range: Range<String.Index>, in text: String) -> Bool {
        func isWordCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber
        }
        if range.lowerBound > text.startIndex {
            let before = text[text.index(before: range.lowerBound)]
            if isWordCharacter(before) { return false }
        }
        if range.upperBound < text.endIndex {
            let after = text[range.upperBound]
            // An apostrophe is allowed to follow, so "the Theotokos' icon" matches.
            if isWordCharacter(after) { return false }
        }
        return true
    }
}
