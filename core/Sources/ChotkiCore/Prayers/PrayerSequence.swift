import Foundation

/// A named order of prayers — a rule, said through from beginning to end.
///
/// Defined once here and used by both the rule library and the prayer rope, so
/// the two cannot drift apart. What each contains is the prayers common to
/// almost every form of that rule, not any one prayer book's full order; prayer
/// books differ and the full rule is settled with a priest.
public struct PrayerSequence: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let title: String
    public let prayerIDs: [String]

    public init(id: String, title: String, prayerIDs: [String]) {
        self.id = id
        self.title = title
        self.prayerIDs = prayerIDs
    }

    public static let morning = PrayerSequence(
        id: "morning", title: "Morning prayers",
        prayerIDs: [
            "opening-prayer", "beginning", "heavenly-king", "trisagion",
            "all-holy-trinity", "our-father", "macarius", "having-risen",
            "guardian-angel", "rejoice-o-virgin", "it-is-truly-meet"
        ]
    )

    public static let evening = PrayerSequence(
        id: "evening", title: "Evening prayers",
        prayerIDs: [
            "opening-prayer", "beginning", "heavenly-king", "trisagion",
            "all-holy-trinity", "our-father", "evening-forgiveness",
            "ioannikios", "guardian-angel", "it-is-truly-meet"
        ]
    )

    public static let trisagionPrayers = PrayerSequence(
        id: "trisagion-prayers", title: "The Trisagion prayers",
        prayerIDs: [
            "beginning", "heavenly-king", "trisagion", "all-holy-trinity", "our-father"
        ]
    )

    public static let all: [PrayerSequence] = [morning, evening, trisagionPrayers]
}

public extension PrayerBook {
    var sequences: [PrayerSequence] { PrayerSequence.all }

    func sequence(id: String) -> PrayerSequence? {
        PrayerSequence.all.first { $0.id == id }
    }

    /// The prayers of a sequence, in order.
    func prayers(of sequence: PrayerSequence) -> [Prayer] {
        prayers(sequence.prayerIDs)
    }
}
