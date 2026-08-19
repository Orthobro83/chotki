import Foundation

public enum GlossaryCategory: String, Sendable, Hashable, Codable, CaseIterable {
    case calendar, fasting, services, prayer, scripture, saints, things

    public var displayName: String {
        switch self {
        case .calendar: return "The church year"
        case .fasting: return "Fasting"
        case .services: return "Services"
        case .prayer: return "Prayer"
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

    public var id: String { slug }

    public init(
        slug: String, term: String, aliases: [String] = [], pronunciation: String? = nil,
        short: String, full: String, category: GlossaryCategory, related: [String] = []
    ) {
        self.slug = slug; self.term = term; self.aliases = aliases
        self.pronunciation = pronunciation
        self.short = short; self.full = full
        self.category = category; self.related = related
    }

    /// Every string that should light up in running text.
    public var matchable: [String] { [term] + aliases }
}
