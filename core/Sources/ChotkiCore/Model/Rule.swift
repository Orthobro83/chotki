import Foundation

public struct Rule: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var title: String
    /// Free text from the user.
    public var note: String?
    /// Where the rule came from — "Fr. Peter", "my godfather", "the parish
    /// bulletin". Rules arrive from other people over months and their origin
    /// matters later.
    public var source: String?
    public var recurrence: Recurrence
    /// nil means the rule runs all day — it is due, has no clock time, and
    /// is reminded differently.
    public var timeOfDay: TimeOfDay?
    public var category: String?
    /// Optional on purpose: a backup written before this existed decodes to nil
    /// rather than failing, and `effectiveReminders` supplies the default.
    public var reminders: RuleReminders?
    public var createdAt: Date
    /// Set when the rule is removed. Never deleted, so history survives.
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        note: String? = nil,
        source: String? = nil,
        recurrence: Recurrence,
        timeOfDay: TimeOfDay? = nil,
        category: String? = nil,
        reminders: RuleReminders? = nil,
        createdAt: Date = Date(),
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.source = source
        self.recurrence = recurrence
        self.timeOfDay = timeOfDay
        self.category = category
        self.reminders = reminders
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }

    public var isArchived: Bool { archivedAt != nil }

    public var effectiveReminders: RuleReminders { reminders ?? .default }

    /// Fasting rules are subject to the Church's dispensations. Keyed on the
    /// category rather than the recurrence, so it holds for a rule written by
    /// hand as well as one taken from the library.
    public var isFastingRule: Bool { category == RuleCategory.fasting.rawValue }
}

/// A stretch during which a rule is actually in force.
///
/// A list of these rather than a boolean is what makes "enable later", "pause
/// without penalty", "resume", and seasonal rules all fall out of one structure.
/// Scoring only ever looks at days covered by an activation.
public struct Activation: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let ruleID: UUID
    public var from: CalendarDate
    /// nil means still in force.
    public var to: CalendarDate?

    public init(id: UUID = UUID(), ruleID: UUID, from: CalendarDate, to: CalendarDate? = nil) {
        self.id = id
        self.ruleID = ruleID
        self.from = from
        self.to = to
    }

    public var isOpen: Bool { to == nil }

    /// `from` inclusive, `to` inclusive — a rule paused "as of today" still
    /// counts today, which is what a person means when they pause in the evening.
    public func covers(_ date: CalendarDate) -> Bool {
        guard date >= from else { return false }
        guard let to else { return true }
        return date <= to
    }
}

public enum OccurrenceStatus: String, Sendable, Hashable, Codable {
    case completed
    /// Done, but after the day was out. Scores partial rather than zero.
    case completedLate
    /// Deliberately excluded — a pause, illness, travel, a blessing to stand
    /// down. Removed from both sides of the ratio, never counted as missed.
    case skipped
    case moved
    case cancelled
}

/// Written only when a day deviates from the default.
///
/// A day with no row and a covering activation is simply due, or once its time
/// has passed, missed. Absence is the default state, not a record — which keeps
/// the table small and means "missed" needs no bookkeeping to come true.
public struct Occurrence: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let ruleID: UUID
    public let date: CalendarDate
    public var status: OccurrenceStatus
    public var completedAt: Date?
    /// Set when status is `.moved`.
    public var movedTo: CalendarDate?

    public init(
        id: UUID = UUID(),
        ruleID: UUID,
        date: CalendarDate,
        status: OccurrenceStatus,
        completedAt: Date? = nil,
        movedTo: CalendarDate? = nil
    ) {
        self.id = id
        self.ruleID = ruleID
        self.date = date
        self.status = status
        self.completedAt = completedAt
        self.movedTo = movedTo
    }
}
