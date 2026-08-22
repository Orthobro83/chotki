import SwiftUI
import ChotkiCore

/// Running text with glossary terms made tappable.
///
/// A newcomer meets a dozen unfamiliar words in the first sentence of a
/// commemoration. Making them tappable where they appear means the explanation
/// is one click from the word rather than a search away — and the reader is
/// never sent somewhere to look something up.
///
/// Deliberately applied to short text only: commemorations, fasting
/// descriptions, titles. Scanning a whole scripture passage would turn it into
/// a field of links and make it harder to read, not easier.
struct TermText: View {
    @ObservedObject var model: AppModel
    let text: String
    var size: CGFloat = 12
    var serif: Bool = false
    var colour: Color = Theme.parchmentDim

    private static let scheme = "chotki-term"

    var body: some View {
        Text(attributed)
            .font(serif ? .custom("Cardo", size: size) : .system(size: size))
            .foregroundStyle(colour)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, TermText.opening(with: model))
    }

    /// Shared so every linked surface answers a tapped term the same way.
    static func opening(with model: AppModel) -> OpenURLAction {
        OpenURLAction { url in
            guard url.scheme == TermText.scheme, let slug = url.host else { return .systemAction }
            model.openGlossary(slug)
            return .handled
        }
    }

    private var attributed: AttributedString {
        TermText.link(text, in: Glossary.shared(for: model.settings.jurisdiction.tradition))
    }

    /// Extracted so the index arithmetic can be tested. Mapping a `String`
    /// range onto an `AttributedString` index is the part most likely to be
    /// subtly wrong, and being off by one would underline the wrong words.
    static func link(_ text: String, in glossary: Glossary) -> AttributedString {
        decorate(text, matches: glossary.scan(text), quiet: false)
    }

    /// Applies a set of matches to one string.
    ///
    /// Separated from finding them because prayer text is scanned a paragraph at
    /// a time against a shared record of what has already been linked, so the
    /// matches arrive from outside.
    ///
    /// `quiet` is for the prayers: a dotted rule rather than a solid one. A
    /// solid underline is right in a commemoration, which is being scanned;
    /// under a line that is being prayed it reads as emphasis on words that are
    /// not emphasised.
    static func decorate(_ text: String, matches: [TermMatch], quiet: Bool) -> AttributedString {
        var result = AttributedString(text)

        for match in matches {
            guard let url = URL(string: "\(TermText.scheme)://\(match.slug)") else { continue }
            // Map the String range onto the AttributedString.
            let lower = text.distance(from: text.startIndex, to: match.range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: match.range.upperBound)
            guard let start = result.index(result.startIndex, offsetByCharacters: lower) as AttributedString.Index?,
                  let end = result.index(result.startIndex, offsetByCharacters: upper) as AttributedString.Index?,
                  start < end
            else { continue }

            result[start..<end].link = url
            result[start..<end].foregroundColor = quiet ? Theme.goldDim : Theme.gold
            result[start..<end].underlineStyle = quiet
                ? Text.LineStyle(pattern: .dot, color: Theme.goldDim.opacity(0.7))
                : .single
        }
        return result
    }
}

/// Prayer text, with the words a newcomer might not know linked to the glossary.
///
/// The prayers were the one place in the app where an unfamiliar word had
/// nowhere to lead: the glossary grew out of the calendar, and a scan of the
/// bundled prayers against it found a single term. The entries for the language
/// of the prayers themselves were written for this view.
///
/// Each term links on its first appearance only, across the whole prayer rather
/// than per paragraph. "Holy Spirit" occurs four times in the Creed, and
/// underlining all four would make a text meant to be prayed look like a page of
/// references.
struct PrayerProse: View {
    @ObservedObject var model: AppModel
    let paragraphs: [String]
    var size: CGFloat = 15
    var spacing: CGFloat = 5
    var centred = false
    /// Supplied when several prayers are shown together and the scan has to
    /// span all of them. Left nil, this prayer is scanned on its own.
    var matches: [[TermMatch]]?

    var body: some View {
        VStack(alignment: centred ? .center : .leading, spacing: 4) {
            ForEach(Array(linked.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.custom("Cardo", size: size))
                    .foregroundStyle(Theme.parchment)
                    .lineSpacing(spacing)
                    .multilineTextAlignment(centred ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
            }
        }
        .environment(\.openURL, TermText.opening(with: model))
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
