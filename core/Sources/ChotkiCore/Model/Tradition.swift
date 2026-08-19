import Foundation

/// The practice family a jurisdiction belongs to.
///
/// Separate from `Reckoning` because the two do not track together: the OCA is
/// Russian in tradition but keeps the New Calendar, and the Georgian Church is
/// Julian but has its own usages. Reckoning decides dates; tradition decides
/// terminology and expectation.
public enum Tradition: String, Sendable, Hashable, Codable, CaseIterable {
    case russian, greek, antiochian, romanian, serbian, bulgarian, georgian

    public var displayName: String {
        switch self {
        case .russian: return "Russian"
        case .greek: return "Greek"
        case .antiochian: return "Antiochian"
        case .romanian: return "Romanian"
        case .serbian: return "Serbian"
        case .bulgarian: return "Bulgarian"
        case .georgian: return "Georgian"
        }
    }

    /// Traditions that share Slavic usage and terminology.
    public var isSlavic: Bool {
        switch self {
        case .russian, .serbian, .bulgarian: return true
        default: return false
        }
    }
}

/// How often confession is customarily made before receiving communion.
///
/// This is the single practice difference newcomers trip over most, because it
/// is genuinely different between traditions rather than a matter of strictness.
public enum ConfessionNorm: String, Sendable, Hashable, Codable {
    /// Russian and Serbian usage: confession before each communion, usually at
    /// the evening service the night before.
    case beforeEachCommunion
    /// Greek and Antiochian usage more commonly: confession regularly, but not
    /// tied to each reception.
    case periodic

    public var summary: String {
        switch self {
        case .beforeEachCommunion:
            return "Confession is customarily made before each communion."
        case .periodic:
            return "Confession is made regularly, but is not usually tied to each communion."
        }
    }
}

/// What a jurisdiction customarily expects, so the app can describe practice
/// accurately instead of assuming one tradition's norms are universal.
///
/// Everything here is **descriptive**. The app reports what is customary and
/// says who to ask; it never tells anyone what they must do. Individual practice
/// is settled with a priest, and every surface built on this must say so.
public struct PracticeProfile: Sendable, Hashable, Codable {
    public var confession: ConfessionNorm
    /// Total abstention from food and drink from midnight before communion.
    public var eucharisticFastFromMidnight: Bool
    /// Canons and an akathist customarily read the evening before communion.
    public var preparatoryCanons: Bool
    /// Shown in settings so the described practice is attributable, not asserted.
    public var notes: [String]

    public init(
        confession: ConfessionNorm,
        eucharisticFastFromMidnight: Bool = true,
        preparatoryCanons: Bool = false,
        notes: [String] = []
    ) {
        self.confession = confession
        self.eucharisticFastFromMidnight = eucharisticFastFromMidnight
        self.preparatoryCanons = preparatoryCanons
        self.notes = notes
    }

    public static func customary(for tradition: Tradition) -> PracticeProfile {
        switch tradition {
        case .russian, .serbian:
            return PracticeProfile(
                confession: .beforeEachCommunion,
                preparatoryCanons: true,
                notes: [
                    "Confession is customarily made before each communion from about the age of seven, most often at the evening service the night before.",
                    "The Order of Preparation for Holy Communion is customarily read beforehand, commonly with three canons and an akathist.",
                    "Practice varies between parishes, and what any individual keeps is settled with a priest."
                ]
            )
        case .bulgarian, .georgian, .romanian:
            return PracticeProfile(
                confession: .beforeEachCommunion,
                preparatoryCanons: false,
                notes: [
                    "Confession is customarily made before communion, though expectations vary between parishes.",
                    "Ask your priest how he would like you to prepare."
                ]
            )
        case .greek, .antiochian:
            return PracticeProfile(
                confession: .periodic,
                preparatoryCanons: false,
                notes: [
                    "Confession is made regularly but is not usually required before each communion.",
                    "Preparation practice varies considerably between parishes. Ask your priest."
                ]
            )
        }
    }
}
