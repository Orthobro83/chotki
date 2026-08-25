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
/// The two links are the only places Chotki sends anyone else's way, and the
/// only outbound traffic besides the church calendar.
public enum Welcome {

    public static let title = "Welcome to Chotki"

    /// The button. Not "Accept": nothing here is a term to agree to, and asking
    /// someone to accept a welcome sets up a decision that is not being offered.
    public static let beginLabel = "Begin"

    public static let brotherhoodURL = "https://www.skool.com/fathermoses/"
    public static let fatherMosesURL = "https://orthodoxaustin.org/our-clergy/"

    public static let paragraphs: [WelcomeParagraph] = [
        WelcomeParagraph([
            WelcomeSpan(
                "This app was created for inquiring Orthodox Christians, catechumens, "
                + "and anyone looking for a tool to help them keep their spiritual "
                + "commitments."
            )
        ]),

        WelcomeParagraph([
            WelcomeSpan("This app was inspired by, but is not officially affiliated with, "),
            WelcomeSpan("The Brotherhood of the Narrow Path", url: brotherhoodURL),
            WelcomeSpan(", an online Orthodox community by "),
            WelcomeSpan("Father Moses McPherson", url: fatherMosesURL),
            WelcomeSpan(".")
        ]),

        WelcomeParagraph([
            WelcomeSpan(
                "To begin, select a rule from the Library. Start small, only what you "
                + "can keep, and build up from there. At the bottom of the Library is "
                + "the option to write your own rule."
            )
        ]),

        WelcomeParagraph([
            WelcomeSpan(
                "A note on writing your own rules: in Orthodoxy, it is generally "
                + "understood that everybody needs a spiritual father who helps them "
                + "build their own discipline. We all need somebody guiding and "
                + "directing us, so that we are going toward God's will and not our "
                + "own. Chotki's author recommends writing your own rules in "
                + "consultation with your Orthodox community and its leadership."
            )
        ], isAside: true)
    ]
}
