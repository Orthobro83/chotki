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
    /// The kathismata appointed for the day, and the psalms in them.
    case psalter
    /// The Reflections section, and today's question in it.
    case reflections
    case none
}

/// How a rule of one's own is recognised as the Psalter rule.
///
/// Matched on the title because a rule taken from the library carries no link
/// back to its template — that is deliberate, so the rule is the person's own
/// and stays theirs when the library changes underneath it.
let psalterRuleTitle = "A kathisma of the Psalter"

/// How a rule of one's own is recognised as the Reflections rule.
///
/// Same reasoning as the Psalter's, and the same consequence: rename it and it
/// becomes an ordinary rule with no way through to the section. That is right.
/// It is theirs at that point, not ours.
public let reflectionRuleTitle = "Reflection"

public extension Rule {
    var reference: RuleReference {
        if hasPrayers { return .prayers }
        // The day's Gospel, the day's Epistle, the life of the day's saint —
        // all three are what the Reading screen already shows.
        if category == RuleCategory.reading.rawValue { return .reading }
        if title == psalterRuleTitle { return .psalter }
        if title == reflectionRuleTitle { return .reflections }
        return .none
    }
}
