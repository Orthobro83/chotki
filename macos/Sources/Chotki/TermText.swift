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
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == TermText.scheme, let slug = url.host else { return .systemAction }
                model.screen = .glossary(slug)
                return .handled
            })
    }

    private var attributed: AttributedString {
        TermText.link(text, in: Glossary.shared(for: model.settings.jurisdiction.tradition))
    }

    /// Extracted so the index arithmetic can be tested. Mapping a `String`
    /// range onto an `AttributedString` index is the part most likely to be
    /// subtly wrong, and being off by one would underline the wrong words.
    static func link(_ text: String, in glossary: Glossary) -> AttributedString {
        var result = AttributedString(text)

        for match in glossary.scan(text) {
            guard let url = URL(string: "\(TermText.scheme)://\(match.slug)") else { continue }
            // Map the String range onto the AttributedString.
            let lower = text.distance(from: text.startIndex, to: match.range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: match.range.upperBound)
            guard let start = result.index(result.startIndex, offsetByCharacters: lower) as AttributedString.Index?,
                  let end = result.index(result.startIndex, offsetByCharacters: upper) as AttributedString.Index?,
                  start < end
            else { continue }

            result[start..<end].link = url
            result[start..<end].foregroundColor = Theme.gold
            result[start..<end].underlineStyle = .single
        }
        return result
    }
}
