import Foundation

/// The rules someone wrote themselves, kept in the library so they can be taken
/// up again.
///
/// Not a second kind of template. The rule record *is* the entry: removing a
/// rule closes its activations and archives it, and the record with its whole
/// history stays behind. Taking it up again opens a new activation rather than
/// making a new rule, so a practice kept, set down for a season and taken up
/// again reads as one thing with a gap in it — which is what it is — instead of
/// two unrelated rules with the progress split between them.
///
/// That is the whole point of the feature: nobody should have to write out a
/// rule a second time because they set it down for Lent.
public enum CustomLibrary {

    /// A rule is one's own when the bundled library has nothing by that name.
    ///
    /// `Rule.source` cannot answer this. It looks like provenance but it is a
    /// free-text note about where a rule came from — "my godfather" — that the
    /// person edits themselves. The title is what `makeRule` copies verbatim
    /// from a template, and it is already what the library matches on to show
    /// "on your rule", so the two agree by construction.
    public static func isOwn(_ rule: Rule, in library: RuleLibrary = .shared) -> Bool {
        !library.templates.contains {
            $0.title.compare(rule.title, options: .caseInsensitive) == .orderedSame
        }
    }

    /// What the Custom section offers, newest first.
    ///
    /// Includes rules currently on the rule, which show as taken rather than
    /// being hidden — the section is meant to be the whole catalogue of what
    /// someone has written, not only the part they are not doing today.
    public static func entries(
        from rules: [Rule], in library: RuleLibrary = .shared
    ) -> [Rule] {
        rules
            .filter { isOwn($0, in: library) && $0.hiddenFromLibrary != true }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// A rule set aside: out of the library, everything else untouched.
    public static func settingAside(_ rule: Rule) -> Rule {
        var aside = rule
        aside.hiddenFromLibrary = true
        return aside
    }

    /// A rule taken up again — unarchived, and due from `date` onwards.
    ///
    /// The caller opens the activation; this only clears the archive mark, so
    /// the two halves of "take it up again" stay in one place each.
    public static func takingUp(_ rule: Rule) -> Rule {
        var restored = rule
        restored.archivedAt = nil
        restored.hiddenFromLibrary = nil
        return restored
    }
}
