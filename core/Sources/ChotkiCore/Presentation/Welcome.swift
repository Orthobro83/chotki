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
    public static let title = "Welcome"

    public static let beginLabel = "Continue"

    public static let churchPrompt = "Do you have an existing church affiliation?"

    public static let noChurchAffiliation = "I don't have a church affiliation yet."

    public static let independence = "Chotki is an independent project. It is not affiliated with or sanctioned by any church authority. It is not a spiritual father and is not meant to stand in for one."

    public static let paragraphs: [WelcomeParagraph] = [
        WelcomeParagraph([WelcomeSpan("Chotki is an independent project. It is not affiliated with or sanctioned by any church authority. The intention is to give new and existing Christians a way to build an initial daily routine in an Orthodox context.")]),
        WelcomeParagraph([WelcomeSpan("All content contained in this app is gathered from the public domain. Prayers, readings, and disciplines vary from church to church. Chotki is not a substitute for a priest or spiritual father.")]),
        WelcomeParagraph([WelcomeSpan("Chotki is best used in cooperation with a spiritual father, and we encourage you to find one as soon as possible.")]),
    ]
}
