import Foundation

public struct Reading: Sendable, Hashable, Codable {
    public let source: String
    public let display: String
    public let shortDisplay: String
    public let text: String

    public init(source: String, display: String, shortDisplay: String, text: String) {
        self.source = source
        self.display = display
        self.shortDisplay = shortDisplay
        self.text = text
    }
}

/// One day of the church calendar, cached.
///
/// Keyed by **civil** date and reckoning. The API takes a civil date in the URL
/// but reports the date in the requested reckoning in the body — asking for
/// 13 January 2027 on the Julian endpoint answers with 31 December 2026. Keying
/// the cache on the reported date would misfile every Old Calendar day by
/// thirteen days, so `civilDate` is the key and `observedDate` is data.
public struct LiturgicalDay: Sendable, Hashable, Codable {
    public let civilDate: CalendarDate
    public let reckoning: Reckoning
    public let observedDate: CalendarDate

    public let tone: Int?
    public let title: String?
    public let summaryTitle: String
    public let saints: [String]
    public let feasts: [String]

    public let fastLevel: Int
    public let fastLevelDescription: String
    public let fastException: Int
    public let fastExceptionDescription: String?
    public let abstentions: [String]

    public let feastLevel: Int
    public let feastLevelDescription: String

    public let readings: [Reading]
    public let paschaDistance: Int
    public let fetchedAt: Date

    public init(
        civilDate: CalendarDate, reckoning: Reckoning, observedDate: CalendarDate,
        tone: Int?, title: String?, summaryTitle: String, saints: [String], feasts: [String],
        fastLevel: Int, fastLevelDescription: String, fastException: Int,
        fastExceptionDescription: String?, abstentions: [String],
        feastLevel: Int, feastLevelDescription: String,
        readings: [Reading], paschaDistance: Int, fetchedAt: Date
    ) {
        self.civilDate = civilDate; self.reckoning = reckoning; self.observedDate = observedDate
        self.tone = tone; self.title = title; self.summaryTitle = summaryTitle
        self.saints = saints; self.feasts = feasts
        self.fastLevel = fastLevel; self.fastLevelDescription = fastLevelDescription
        self.fastException = fastException; self.fastExceptionDescription = fastExceptionDescription
        self.abstentions = abstentions
        self.feastLevel = feastLevel; self.feastLevelDescription = feastLevelDescription
        self.readings = readings; self.paschaDistance = paschaDistance; self.fetchedAt = fetchedAt
    }

    /// orthocal fast levels: 0 none, 1 Wednesday/Friday, 2 Great Lent,
    /// 3 Apostles, 4 Dormition, 5 Nativity.
    public var isFast: Bool { fastLevel > 0 }

    /// Exception 11 is "Fast Free". Other exceptions relax a fast rather than
    /// lifting it — a feast falling on a fast day may allow fish, wine and oil.
    public var isFastFree: Bool { fastException == 11 }

    /// Feast levels 7 and 8 are the Major Feasts of the Theotokos and of the
    /// Lord — the Twelve Great Feasts and Pascha. Lower levels are ranked days
    /// rather than Great Feasts.
    public var isGreatFeast: Bool { feastLevel >= 7 }

    public var season: FastingSeason? {
        switch fastLevel {
        case 2: return .greatLent
        case 3: return .apostlesFast
        case 4: return .dormitionFast
        case 5: return .nativityFast
        default: return nil
        }
    }

    /// Wording matters: this describes what the church calendar marks, it does
    /// not instruct anyone what to eat. See the Observance section in design.md.
    public var fastDescription: String {
        guard isFast else { return fastExceptionDescription ?? fastLevelDescription }
        if let exception = fastExceptionDescription, !exception.isEmpty {
            return "\(fastLevelDescription) — \(exception)"
        }
        return fastLevelDescription
    }

    public func isStale(asOf now: Date, maxAge: TimeInterval = 60 * 60 * 24 * 30) -> Bool {
        now.timeIntervalSince(fetchedAt) > maxAge
    }
}
