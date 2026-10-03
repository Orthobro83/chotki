import SwiftUI
import ChotkiCore

/// The places, and how many of them there are.
///
/// Five places. The glossary is not one of them: it is reached from a word,
/// from "Glossary of terms" under the reading and the prayers, and from
/// Settings for browsing. The bar draws its own marks rather than using
/// SF Symbols, in the same line weight as Android.
enum Place: String, CaseIterable, Hashable {
    case rule = "Home"
    case prayers = "Prayers"
    case reading = "Reading"
    case progress = "Progress"
    case settings = "Settings"
}

/// Somewhere reached from a place, rather than a place itself.
///
/// A value, not a screen. Android learned this the hard way: navigation held as
/// "which screen is showing" made the back button guess, and it took three
/// attempts before back reliably went back one. A stack of these cannot guess.
enum Route: Hashable {
    case prayers(ruleID: UUID)
    /// `ruleID` is an existing rule being changed. `startingFrom` is a new one
    /// filled in from a library template and not yet saved — taking something
    /// on is a decision about how often, so it is asked before the rule lands
    /// on the day rather than after.
    case editor(ruleID: UUID?, startingFrom: Rule? = nil)
    case term(slug: String?)
    case psalter
    case rope
    /// The seven questions and the journal of answers.
    ///
    /// A route rather than a sixth tab: iPhone folds the sixth into a "More"
    /// list, and that list is a worse home for anything than a considered
    /// arrangement. Reached the way the glossary and the Psalter are — from the
    /// rule that names it on the day, and from Settings for browsing.
    ///
    /// `weekday` is the day to open on: tapping the way through from Tuesday's
    /// rule should land on Tuesday's question rather than at the top of a
    /// seven-day scroll. nil opens at the top, which is what Settings wants.
    case reflections(weekday: Weekday? = nil)
}
