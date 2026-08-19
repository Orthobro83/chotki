import Foundation

/// Wire format of orthocal.info. Field names are the API's, not ours — note
/// `fast_level_desc` alongside `feast_level_description`, which is why the
/// decoded property names are uneven.
struct OrthocalResponse: Decodable {
    let year: Int
    let month: Int
    let day: Int
    let tone: Int?
    let titles: [String]?
    let summaryTitle: String?
    let saints: [String]?
    let feasts: [String]?
    let feastLevel: Int
    let feastLevelDescription: String
    let fastLevel: Int
    let fastLevelDesc: String
    let fastException: Int
    let fastExceptionDesc: String?
    let fastAbstentions: [String]?
    let paschaDistance: Int
    let readings: [ResponseReading]?

    struct ResponseReading: Decodable {
        let source: String
        let display: String
        let shortDisplay: String
        let passage: [Verse]?

        struct Verse: Decodable {
            let content: String?
        }

        var text: String {
            (passage ?? []).compactMap(\.content).joined(separator: " ")
        }
    }
}

public struct OrthocalClient: Sendable {
    public static let defaultHost = "https://orthocal.info"

    private let http: any HTTPFetching
    private let host: String

    public init(http: any HTTPFetching = URLSessionFetcher(), host: String = OrthocalClient.defaultHost) {
        self.http = http
        self.host = host
    }

    /// The URL takes a **civil** date. The response reports the date in the
    /// requested reckoning, which is why the caller keeps the civil date as the key.
    public func url(for date: CalendarDate, reckoning: Reckoning) -> URL {
        URL(string: "\(host)/api/\(reckoning.endpointPath)/\(date.year)/\(date.month)/\(date.day)/")!
    }

    public func day(for date: CalendarDate, reckoning: Reckoning, now: Date = Date()) async throws -> LiturgicalDay {
        let data = try await http.data(from: url(for: date, reckoning: reckoning))
        return try Self.decode(data, civilDate: date, reckoning: reckoning, now: now)
    }

    static func decode(
        _ data: Data, civilDate: CalendarDate, reckoning: Reckoning, now: Date
    ) throws -> LiturgicalDay {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = try decoder.decode(OrthocalResponse.self, from: data)

        // Falls back to the civil date if the payload is malformed rather than
        // failing the whole day — the reported date is data, not the key.
        let observed = CalendarDate(year: raw.year, month: raw.month, day: raw.day) ?? civilDate

        return LiturgicalDay(
            civilDate: civilDate,
            reckoning: reckoning,
            observedDate: observed,
            tone: raw.tone,
            title: raw.titles?.first,
            summaryTitle: raw.summaryTitle ?? "",
            saints: raw.saints ?? [],
            feasts: raw.feasts ?? [],
            fastLevel: raw.fastLevel,
            fastLevelDescription: raw.fastLevelDesc,
            fastException: raw.fastException,
            fastExceptionDescription: raw.fastExceptionDesc?.isEmpty == true ? nil : raw.fastExceptionDesc,
            abstentions: raw.fastAbstentions ?? [],
            feastLevel: raw.feastLevel,
            feastLevelDescription: raw.feastLevelDescription,
            readings: (raw.readings ?? []).map {
                Reading(source: $0.source, display: $0.display, shortDisplay: $0.shortDisplay, text: $0.text)
            },
            paschaDistance: raw.paschaDistance,
            fetchedAt: now
        )
    }
}
