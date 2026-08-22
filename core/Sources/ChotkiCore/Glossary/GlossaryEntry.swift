import Foundation

public enum GlossaryCategory: String, Sendable, Hashable, Codable, CaseIterable {
    case calendar, fasting, services, prayer, faith, scripture, saints, things

    public var displayName: String {
        switch self {
        case .calendar: return "The church year"
        case .fasting: return "Fasting"
        case .services: return "Services"
        case .prayer: return "Prayer"
        case .faith: return "The Faith"
        case .scripture: return "Scripture"
        case .saints: return "Saints and titles"
        case .things: return "Objects and places"
        }
    }
}

/// One explained term.
///
/// `short` is what a person sees first — one sentence, no jargon of its own.
/// `full` is the pane. `aliases` exist because the calendar says "Ven." where a
/// reader would search "venerable", and because Greek and Slavonic names for the
/// same thing both circulate.
public struct GlossaryEntry: Sendable, Hashable, Codable, Identifiable {
    public let slug: String
    public let term: String
    public let aliases: [String]
    public let pronunciation: String?
    public let short: String
    public let full: String
    public let category: GlossaryCategory
    public let related: [String]
    /// Empty means universal. Otherwise the term belongs to these traditions
    /// only — a Greek parishioner should not be shown ROCOR-specific entries as
    /// though they were common to all Orthodoxy.
    public let traditions: Set<Tradition>

    public var id: String { slug }

    public init(
        slug: String, term: String, aliases: [String] = [], pronunciation: String? = nil,
        short: String, full: String, category: GlossaryCategory, related: [String] = [],
        traditions: Set<Tradition> = []
    ) {
        self.slug = slug; self.term = term; self.aliases = aliases
        self.pronunciation = pronunciation
        self.short = short; self.full = full
        self.category = category; self.related = related
        self.traditions = traditions
    }

    public var isUniversal: Bool { traditions.isEmpty }

    public func appliesTo(_ tradition: Tradition) -> Bool {
        isUniversal || traditions.contains(tradition)
    }

    /// Returns a copy scoped to the given traditions.
    public func limited(to traditions: Set<Tradition>) -> GlossaryEntry {
        GlossaryEntry(
            slug: slug, term: term, aliases: aliases, pronunciation: pronunciation,
            short: short, full: full, category: category, related: related,
            traditions: traditions
        )
    }

    /// Every string that should light up in running text.
    public var matchable: [String] { [term] + aliases }
}
