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
    public static let ordered: [RuleCategory] = [.prayer, .fasting, .services, .reading, .life]
}
