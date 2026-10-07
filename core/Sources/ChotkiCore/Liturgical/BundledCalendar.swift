import Foundation

/// The church calendar that ships with the app, read-only.
///
/// Generated once from Orthocal's own open-source code (`core/Tools/calendar-bundle.py`),
/// audited so that every word of scripture is public-domain KJV, and stored as one file per
/// reckoning-year. Days are decoded when first asked for and kept; nothing is written to
/// the person's record, so there is no schema change and no migration.
///
/// A day answers from here before the cache or the network is consulted. The network is a
/// refill for dates past `last`, and nothing more.
public final class BundledCalendar: @unchecked Sendable {

    public struct Manifest: Decodable, Sendable {
        public let schema: Int
        public let tradition: String
        public let first: String
        public let last: String
        public let generatedAt: String
        public let orthocalCommit: String
        public let textDigest: String
        /// A digest of every field of every day except reading text, built from the audited source.
        public let fieldsDigest: String
        public let files: [String]
    }

    private struct YearFile: Decodable {
        let y: Int
        let days: [Record]
    }

    private struct Record: Decodable {
        struct Entry: Decodable {
            let s: Int
            let d: Int
            let h: Int
            let r: [PassageRun]
        }
        let o: [Int]
        let t: Int?
        let ti: Int?
        let su: Int
        let sa: [Int]
        let fe: [Int]
        let fl: Int
        let fd: Int
        let fx: Int
        let fxd: Int?
        let ab: [Int]
        let el: Int
        let ed: Int
        let pd: Int
        let r: [Entry]
    }

    public let manifest: Manifest
    public let first: CalendarDate
    public let last: CalendarDate

    private let strings: [String]
    private let fetchedAt: Date
    private let load: @Sendable (String) -> Data?
    private let lock = NSLock()
    private var years: [String: [LiturgicalDay]] = [:]

    /// The calendar in the core bundle. Nil only if the bundle is damaged.
    public static let standard: BundledCalendar? = BundledCalendar { name in
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2, let url = BundledFile.url(parts[0], extension: parts[1], subdirectory: "calendar")
        else { return nil }
        return try? Data(contentsOf: url)
    }

    /// `load` returns the bytes of a named file ("manifest.json", "julian-2027.json", ...).
    public init?(load: @escaping @Sendable (String) -> Data?) {
        let decoder = JSONDecoder()
        guard let manifestData = load("manifest.json"),
              let manifest = try? decoder.decode(Manifest.self, from: manifestData),
              manifest.schema == 1,
              let first = CalendarDate(iso: manifest.first), let last = CalendarDate(iso: manifest.last),
              let stringData = load("strings.json"),
              let strings = try? decoder.decode([String].self, from: stringData),
              let stamp = CalendarDate(iso: manifest.generatedAt)
        else { return nil }
        self.manifest = manifest
        self.first = first
        self.last = last
        self.strings = strings
        self.load = load
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        self.fetchedAt = utc.date(from: DateComponents(year: stamp.year, month: stamp.month, day: stamp.day)) ?? Date(timeIntervalSince1970: 0)
    }

    public func covers(_ date: CalendarDate) -> Bool {
        date >= first && date <= last
    }

    public func day(civil date: CalendarDate, reckoning: Reckoning) -> LiturgicalDay? {
        guard covers(date) else { return nil }
        let days = year(date.year, reckoning: reckoning)
        guard let start = CalendarDate(year: date.year, month: 1, day: 1) else { return nil }
        let index = start.days(until: date)
        return days.indices.contains(index) ? days[index] : nil
    }

    private func year(_ year: Int, reckoning: Reckoning) -> [LiturgicalDay] {
        let name = "\(reckoning.rawValue)-\(year)"
        lock.lock(); defer { lock.unlock() }
        if let cached = years[name] { return cached }
        guard let data = load("\(name).json"),
              let file = try? JSONDecoder().decode(YearFile.self, from: data),
              let start = CalendarDate(year: year, month: 1, day: 1)
        else { years[name] = []; return [] }
        let decoded: [LiturgicalDay] = file.days.enumerated().compactMap { offset, record in
            guard record.o.count == 3, let observed = CalendarDate(year: record.o[0], month: record.o[1], day: record.o[2])
            else { return nil }
            return LiturgicalDay(
                civilDate: start.adding(days: offset), reckoning: reckoning, observedDate: observed,
                tone: record.t, title: record.ti.map { strings[$0] }, summaryTitle: strings[record.su],
                saints: record.sa.map { strings[$0] }, feasts: record.fe.map { strings[$0] },
                fastLevel: record.fl, fastLevelDescription: strings[record.fd],
                fastException: record.fx, fastExceptionDescription: record.fxd.map { strings[$0] },
                abstentions: record.ab.map { strings[$0] },
                feastLevel: record.el, feastLevelDescription: strings[record.ed],
                readings: record.r.map {
                    Reading(source: strings[$0.s], display: strings[$0.d], shortDisplay: strings[$0.h],
                            text: ScriptureText.text(for: $0.r) ?? "")
                },
                paschaDistance: record.pd, fetchedAt: fetchedAt
            )
        }
        years[name] = decoded
        return decoded
    }
}
