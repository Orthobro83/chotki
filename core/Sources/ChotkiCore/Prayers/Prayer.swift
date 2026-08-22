import Foundation

/// A prayer, as text to be read.
///
/// The words matter more than anything else in this app, so they are data
/// rather than code: correcting one, or replacing a translation wholesale, is
/// an edit to `PrayerContent.swift` and nothing else.
///
/// **Every text here awaits a priest's review.** The translations are older
/// public-domain English, in the same tradition as the patristic passages —
/// modern prayer books, the Jordanville book included, remain in copyright and
/// must not be pasted in.
public struct Prayer: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    /// Shown under the title where it helps — "said three times", or what the
    /// prayer is for.
    public let rubric: String?
    /// Paragraphs, in order. Kept as separate strings so the interface can set
    /// them apart without parsing.
    public let paragraphs: [String]
    /// Where this wording comes from, so it can be checked.
    public let source: String
    /// Where to read that source, where it is online.
    public let sourceURL: String?
    /// Traditionally counted on a prayer rope — said over and over, rather
    /// than read once. Governs whether the rope is shown alongside it.
    public let isForRope: Bool
    /// Empty means every tradition.
    public let traditions: Set<Tradition>

    public init(
        id: String, title: String, rubric: String? = nil, paragraphs: [String],
        source: String, sourceURL: String? = nil,
        isForRope: Bool = false, traditions: Set<Tradition> = []
    ) {
        self.id = id
        self.title = title
        self.rubric = rubric
        self.paragraphs = paragraphs
        self.source = source
        self.sourceURL = sourceURL
        self.isForRope = isForRope
        self.traditions = traditions
    }

    public var text: String { paragraphs.joined(separator: "\n\n") }

    public func appliesTo(_ tradition: Tradition) -> Bool {
        traditions.isEmpty || traditions.contains(tradition)
    }
}

public struct PrayerBook: Sendable {
    public let prayers: [Prayer]

    public init(prayers: [Prayer] = PrayerBook.bundled) {
        self.prayers = prayers
    }

    public static let shared = PrayerBook()

    public func prayer(id: String) -> Prayer? {
        prayers.first { $0.id == id }
    }

    public func prayers(_ ids: [String]) -> [Prayer] {
        ids.compactMap { prayer(id: $0) }
    }

    /// Prayers traditionally counted on a rope.
    public func forRope(tradition: Tradition? = nil) -> [Prayer] {
        prayers.filter { $0.isForRope && (tradition.map($0.appliesTo) ?? true) }
    }

    /// Prayers that are read rather than counted.
    public func notForRope(tradition: Tradition? = nil) -> [Prayer] {
        prayers.filter { !$0.isForRope && (tradition.map($0.appliesTo) ?? true) }
    }

    /// Whether the rope belongs alongside a given selection.
    ///
    /// Counted prayers bring the rope; rules read through do not. Choosing
    /// nothing brings it too — for someone who has the prayer by heart and only
    /// wants somewhere to keep the count.
    ///
    /// This is what the tradition does, not what anyone must do: the interface
    /// lets a person overrule it, because practice varies and the app should
    /// not argue.
    public func ropeBelongs(with selection: String?) -> Bool {
        guard let selection, !selection.isEmpty else { return true }
        if sequence(id: selection) != nil { return false }
        guard let prayer = prayer(id: selection) else { return true }
        return prayer.isForRope
    }

    public func scoped(to tradition: Tradition) -> PrayerBook {
        PrayerBook(prayers: prayers.filter { $0.appliesTo(tradition) })
    }
}
