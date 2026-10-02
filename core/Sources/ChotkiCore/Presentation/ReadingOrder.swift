import Foundation

/// The Android reading order, shared by the Apple interfaces.
public enum ReadingOrder {
    public static let saintLifeBand = 4
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
