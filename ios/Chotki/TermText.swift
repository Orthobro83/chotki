import SwiftUI
import ChotkiCore

/// How a tapped word gets to the glossary from wherever it was read.
///
/// macOS calls a method on one model because it has one window. Here each tab
/// owns its own `NavigationPath`, so the shell puts the right one in the
/// environment and the text below does not have to know which tab it is in —
/// or that tabs exist. A word tapped in the Reading pushes the glossary onto
/// the Reading's stack, and the back-swipe returns to the passage.
/// A named action rather than a bare closure: an environment value must be
/// `Sendable`, and appending to a `NavigationPath` is main-actor work.
/// Wrapping it says both — the closure is isolated to the main actor, and the
/// value carrying it can cross.
struct OpenTerm: Sendable {
    private let action: @MainActor @Sendable (String) -> Void

    init(_ action: @escaping @MainActor @Sendable (String) -> Void) { self.action = action }

    @MainActor func callAsFunction(_ slug: String) { action(slug) }
}

struct OpenTermKey: EnvironmentKey {
    static let defaultValue = OpenTerm { _ in }
}

extension EnvironmentValues {
    var openTerm: OpenTerm {
        get { self[OpenTermKey.self] }
        set { self[OpenTermKey.self] = newValue }
    }
}

/// Going to one of the tabs from inside a screen.
///
/// The day's readings already have a place of their own, so a reading rule
/// sends you there rather than pushing a second copy onto the day's stack —
/// which is the call macOS makes (`model.tab = .reading`) and Android makes
/// (`journey.go(Place.READING)`). Only the shell knows which tab is showing, so
/// it puts the way to change that here.
struct GoToPlace: Sendable {
    private let action: @MainActor @Sendable (Place) -> Void

    init(_ action: @escaping @MainActor @Sendable (Place) -> Void) { self.action = action }

    @MainActor func callAsFunction(_ place: Place) { action(place) }
}

struct GoToPlaceKey: EnvironmentKey {
    static let defaultValue = GoToPlace { _ in }
}

extension EnvironmentValues {
    var goToPlace: GoToPlace {
        get { self[GoToPlaceKey.self] }
        set { self[GoToPlaceKey.self] = newValue }
    }
}

/// Pushing a route onto whichever tab's stack is showing.
///
/// A `NavigationLink` inside a `List` row makes the row draw a disclosure
/// chevron, so a row with a prayers link and a pencil grew two of them pointing
/// at nothing in particular. And a `NavigationLink` inside a `.contextMenu` is
/// presented outside the navigation stack, where it does not reliably do
/// anything at all. Both become ordinary buttons if there is a way to push by
/// hand, so here is one.
struct PushRoute: Sendable {
    private let action: @MainActor @Sendable (Route) -> Void

    init(_ action: @escaping @MainActor @Sendable (Route) -> Void) { self.action = action }

    @MainActor func callAsFunction(_ route: Route) { action(route) }
}

struct PushRouteKey: EnvironmentKey {
    static let defaultValue = PushRoute { _ in }
}

extension EnvironmentValues {
    var pushRoute: PushRoute {
        get { self[PushRouteKey.self] }
        set { self[PushRouteKey.self] = newValue }
    }
}

/// Running text with glossary terms made tappable.
///
/// A newcomer meets a dozen unfamiliar words in the first sentence of a
/// commemoration. Making them tappable where they appear means the explanation
/// is one tap from the word rather than a search away.
///
/// Deliberately applied to short text only: commemorations, fasting
/// descriptions, titles. Scanning a whole scripture passage would turn it into
/// a field of links and make it harder to read, not easier.
struct TermText: View {
    let model: Model
    let text: String
    var size: CGFloat = 13
    var colour: Color = Chotki.parchmentDim

    static let scheme = "chotki-term"

    @Environment(\.openTerm) private var openTerm

    var body: some View {
        Text(TermText.link(text, in: Glossary.shared(for: model.settings.jurisdiction.tradition)))
            .font(.system(size: size))
            .foregroundStyle(colour)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, TermText.opening(openTerm))
    }

    /// Shared so every linked surface answers a tapped term the same way.
    @MainActor
    static func opening(_ openTerm: OpenTerm) -> OpenURLAction {
        OpenURLAction { url in
            guard url.scheme == TermText.scheme, let slug = url.host else { return .systemAction }
            openTerm(slug)
            return .handled
        }
    }

    static func link(_ text: String, in glossary: Glossary) -> AttributedString {
        decorate(text, matches: glossary.scan(text), quiet: false)
    }

    /// Applies a set of matches to one string.
    ///
    /// Separated from finding them because prayer text is scanned a paragraph
    /// at a time against a shared record of what has already been linked, so
    /// the matches arrive from outside.
    ///
    /// `quiet` is for the prayers: a dotted rule rather than a solid one. Under
    /// a line that is being prayed a solid underline reads as emphasis on words
    /// that are not emphasised.
    static func decorate(_ text: String, matches: [TermMatch], quiet: Bool) -> AttributedString {
        var result = AttributedString(text)

        for match in matches {
            guard let url = URL(string: "\(TermText.scheme)://\(match.slug)") else { continue }
            let lower = text.distance(from: text.startIndex, to: match.range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: match.range.upperBound)
            guard let start = result.index(result.startIndex, offsetByCharacters: lower) as AttributedString.Index?,
                  let end = result.index(result.startIndex, offsetByCharacters: upper) as AttributedString.Index?,
                  start < end
            else { continue }

            result[start..<end].link = url
            result[start..<end].foregroundColor = quiet ? Chotki.goldDim : Chotki.gold
            result[start..<end].underlineStyle = quiet
                ? Text.LineStyle(pattern: .dot, color: Chotki.goldDim.opacity(0.7))
                : .single
        }
        return result
    }
}

/// Prayer text, with the words a newcomer might not know linked.
///
/// Each term links on its first appearance only, across the whole prayer rather
/// than per paragraph. "Holy Spirit" occurs four times in the Creed, and
/// underlining all four would make a text meant to be prayed look like a page
/// of references.
struct PrayerProse: View {
    let model: Model
    let paragraphs: [String]
    var size: CGFloat = 17
    var spacing: CGFloat = 5
    var centred = false
    /// Supplied when several prayers are shown together and the scan has to
    /// span all of them. Left nil, this prayer is scanned on its own.
    var matches: [[TermMatch]]?

    @Environment(\.openTerm) private var openTerm

    var body: some View {
        VStack(alignment: centred ? .center : .leading, spacing: 8) {
            ForEach(Array(linked.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: size))
                    .foregroundStyle(Chotki.parchment)
                    .lineSpacing(spacing)
                    .multilineTextAlignment(centred ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
            }
        }
        .environment(\.openURL, TermText.opening(openTerm))
    }

    private var linked: [AttributedString] {
        let found = matches ?? Glossary
            .shared(for: model.settings.jurisdiction.tradition)
            .scanOnce(paragraphs)
        return zip(paragraphs, found).map { text, matches in
            TermText.decorate(text, matches: matches, quiet: true)
        }
    }
}

/// Where the wording came from, so it can be checked.
///
/// Every text bundled here is public domain, and none of it has had a priest's
/// eye on it yet. Saying where it came from is the least the app owes anyone
/// praying it.
struct PrayerAttribution: View {
    let prayer: Prayer

    var body: some View {
        Text(prayer.source)
            .font(.system(size: 11))
            .foregroundStyle(Chotki.faint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }
}
