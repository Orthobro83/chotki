import Foundation

/// Which calendar a jurisdiction reckons fixed feasts by.
///
/// Note what this does *not* affect: days of the week, and the movable cycle.
/// Nearly every Orthodox church computes Pascha on the Julian reckoning, so
/// Great Lent, Pascha and Pentecost fall on the same civil days under both.
/// Only fixed feasts differ, by 13 days — which is why disagreement clusters
/// around the Nativity and Theophany rather than spreading through the year.
public enum Reckoning: String, Sendable, Hashable, Codable, CaseIterable {
    /// Old Calendar. The default, on adherent numbers: roughly 110 million
    /// against roughly 47 million.
    case julian
    /// New Calendar, also called Revised Julian.
    case revisedJulian

    /// orthocal names the New Calendar endpoint "gregorian".
    public var endpointPath: String {
        switch self {
        case .julian: return "julian"
        case .revisedJulian: return "gregorian"
        }
    }

    public var displayName: String {
        switch self {
        case .julian: return "Old Calendar (Julian)"
        case .revisedJulian: return "New Calendar (Revised Julian)"
        }
    }
}

/// The church a person belongs to. Every date-aware surface reads through this,
/// so changing jurisdiction is one setting and no other code reacts.
public struct Jurisdiction: Sendable, Hashable, Codable {
    public var name: String
    public var reckoning: Reckoning

    public init(name: String, reckoning: Reckoning) {
        self.name = name
        self.reckoning = reckoning
    }

    public static let `default` = Jurisdiction(name: "Old Calendar", reckoning: .julian)

    /// Offered in settings. The list is not exhaustive and the reckoning can be
    /// set directly — a parish sometimes differs from its jurisdiction's norm,
    /// so this is a convenience, never an authority.
    public static let common: [Jurisdiction] = [
        Jurisdiction(name: "Russian / ROCOR", reckoning: .julian),
        Jurisdiction(name: "Serbian", reckoning: .julian),
        Jurisdiction(name: "Georgian", reckoning: .julian),
        Jurisdiction(name: "Jerusalem", reckoning: .julian),
        Jurisdiction(name: "Greek", reckoning: .revisedJulian),
        Jurisdiction(name: "Romanian", reckoning: .revisedJulian),
        Jurisdiction(name: "Antiochian", reckoning: .revisedJulian),
        Jurisdiction(name: "Bulgarian", reckoning: .revisedJulian),
        Jurisdiction(name: "OCA", reckoning: .revisedJulian)
    ]
}
