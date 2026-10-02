import Foundation

/// One day of the Prologue from Ochrid, stored as published.
///
/// `month` and `day` are the church day the reading belongs to. The Old
/// Calendar and the New Calendar both look a life up by the observed church
/// day, so the same wall-calendar day shows a different life when the
/// reckoning changes. `gregorianMonth` and `gregorianDay` are the civil date
/// on which the Old Calendar keeps that church day — the second date in
/// `dates`, which is the page's own line, such as "December 19 / January 1".
/// February 29 is not among them: that page publishes no reading.
///
/// The words are the English text from app.ochrid.com and are not rewritten.
/// Emphasis is recorded so the reading can be set in italic or bold without
/// those marks becoming part of the text. The license note is cited under the
/// reading; it is not part of the prologue.
public struct SaintLife: Sendable, Codable, Hashable {
    public let month: Int
    public let day: Int
    public let gregorianMonth: Int
    public let gregorianDay: Int
    public let dates: String
    /// A title line a few days print before the sections, such as "22. April".
    public let preface: String?
    public let sections: [Section]
    public let source: String
    public let sourceURL: String
    public let license: String
    public let licenseURL: String
    public let licenseNote: String

    public struct Section: Sendable, Codable, Hashable {
        public let heading: String
        public let blocks: [Block]
    }

    public struct Block: Sendable, Codable, Hashable {
        public let kind: String
        public let text: String?
        public let spans: [Span]?
        public let rows: [[Span]]?

        public init(kind: String, text: String? = nil, spans: [Span]? = nil, rows: [[Span]]? = nil) {
            self.kind = kind
            self.text = text
            self.spans = spans
            self.rows = rows
        }
    }

    public struct Span: Sendable, Hashable {
        public let text: String
        public let italic: Bool
        public let bold: Bool

        public init(text: String, italic: Bool = false, bold: Bool = false) {
            self.text = text
            self.italic = italic
            self.bold = bold
        }
    }
}

extension SaintLife.Span: Codable {
    private enum CodingKeys: String, CodingKey { case text, italic, bold }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        if italic { try container.encode(true, forKey: .italic) }
        if bold { try container.encode(true, forKey: .bold) }
    }
}

public enum SaintLives {
    private static let readings: [SaintLife] = {
        guard let url = Bundle.module.url(forResource: "saint-lives", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let lives = try? JSONDecoder().decode([SaintLife].self, from: data)
        else { return [] }
        return lives
    }()

    public static func reading(on observedDate: CalendarDate) -> SaintLife? {
        readings.first { $0.month == observedDate.month && $0.day == observedDate.day }
    }

    public static var availableDayCount: Int { readings.count }
}
