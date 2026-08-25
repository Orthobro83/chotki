import Foundation

/// What text, if any, a rule points at.
///
/// The point of a rule is the thing itself, and a rule that names a text the
/// app is holding should be one tap from it. Deciding that in core rather than
/// in each interface is what stops the two platforms disagreeing — the reading
/// rules had no way through on either, for the same reason, and were noticed
/// on one.
///
/// `none` is a real answer and not a failure. An akathist and a kathisma of the
/// Psalter are named in the library because people keep them, but their texts
/// are long and not ours to ship; offering a link to nothing would be worse
/// than offering none.
public enum RuleReference: Sendable, Hashable {
    /// The prayers the rule carries, in order.
    case prayers
    /// The day's appointed readings and its commemoration.
    case reading
    case none
}

public extension Rule {
    var reference: RuleReference {
        if hasPrayers { return .prayers }
        // The day's Gospel, the day's Epistle, the life of the day's saint —
        // all three are what the Reading screen already shows.
        if category == RuleCategory.reading.rawValue { return .reading }
        return .none
    }
}
