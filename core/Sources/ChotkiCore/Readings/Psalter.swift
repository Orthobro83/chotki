import Foundation

/// A psalm, in Septuagint numbering.
public struct Psalm: Sendable, Hashable, Codable, Identifiable {
    public struct Verse: Sendable, Hashable, Codable {
        /// A string because Brenton splits a few — "4a", "4b".
        public let number: String
        public let text: String
    }

    public let number: Int
    /// The title, where the psalm has one. Counted as verse 1 in the
    /// Septuagint, which is why those psalms begin their body at verse 2.
    public let superscription: String?
    public let verses: [Verse]

    public var id: Int { number }
}

/// The Psalter the app carries.
///
/// Brenton's Septuagint of 1851, in the public domain, taken from the
/// proofread machine-readable text at eBible.org rather than from a scan —
/// an OCR error in a psalm is an error in a psalm, not a typo. Nothing here
/// was retyped; `core/Tools/psalter-from-brenton.py` moved it.
///
/// Septuagint numbering throughout, which is what the Orthodox Psalter uses
/// and what the kathisma divisions are stated in.
public enum Psalter {

    private struct Document: Codable {
        let source: String
        let sourceURL: String
        let psalms: [Psalm]
    }

    private static let document: Document = {
        guard let url = Bundle.module.url(forResource: "psalter", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Document.self, from: data)
        else {
            // A missing resource is a build fault, not a runtime condition.
            fatalError("the Psalter is missing from the bundle")
        }
        return decoded
    }()

    public static var all: [Psalm] { document.psalms }
    public static var source: String { document.source }
    public static var sourceURL: String { document.sourceURL }

    public static func psalm(_ number: Int) -> Psalm? {
        all.first { $0.number == number }
    }

    /// The psalms of a kathisma, in order.
    public static func kathisma(_ number: Int) -> [Psalm] {
        guard let range = Kathisma.psalms(in: number) else { return [] }
        return range.compactMap(psalm)
    }
}
