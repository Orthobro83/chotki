import Foundation

/// One service, or one long-form devotion, as the book sets it.
public struct ServiceText: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let title: String
    public let paragraphs: [String]

    /// A rough sense of length, for a list that has to say what it is offering
    /// before someone opens a forty-page Liturgy on a phone.
    public var lengthDescription: String {
        switch paragraphs.count {
        case ..<40: return "short"
        case ..<120: return "medium"
        default: return "long"
        }
    }
}

/// The parts of the prayer book that are followed rather than said as a rule.
///
/// Vespers, Matins and the Liturgy are what happens in church; the akathists,
/// canons and the preparation for communion are long devotions read through
/// rather than kept daily. Either way they do not belong in the prayers
/// dropdown, which is for what a rule is made of — so they live behind the
/// Reading, where the day's other texts already are.
///
/// The order is the book's own, and so are the titles. Someone holding the
/// printed book should be able to find the same thing in the same place.
///
/// Bundled as a resource rather than as Swift, for the same reason the Psalter
/// is: a quarter of a megabyte of string literals is a slow file to compile and
/// an unreadable one to review.
public enum ServiceTexts {

    private struct Document: Codable {
        let source: String
        let sourceURL: String
        let texts: [ServiceText]
    }

    private static let document: Document = {
        guard let url = Bundle.module.url(forResource: "service-texts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Document.self, from: data)
        else {
            // A missing resource is a build fault, not a runtime condition.
            fatalError("the service texts are missing from the bundle")
        }
        return decoded
    }()

    public static var all: [ServiceText] { document.texts }
    public static var source: String { document.source }
    public static var sourceURL: String { document.sourceURL }

    public static func text(id: String) -> ServiceText? {
        document.texts.first { $0.id == id }
    }
}
