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

    /// The Morning Prayers, in the order the book sets them.
    ///
    /// Twenty-three, where the Hapgood set before it had eleven. This is the
    /// whole rule as Jordanville gives it, not a selection from it — a rule
    /// that leaves prayers out is a different rule.
    public static let morning = PrayerSequence(
        id: "morning", title: "Morning prayers",
        prayerIDs: [
            "publican", "opening-prayer", "beginning", "heavenly-king",
            "trisagion", "all-holy-trinity", "our-father",
            "troparia-to-the-holy-trinity",
            "prayer-of-saint-basil-the-great-to-the-most", "psalm-50",
            "creed", "prayer-i-of-st-macarius-the-great",
            "prayer-ii-of-the-same-saint", "prayer-iii-of-the-same-saint",
            "prayer-iv-of-the-same-saint",
            "prayer-v-of-st-basil-the-great",
            "prayer-vi-likewise-by-st-basil",
            "prayer-vii-to-the-most-holy-theotokos",
            "prayer-viii-to-our-lord-jesus-christ",
            "prayer-ix-to-the-holy-guardian-angel",
            "prayer-x-to-the-most-holy-theotokos",
            "prayer-for-the-salvation-of-russia",
            "prayerful-invocation-of-the-saint-whose-name",
            "rejoice-o-virgin", "troparion-to-the-cross", "for-the-living",
            "for-the-departed", "it-is-truly-meet"
        ]
    )

    /// Prayers during the Day: before and after work, lessons and meals.
    ///
    /// New here. The book gives them as pairs and they are kept as pairs, so
    /// "before" and "after" sit together rather than being split into two
    /// rules that would each look incomplete.
    public static let duringTheDay = PrayerSequence(
        id: "during-the-day", title: "Prayers during the day",
        prayerIDs: [
            "before-the-beginning-of-any-work",
            "after-the-completion-of-any-work", "before-lessons",
            "after-lessons", "before-noon-and-evening-meals",
            "after-noon-and-evening-meals"
        ]
    )

    /// Prayers before Sleep.
    ///
    /// Still called "evening" so that a rule someone already keeps does not
    /// lose its prayers when this lands. The book's own name for it is the
    /// title.
    public static let evening = PrayerSequence(
        id: "evening", title: "Prayers before sleep",
        prayerIDs: [
            "opening-prayer", "beginning", "heavenly-king", "trisagion",
            "all-holy-trinity", "our-father", "troparia",
            "sleep-prayer-i-of-st-macarius-the-great",
            "prayer-ii-of-saint-antiochus",
            "prayer-iii-to-the-holy-spirit",
            "prayer-iv-of-st-macarius-the-great", "prayer-v", "prayer-vi",
            "prayer-vii-of-st-john-chrysostom-according-t",
            "sleep-prayer-viii-to-our-lord-jesus-christ",
            "prayer-ix-to-the-most-holy-theotokos", "ioannikios",
            "kontakion-to-the-theotokos",
            "prayer-of-saint-john-damascene-which-is-to-b",
            "and-when-about-to-lie-down-in-bed-say-this",
            "then-instead-of-forgiveness", "prayer",
            "daily-confession-of-sins",
            "when-giving-thyself-up-to-sleep-say"
        ]
    )

    /// The Trisagion prayers — the short opening every rule begins with.
    ///
    /// Jordanville does not set these apart under a heading of their own: it
    /// runs them together as the opening of the Morning Prayers, from the
    /// Publican through the Our Father. So this names those two blocks rather
    /// than inventing a division the book does not make.
    public static let trisagionPrayers = PrayerSequence(
        id: "trisagion-prayers", title: "The Trisagion prayers",
        prayerIDs: [
            "opening-prayer", "beginning", "heavenly-king", "trisagion",
            "all-holy-trinity", "our-father"
        ]
    )

    public static let all: [PrayerSequence] = [morning, duringTheDay, evening, trisagionPrayers]
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
