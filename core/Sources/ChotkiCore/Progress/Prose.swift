import Foundation

/// Turns a set of scores into sentences.
///
/// This is the part of the report that leads, because "evening prayers slipped
/// twice, both Fridays" tells someone something they can act on, and a
/// percentage does not.
///
/// The constraints are binding, and tested:
/// nothing is phrased as failure; nothing compares the reader against a target,
/// against other people, or against a better past self; a broken streak is
/// never the subject of a sentence; and standing something down is described
/// neutrally, because it is a legitimate act rather than a lapse.
enum Prose {

    static func summary(for scores: [RuleScore]) -> [String] {
        let live = scores.filter(\.hasAnythingDue)
        guard !live.isEmpty else {
            return ["Nothing has come due yet. This fills in as the days pass."]
        }

        var lines: [String] = []

        let slipped = live.filter { $0.missed > 0 }.sorted { $0.missed > $1.missed }
        let held = live.filter { $0.missed == 0 }

        if slipped.isEmpty {
            lines.append(everythingHeld(live))
        } else {
            for score in slipped.prefix(3) {
                lines.append(describe(score))
            }
            if slipped.count > 3 {
                lines.append("A few others slipped once or twice as well.")
            }
            if !held.isEmpty {
                lines.append(held.count == 1
                    ? "\(held[0].title) held throughout."
                    : "Everything else held.")
            }
        }

        if let late = lateNote(live) { lines.append(late) }
        if let paused = stoodDownNote(live) { lines.append(paused) }

        return lines
    }

    // MARK: pieces

    private static func everythingHeld(_ scores: [RuleScore]) -> String {
        if scores.count == 1 {
            return "You kept \(lowerFirst(scores[0].title)) every time it came round."
        }
        return "You kept everything you took on."
    }

    private static func describe(_ score: RuleScore) -> String {
        let times = frequency(score.missed)
        if let pattern = weekdayPattern(score.missedDates) {
            return "\(score.title) slipped \(times), \(pattern)."
        }
        return "\(score.title) slipped \(times)."
    }

    /// Only reported when every slip fell on the same weekday and there is more
    /// than one — otherwise it is noise dressed as insight.
    private static func weekdayPattern(_ dates: [CalendarDate]) -> String? {
        guard dates.count >= 2 else { return nil }
        let weekdays = Set(dates.map(\.weekday))
        guard weekdays.count == 1, let day = weekdays.first else { return nil }
        return "all on \(plural(day))"
    }

    private static func lateNote(_ scores: [RuleScore]) -> String? {
        let late = scores.reduce(0) { $0 + $1.keptLate }
        guard late > 0 else { return nil }
        return late == 1
            ? "One was kept a little after the day was out, which still counts."
            : "\(count(late).capitalizedFirst) were kept after the day was out, which still counts."
    }

    /// Neutral by design. Standing a rule down is a legitimate act, so it is
    /// reported as a fact about the record and never as something to explain.
    private static func stoodDownNote(_ scores: [RuleScore]) -> String? {
        let total = scores.reduce(0) { $0 + $1.stoodDown }
        guard total > 0 else { return nil }
        return total == 1
            ? "One day was stood down and is not counted either way."
            : "\(count(total).capitalizedFirst) days were stood down and are not counted either way."
    }

    // MARK: words

    /// "once", "twice", then "three times" and so on.
    private static func frequency(_ n: Int) -> String {
        switch n {
        case 1: return "once"
        case 2: return "twice"
        default: return "\(count(n)) times"
        }
    }

    private static func count(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six",
                     "seven", "eight", "nine", "ten"]
        return n < words.count ? words[n] : "\(n)"
    }

    private static func plural(_ day: Weekday) -> String {
        ["Sundays", "Mondays", "Tuesdays", "Wednesdays",
         "Thursdays", "Fridays", "Saturdays"][day.rawValue - 1]
    }

    private static func lowerFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
