import Foundation

/// The journal as a file of its own.
///
/// The whole record already travels in `Backup`; this exists because a journal
/// is the part someone most wants to hold as a file they own, separately from
/// the machinery around it. Plain JSON, for the same reason `Backup` is: what
/// someone wrote should outlive this application.
public struct ReflectionArchive: Sendable, Codable {
    public var version: Int = 1
    public var exportedAt: Date
    /// The questions as they currently stand. Restored on import only where a
    /// weekday has no record here yet — an import must not silently rewrite a
    /// question the user has since edited.
    public var reflections: [Reflection]
    public var entries: [ReflectionEntry]

    public init(exportedAt: Date = Date(), reflections: [Reflection], entries: [ReflectionEntry]) {
        self.exportedAt = exportedAt
        self.reflections = reflections
        self.entries = entries
    }
}

/// What an import did, so the interface can say so rather than going quiet.
public struct ReflectionImportResult: Sendable, Hashable {
    /// Written.
    public let added: [ReflectionEntry]
    /// Already held, under the same weekday and date. Left alone.
    public let alreadyPresent: Int
    /// Dropped because two incoming entries claimed the same weekday and date.
    /// Only reachable from a `nepsis:v1` file, where two cycle days could be
    /// answered on one calendar day.
    public let collided: Int

    public var addedCount: Int { added.count }

    public init(added: [ReflectionEntry], alreadyPresent: Int, collided: Int) {
        self.added = added
        self.alreadyPresent = alreadyPresent
        self.collided = collided
    }
}

public enum ReflectionImportError: Error, Equatable {
    /// Neither shape could be read. The file is left alone and so is the record.
    case unrecognised
}

/// Reading a journal file.
///
/// Two shapes are accepted: this app's own `ReflectionArchive`, and the web
/// artifact's `nepsis:v1`, so that anything already written on the web comes
/// across rather than being retyped.
public enum ReflectionImport {

    /// The artifact's storage shape. Its `days` are keyed "1"…"7" by position in
    /// the cycle, and its entries carry no question, because on the web the
    /// seven were fixed and could not be edited.
    private struct NepsisV1: Decodable {
        struct Entry: Decodable { let date: String; let text: String }
        let days: [String: [Entry]]?
    }

    public static func read(_ data: Data, now: Date = Date()) throws -> ReflectionArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let archive = try? decoder.decode(ReflectionArchive.self, from: data) {
            return archive
        }
        if let legacy = try? decoder.decode(NepsisV1.self, from: data), legacy.days != nil {
            return ReflectionArchive(
                exportedAt: now, reflections: [], entries: entries(from: legacy, now: now)
            )
        }
        throw ReflectionImportError.unrecognised
    }

    /// Converts the artifact's shape.
    ///
    /// **The weekday comes from the date, not from the cycle number.** On the
    /// web the seven were a cycle rather than a week — "day 3" was the third
    /// prompt, whatever day it was answered on — so an entry's date may fall on
    /// any weekday. It is filed under the weekday it was actually written on
    /// and keeps the question it actually answered, which is precisely what the
    /// snapshot rule is for. Nothing has to be guessed and nothing is lost.
    private static func entries(from legacy: NepsisV1, now: Date) -> [ReflectionEntry] {
        var out: [ReflectionEntry] = []
        for (key, written) in legacy.days ?? [:] {
            guard let number = Int(key), let cycleDay = Weekday(rawValue: number) else { continue }
            let question = Reflection.bundled(for: cycleDay).question
            for entry in written {
                guard let date = CalendarDate(iso: entry.date) else { continue }
                let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                out.append(
                    ReflectionEntry(
                        weekday: date.weekday, date: date, text: text,
                        question: question, writtenAt: now
                    )
                )
            }
        }
        return out.sorted { $0.date < $1.date }
    }

    /// What merging an archive into an existing record would do. Never discards
    /// — see `ReflectionJournal.merge`.
    public static func plan(
        _ archive: ReflectionArchive, into existing: [ReflectionEntry]
    ) -> ReflectionImportResult {
        var seen = Set(existing.map { "\($0.weekday.rawValue):\($0.date.iso)" })
        var added: [ReflectionEntry] = []
        var alreadyPresent = 0
        var collided = 0
        for entry in archive.entries.sorted(by: { $0.date < $1.date }) {
            let key = "\(entry.weekday.rawValue):\(entry.date.iso)"
            if seen.contains(key) {
                // Already here from the record, or already taken by an earlier
                // entry in this same file.
                if existing.contains(where: { $0.weekday == entry.weekday && $0.date == entry.date }) {
                    alreadyPresent += 1
                } else {
                    collided += 1
                }
                continue
            }
            seen.insert(key)
            added.append(entry)
        }
        return ReflectionImportResult(added: added, alreadyPresent: alreadyPresent, collided: collided)
    }
}
