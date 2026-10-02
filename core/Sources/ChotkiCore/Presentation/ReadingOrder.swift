import Foundation

/// The Android reading order, shared by the Apple interfaces.
public enum ReadingOrder {
    public static let saintLifeBand = 4
    /// The daily commemoration of the departed, for the traditions that keep it.
    public static let departedBand = 5
    /// The Akathist, present only on a Friday the Church appoints it.
    public static let akathistBand = 6

    public static func band(source: String) -> Int {
        let text = source.lowercased()
        if text.contains("matins") { return 3 }
        if text.contains("gospel") { return 0 }
        if text.contains("epistle") { return 1 }
        if text.contains("vespers") { return 2 }
        return 3
    }

    public static func band(ofTitle title: String) -> Int? {
        let text = title.lowercased()
        if text.contains("akathist") { return akathistBand }
        if text.contains("departed") { return departedBand }
        if text.contains("life of the day") && text.contains("saint") { return saintLifeBand }
        if text.contains("epistle") { return 1 }
        if text.contains("vespers") { return 2 }
        if text.contains("matins") { return 3 }
        if text.contains("gospel") { return 0 }
        return nil
    }

    public static func orderedBands(held: Set<Int>) -> [Int] {
        (0...3).filter { held.contains($0) } + (0...3).filter { !held.contains($0) }
    }

    /// The heading of a collapsible section on the Reading tab.
    ///
    /// Gospel, Epistle and the life use the library's own names. Vespers and
    /// Matins are sections of the day's readings rather than library rules.
    public static func sectionTitle(band: Int, sources: [String] = []) -> String {
        switch band {
        case 0: return "The day's Gospel"
        case 1: return "The day's Epistle"
        case 2: return "Vespers"
        case saintLifeBand: return "The life of the day's saint"
        case departedBand: return "Prayer for the departed"
        case akathistBand: return "The Akathist to the Theotokos"
        default:
            if !sources.isEmpty, sources.allSatisfy({ $0.lowercased().contains("matins") }) {
                return "Matins"
            }
            return "The other readings"
        }
    }
}

public enum ReadingCompletion {
    public static func matches(_ rule: Rule, prayer: String, counted: Bool) -> Bool {
        if counted {
            return prayer == "jesus-prayer" &&
                (rule.ropePrayerID == prayer || rule.title == "The Jesus Prayer")
        }
        switch prayer {
        case "morning": return rule.title == "Morning prayers"
        case "evening": return rule.title == "Evening prayers"
        default: return false
        }
    }
}
