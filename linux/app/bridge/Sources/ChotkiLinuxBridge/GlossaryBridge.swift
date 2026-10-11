import ChotkiCore
import Foundation

// The bundled glossary, scoped to the reader's tradition. Core finds the terms.
// The window only opens the entry it is given. The note is the screen's own
// caveat: this is an introduction, not a ruling.

let glossaryNote = "Introductory, not a ruling. Practice varies between parishes, and fasting or preparation for communion is for your priest."

struct GlossaryTermPayload: Encodable {
    var slug: String
    var term: String
    var short: String
}

struct GlossaryCategoryPayload: Encodable {
    var name: String
    var terms: [GlossaryTermPayload]
}

struct GlossaryLinkPayload: Encodable {
    var slug: String
    var term: String
}

struct GlossaryEntryPayload: Encodable {
    var slug: String
    var term: String
    var pronunciation: String?
    var full: String
    var related: [GlossaryLinkPayload]
}

struct GlossaryPayload: Encodable {
    var note: String
    var query: String
    var categories: [GlossaryCategoryPayload]
    /// Omitted on the index. A chain of related terms replaces this and leaves
    /// the section that opened the glossary alone.
    var entry: GlossaryEntryPayload?
}

func performGlossary(_ request: BridgeRequest, store: SQLiteStore) throws {
    let settings = try store.loadSettings() ?? .default
    let glossary = Glossary.shared(for: settings.jurisdiction.tradition)
    let query = request.query ?? ""
    var entry: GlossaryEntryPayload?
    if let slug = request.slug, !slug.isEmpty {
        guard let found = glossary.entry(slug: slug) else { throw BridgeError.unknownTerm }
        entry = GlossaryEntryPayload(
            slug: found.slug, term: found.term, pronunciation: found.pronunciation,
            full: found.full,
            related: glossary.related(to: found).map { GlossaryLinkPayload(slug: $0.slug, term: $0.term) }
        )
    }
    respond(BridgeSuccess(
        v: bridgeProtocolVersion, id: request.id,
        glossary: GlossaryPayload(
            note: glossaryNote, query: query,
            categories: glossaryCategories(glossary, query: query), entry: entry
        )
    ))
}

func glossaryCategories(_ glossary: Glossary, query: String) -> [GlossaryCategoryPayload] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let visible = Set((trimmed.isEmpty ? glossary.entries : glossary.search(trimmed)).map(\.slug))
    return glossary.byCategory.compactMap { category, entries in
        let terms = entries.filter { visible.contains($0.slug) }.map {
            GlossaryTermPayload(slug: $0.slug, term: $0.term, short: $0.short)
        }
        return terms.isEmpty ? nil : GlossaryCategoryPayload(name: category.displayName, terms: terms)
    }
}

func escapeMarkup(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count)
    for character in text {
        switch character {
        case "&": out += "&amp;"
        case "<": out += "&lt;"
        case ">": out += "&gt;"
        case "\"": out += "&quot;"
        default: out.append(character)
        }
    }
    return out
}

/// Gold links for the terms core found. The plain paragraph stays beside this.
func linkedMarkup(_ text: String, matches: [TermMatch]) -> String {
    var html = ""
    var cursor = text.startIndex
    for match in matches where match.range.lowerBound >= cursor {
        if cursor < match.range.lowerBound {
            html += escapeMarkup(String(text[cursor..<match.range.lowerBound]))
        }
        html += "<a href=\"\(match.slug)\" style=\"color:#c9a227; text-decoration: underline\">"
        html += escapeMarkup(match.matchedText)
        html += "</a>"
        cursor = match.range.upperBound
    }
    if cursor < text.endIndex || html.isEmpty {
        html += escapeMarkup(String(text[cursor...]))
    }
    return html
}
