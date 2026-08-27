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

    /// The shortest gap between two knots that will be counted.
    ///
    /// Zero counts every press, which is what a tap on a phone should do. The
    /// Mac sets a second, because its Count button answers the space bar: hold
    /// the key down and the system's key repeat pumps out knots at whatever
    /// rate the reader has set in their keyboard preferences, and a fast repeat
    /// with a short delay puts a whole knot on the record from one lean on the
    /// bar. A prayer is not said in under a second, so nothing real is lost by
    /// refusing.
    ///
    /// A refused press is not an error and says nothing: `advance` simply
    /// leaves the count alone, and the caller already checks whether it moved
    /// before ringing anything.
    public var minimumInterval: TimeInterval

    /// When the last knot was counted, so the interval can be measured.
    public private(set) var lastAdvancedAt: Date?

    public static let targets = [33, 50, 100]

    public init(
        selection: String? = "jesus-prayer",
        count: Int = 0,
        target: Int = 33,
        minimumInterval: TimeInterval = 0
    ) {
        self.selection = selection
        self.count = count
        self.target = target
        self.minimumInterval = minimumInterval
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
    ///
    /// `now` is passed in rather than read, so the interval can be tested
    /// without waiting a second per assertion.
    @discardableResult
    public mutating func advance(at now: Date = Date()) -> Bool {
        guard count < target else { return false }
        if let last = lastAdvancedAt, now.timeIntervalSince(last) < minimumInterval {
            return false
        }
        lastAdvancedAt = now
        count += 1
        return count == target
    }

    /// A new target starts the count again: carrying 40 of 50 across to a target
    /// of 33 would show a knot already complete without a word said.
    public mutating func aim(at target: Int) {
        self.target = target
        count = 0
        // Deliberately starting over is not a stray repeat, so the next knot
        // counts immediately rather than waiting out the interval.
        lastAdvancedAt = nil
    }

    public mutating func startAgain() {
        count = 0
        lastAdvancedAt = nil
    }
}
