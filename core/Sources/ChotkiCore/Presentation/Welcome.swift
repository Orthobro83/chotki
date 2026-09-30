import Foundation

/// A run of text, sometimes a link.
///
/// Paragraphs are held as spans rather than as one string with markup because
/// both interfaces have to build a real link out of it — an `AttributedString`
/// on one side, an annotated string on the other — and neither should be
/// parsing anything to do it.
public struct WelcomeSpan: Sendable, Hashable, Codable {
    public let text: String
    /// Nil for ordinary text.
    public let url: String?

    public init(_ text: String, url: String? = nil) {
        self.text = text
        self.url = url
    }
}

public struct WelcomeParagraph: Sendable, Hashable, Codable {
    public let spans: [WelcomeSpan]
    /// Set apart from the rest — quieter, and indented behind a rule.
    public let isAside: Bool

    public init(_ spans: [WelcomeSpan], isAside: Bool = false) {
        self.spans = spans
        self.isAside = isAside
    }
}

/// What someone reads the first time they open Chotki, and once only.
///
/// Ryan's words. It lives in core so that both platforms say exactly the same
/// thing — the alternative is the same paragraph typed into two languages,
/// which is how the Mac and Android came to disagree about several other
/// things in this app.
///
/// It carries no links. Chotki positions itself as an independent project and
/// speaks for nobody, so the first screen sends the reader nowhere.
public enum Welcome {

    public static let title = "Welcome to Chotki"

    /// The button. Not "Accept": nothing here is a term to agree to, and asking
    /// someone to accept a welcome sets up a decision that is not being offered.
    public static let beginLabel = "Begin"

    /// The standing disclaimer, wherever the app has to state what it is.
    ///
    /// One string in core because it was three literals before: the Android
    /// settings screen, the iOS settings screen, and the README each carried
    /// its own copy, and three copies of a sentence about what the app is not
    /// is three chances to say something different.
    public static let independence =
        "An independent project by an Orthodox Inquirer. Chotki speaks for no "
        + "parish, no jurisdiction, and no community, and nothing in it carries "
        + "anyone's blessing. It is not a spiritual father and is not meant to "
        + "stand in for one."

    public static let paragraphs: [WelcomeParagraph] = [
        WelcomeParagraph([
            WelcomeSpan(
                "Chotki is a tool for keeping an Orthodox rule: for inquirers, for "
                + "catechumens, and for anyone who wants their commitments written "
                + "down somewhere they will be seen."
            )
        ]),

        WelcomeParagraph([
            WelcomeSpan(
                "It is an independent project by an Orthodox inquirer. It exists "
                + "because its author has no spiritual father within reach of where he "
                + "lives, and the rule still had to be kept. It speaks for no parish, "
                + "no jurisdiction, and no community, and nothing in it carries "
                + "anyone's blessing."
            )
        ]),

        WelcomeParagraph([
            WelcomeSpan(
                "To begin, take a rule from the Library. Choose what you can actually "
                + "keep rather than what you would like to keep, and add to it slowly. "
                + "At the foot of the Library you can write a rule of your own."
            )
        ]),

        WelcomeParagraph([
            WelcomeSpan(
                "No application is a spiritual father. The Church has always held that "
                + "a person needs someone who knows them to shape their discipline, and "
                + "a record of what was kept is no substitute for that counsel. If you "
                + "have a priest or a spiritual father, settle your rule with him and "
                + "let this app do nothing more than remember it. If you do not yet "
                + "have one, treat what is here as a beginning rather than an "
                + "authority, and go on looking."
            )
        ], isAside: true)
    ]
}
