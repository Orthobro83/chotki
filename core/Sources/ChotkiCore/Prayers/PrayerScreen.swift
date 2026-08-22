import Foundation

/// What the prayers screen is showing, and where the count has got to.
///
/// Held apart from the view because following a word into the glossary destroys
/// and rebuilds it. Losing your place in a hundred-knot count because you looked
/// up "Publican" would be a poor trade, and losing the prayer you had chosen is
/// only slightly less annoying.
///
/// The rope rule lives here too, so it is tested rather than asserted in a view
/// body, and so the Android version inherits it.
public struct PrayerScreen: Equatable, Sendable {

    /// What is being prayed. `nil` is the rope on its own, for someone who has
    /// the words by heart.
    public private(set) var selection: String?
    public private(set) var count: Int
    public private(set) var target: Int
    /// `nil` follows the prayer; `true` or `false` is the reader's own decision.
    public private(set) var ropeOverride: Bool?

    public static let targets = [33, 50, 100]

    public init(selection: String? = "jesus-prayer", count: Int = 0, target: Int = 33) {
        self.selection = selection
        self.count = count
        self.target = target
    }

    /// Whether the rope belongs on screen: what the tradition does, unless the
    /// reader has said otherwise.
    public func showsRope(in book: PrayerBook = .shared) -> Bool {
        ropeOverride ?? book.ropeBelongs(with: selection)
    }

    public var isComplete: Bool { count >= target }

    // MARK: changing it

    /// Choosing again returns to following the prayer, so one decision about the
    /// rope does not stay stuck to everything chosen afterwards.
    public mutating func choose(_ selection: String?) {
        guard selection != self.selection else { return }
        self.selection = selection
        ropeOverride = nil
    }

    public mutating func showRope(_ shown: Bool) { ropeOverride = shown }

    /// Advances the count, and says whether that completed the knot — the caller
    /// rings the bell, which this layer knows nothing about.
    @discardableResult
    public mutating func advance() -> Bool {
        guard count < target else { return false }
        count += 1
        return count == target
    }

    /// A new target starts the count again: carrying 40 of 50 across to a target
    /// of 33 would show a knot already complete without a word said.
    public mutating func aim(at target: Int) {
        self.target = target
        count = 0
    }

    public mutating func startAgain() { count = 0 }
}
