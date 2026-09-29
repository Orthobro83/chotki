import Foundation

public enum RuleCategory: String, Sendable, Hashable, Codable, CaseIterable {
    case prayer, fasting, services, reading, life

    public var displayName: String {
        switch self {
        case .prayer: return "Prayer"
        case .fasting: return "Fasting"
        case .services: return "Services"
        case .reading: return "Reading"
        case .life: return "Life"
        }
    }

    /// The order they appear in the library.
    ///
    /// Ryan's, and deliberately not alphabetical or historical: what happens
    /// in church first, then what is said at home, then what is read, then
    /// what is kept from food, then the rest of a life. Rules of one's own
    /// come after all of them, and are not a category here because they are
    /// not the library's.
    public static let ordered: [RuleCategory] = [.services, .prayer, .reading, .fasting, .life]
}
