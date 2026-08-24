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

/// The church a person belongs to.
///
/// Carries three things: which calendar it reckons fixed feasts by, which
/// practice family it belongs to, and what that family customarily expects.
/// Every date-aware and practice-aware surface reads through this, so choosing
/// a church is one setting.
public struct Jurisdiction: Sendable, Hashable, Codable {
    public var name: String
    public var reckoning: Reckoning
    public var tradition: Tradition
    /// Defaults to the customary profile for the tradition, and can be adjusted
    /// — a parish sometimes differs from its jurisdiction's norm.
    public var practice: PracticeProfile

    public init(name: String, reckoning: Reckoning, tradition: Tradition, practice: PracticeProfile? = nil) {
        self.name = name
        self.reckoning = reckoning
        self.tradition = tradition
        self.practice = practice ?? .customary(for: tradition)
    }

    /// This jurisdiction as the app ships it, when the name is one it knows.
    public var asShipped: Jurisdiction? {
        Jurisdiction.known.first { $0.name == name }
    }

    /// True when the calendar has been set away from the one this jurisdiction
    /// customarily keeps.
    ///
    /// Not an error and not a warning. Jurisdictions are not uniform: parishes
    /// within one sometimes keep a different calendar from the body they belong
    /// to, and a convert may be attached to a parish rather than to a
    /// jurisdiction's norm. The app records what is actually kept and says
    /// plainly that it differs, rather than correcting anyone.
    public var reckoningDiffersFromJurisdiction: Bool {
        guard let asShipped else { return false }
        return asShipped.reckoning != reckoning
    }

    /// True when this jurisdiction's practice has been adjusted away from its
    /// tradition's norm — a parish sometimes differs, and the app should show
    /// what was actually set rather than what the tradition usually does.
    public var confessionNormDiffersFromTradition: Bool {
        practice.confession != PracticeProfile.customary(for: tradition).confession
    }

    public static let `default` = Jurisdiction(
        name: "Russian Orthodox Church Outside Russia", reckoning: .julian, tradition: .russian
    )

    /// Offered in settings. Reckoning and practice can still be set directly:
    /// a parish sometimes differs from its jurisdiction's norm, so this is a
    /// starting point, never an authority.
    public static let known: [Jurisdiction] = [
        Jurisdiction(name: "Russian Orthodox Church Outside Russia", reckoning: .julian, tradition: .russian),
        Jurisdiction(name: "Moscow Patriarchate", reckoning: .julian, tradition: .russian),
        Jurisdiction(name: "Serbian Orthodox Church", reckoning: .julian, tradition: .serbian),
        Jurisdiction(name: "Georgian Orthodox Church", reckoning: .julian, tradition: .georgian),
        Jurisdiction(name: "Patriarchate of Jerusalem", reckoning: .julian, tradition: .greek),
        Jurisdiction(name: "Polish Orthodox Church", reckoning: .julian, tradition: .russian),
        Jurisdiction(name: "Orthodox Church in America", reckoning: .revisedJulian, tradition: .russian),
        Jurisdiction(name: "Greek Orthodox Archdiocese", reckoning: .revisedJulian, tradition: .greek),
        Jurisdiction(name: "Ecumenical Patriarchate", reckoning: .revisedJulian, tradition: .greek),
        Jurisdiction(name: "Antiochian Orthodox Archdiocese", reckoning: .revisedJulian, tradition: .antiochian),
        Jurisdiction(name: "Romanian Orthodox Church", reckoning: .revisedJulian, tradition: .romanian),
        Jurisdiction(name: "Bulgarian Orthodox Church", reckoning: .revisedJulian, tradition: .bulgarian),
        Jurisdiction(name: "Ukrainian Orthodox Church (OCU)", reckoning: .revisedJulian, tradition: .russian),
        Jurisdiction(name: "Church of Greece", reckoning: .revisedJulian, tradition: .greek),
        Jurisdiction(name: "Church of Cyprus", reckoning: .revisedJulian, tradition: .greek),
        Jurisdiction(name: "Albanian Orthodox Church", reckoning: .revisedJulian, tradition: .greek)
    ]
}
