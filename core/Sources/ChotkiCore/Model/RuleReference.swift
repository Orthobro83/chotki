import Foundation

/// What text, if any, a rule points at.
///
/// The point of a rule is the thing itself, and a rule that names a text the
/// app is holding should be one tap from it. Deciding that in core rather than
/// in each interface is what stops the two platforms disagreeing — the reading
/// rules had no way through on either, for the same reason, and were noticed
/// on one.
///
/// `none` is a real answer and not a failure. A kathisma of the Psalter is
/// named in the library because people keep it; the text it points at is the
/// Psalter itself, matched by title below.
public enum RuleReference: Sendable, Hashable {
    /// The rope, already counting the prayer this rule carries.
    case rope
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

/// The library title of the Akathist rule. A copy taken from the library has
/// no link back, so the title is how the Reading section is found.
public let akathistRuleTitle = "An akathist"

/// The library title of the daily commemoration of the departed.
public let departedRuleTitle = "Prayer for the departed"

public extension Rule {
    /// The named sequence this rule is said as, when it is one.
    ///
    /// An exact list wins. The editor never offers a way to rewrite that list,
    /// so a rule that still carries the sequence's own title, and whose stored
    /// prayers are all part of it, opens the sequence as it stands now — an
    /// older copy of the list would otherwise show a different morning or
    /// evening rule from the one the other platforms open. A list that contains
    /// something else was chosen, and is left alone.
    var sequenceID: String? {
        if let ids = prayerIDs,
           let exact = PrayerSequence.all.first(where: { $0.prayerIDs == ids }) {
            return exact.id
        }
        guard let sequence = PrayerSequence.all.first(where: {
            $0.title.compare(title, options: .caseInsensitive) == .orderedSame
        }) else { return nil }
        if let stored = prayerIDs {
            // An empty list was set, not merely never filled in.
            guard !stored.isEmpty, stored.allSatisfy(sequence.prayerIDs.contains) else { return nil }
        }
        return sequence.id
    }

    /// The prayer the rope should already be counting when this rule is opened.
    ///
    /// A rule whose whole text is a single counted prayer is not read through:
    /// it is said over and over. Sending it to the prayer screen hands the
    /// reader one short paragraph and nowhere to keep the count, which is the
    /// opposite of what they opened it for. Nil for every other rule, and that
    /// is what decides `.rope` below.
    var ropePrayerID: String? {
        guard let ids = prayerIDs, ids.count == 1,
              let prayer = PrayerBook.shared.prayer(id: ids[0]), prayer.isForRope
        else { return nil }
        return prayer.id
    }

    var reference: RuleReference {
        if ropePrayerID != nil { return .rope }
        if hasPrayers { return .prayers }
        // The day's Gospel, the day's Epistle, the life of the day's saint —
        // all three are what the Reading screen already shows.
        if category == RuleCategory.reading.rawValue { return .reading }
        if title == psalterRuleTitle { return .psalter }
        if title == reflectionRuleTitle { return .reflections }
        if title == akathistRuleTitle || title == departedRuleTitle { return .reading }
        return .none
    }
}

public extension Rule {
    /// The glossary entry that explains what this rule is.
    ///
    /// Two ways of finding it, in order of trust. A rule taken from the library
    /// keeps its template's title, and the template says outright which entry
    /// is about it, so that answer is used wherever it can be had. Failing
    /// that the title is scanned the way prayer text is scanned, which is what
    /// rescues the renamed ones: "The Jesus Prayer, 33 repetitions" is not a
    /// template title any more, but it still contains one.
    ///
    /// Nil is a real answer. A rule someone wrote themselves is theirs, and
    /// the app has nothing to say about what "Cold plunge" means.
    var glossarySlug: String? {
        if let curated = RuleLibrary.shared.templates
            .first(where: { $0.title.compare(title, options: .caseInsensitive) == .orderedSame })?
            .glossarySlugs.first {
            return curated
        }
        return Glossary.shared.scan(title).first?.slug
    }
}
