import Foundation

/// A rule offered in the library.
///
/// Enabling one **copies** it into the user's own rule. It does not stay linked,
/// so the copy can be renamed, retimed and rewritten freely — a rule taken from
/// the library and a rule written from scratch are the same kind of thing
/// afterwards, with no second-class citizens.
public struct RuleTemplate: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let title: String
    /// Shown under the title in the library, explaining what taking it on means.
    public let summary: String
    public let note: String?
    public let recurrence: Recurrence
    public let timeOfDay: TimeOfDay?
    public let category: RuleCategory
    public let reminders: RuleReminders
    /// Empty means offered to everyone.
    public let traditions: Set<Tradition>
    /// Terms in the glossary worth reading alongside it.
    public let glossarySlugs: [String]
    /// The prayers this rule carries, in the order they are said.
    public let prayerIDs: [String]

    public init(
        id: String, title: String, summary: String, note: String? = nil,
        recurrence: Recurrence, timeOfDay: TimeOfDay? = nil,
        category: RuleCategory, reminders: RuleReminders = .default,
        traditions: Set<Tradition> = [], glossarySlugs: [String] = [],
        prayerIDs: [String] = []
    ) {
        self.id = id; self.title = title; self.summary = summary; self.note = note
        self.recurrence = recurrence; self.timeOfDay = timeOfDay
        self.category = category; self.reminders = reminders
        self.traditions = traditions; self.glossarySlugs = glossarySlugs
        self.prayerIDs = prayerIDs
    }

    /// The observance this rule needs before it will ever come due.
    ///
    /// A `.liturgical` rule produces nothing while its observance is merely
    /// shown, so taking one on without turning the observance on is a silent
    /// no-op. Callers use this to avoid that.
    public var requiredTrigger: LiturgicalTrigger? {
        if case .liturgical(let trigger) = recurrence { return trigger }
        // A fasting rule that is not itself liturgical — the Wednesday and
        // Friday fast is simply weekly — still wants the calendar marking fast
        // days, and still answers to the Church's dispensations.
        if category == .fasting { return .fastDay }
        return nil
    }

    public func appliesTo(_ tradition: Tradition) -> Bool {
        traditions.isEmpty || traditions.contains(tradition)
    }

    /// A fresh rule, owned by the user, carrying no link back here.
    public func makeRule(source: String? = nil) -> Rule {
        Rule(
            title: title, note: note, source: source,
            recurrence: recurrence, timeOfDay: timeOfDay,
            category: category.rawValue, reminders: reminders,
            prayerIDs: prayerIDs.isEmpty ? nil : prayerIDs
        )
    }
}

public struct RuleLibrary: Sendable {
    public let templates: [RuleTemplate]

    public init(templates: [RuleTemplate] = RuleLibrary.bundled) {
        self.templates = templates
    }

    public static let shared = RuleLibrary()

    public func template(id: String) -> RuleTemplate? {
        templates.first { $0.id == id }
    }

    public func scoped(to tradition: Tradition) -> RuleLibrary {
        RuleLibrary(templates: templates.filter { $0.appliesTo(tradition) })
    }

    /// Grouped for display, in category order, skipping empty groups.
    /// The prayers a rule ought to carry, for one taken from the library before
    /// rules carried prayers at all.
    ///
    /// `prayer_ids` arrived in schema 5 as a nullable column with nothing to
    /// fill it in, so every rule taken on before that reads as having no
    /// prayers: no way through to the words, on the rules most likely to want
    /// them. The first Evening prayers found this — taken on 20 August, two days
    /// before the prayers existed.
    ///
    /// Matched on the title, which `makeRule` copies from the template verbatim.
    /// A renamed rule is left alone rather than guessed at, and so is a rule
    /// whose prayers were set to none deliberately: only `nil`, meaning never
    /// set, is treated as missing.
    public func restoredPrayerIDs(for rule: Rule) -> [String]? {
        guard rule.prayerIDs == nil else { return nil }
        guard let template = templates.first(where: {
            $0.title.compare(rule.title, options: .caseInsensitive) == .orderedSame
        }) else { return nil }
        return template.prayerIDs.isEmpty ? nil : template.prayerIDs
    }

    /// The rules that need repairing, already repaired. Rules needing nothing
    /// are left out, so the caller writes only what changed.
    public func restoringPrayers(in rules: [Rule]) -> [Rule] {
        rules.compactMap { rule in
            guard let ids = restoredPrayerIDs(for: rule) else { return nil }
            var repaired = rule
            repaired.prayerIDs = ids
            return repaired
        }
    }

    public func byCategory() -> [(RuleCategory, [RuleTemplate])] {
        RuleCategory.ordered.compactMap { category in
            let matching = templates.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }
}
