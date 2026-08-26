import SwiftUI
import ChotkiCore

/// The places, and how many of them there are.
///
/// Five, not Android's six. iPhone shows five tabs before folding the rest into
/// a "More" list, which is a worse home for anything than a considered
/// omission. The glossary is the one left out, and deliberately: it is reached
/// by tapping a word in the text that puzzled you, which is how anyone actually
/// arrives there, and from Settings for browsing. macOS makes a third choice —
/// three tabs — so this is a per-platform arrangement rather than a rule.
///
/// **It is not a difference in what the app can do**, and `PortParityTests`
/// exists to keep it that way: every screen reachable elsewhere is reachable
/// here.
enum Place: String, CaseIterable, Hashable {
    case rule = "Rule"
    case prayers = "Prayers"
    case reading = "Reading"
    case progress = "Progress"
    case settings = "Settings"

    var symbol: String {
        switch self {
        case .rule: return "calendar"
        case .prayers: return "circle.hexagongrid"
        case .reading: return "book"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .settings: return "slider.horizontal.3"
        }
    }
}

/// Somewhere reached from a place, rather than a place itself.
///
/// A value, not a screen. Android learned this the hard way: navigation held as
/// "which screen is showing" made the back button guess, and it took three
/// attempts before back reliably went back one. A stack of these cannot guess.
enum Route: Hashable {
    case prayers(ruleID: UUID)
    case editor(ruleID: UUID?)
    case term(slug: String?)
    case psalter
    case rope
}
