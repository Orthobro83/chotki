import Foundation

/// The wording of a reflection, held as one value so that "the question as it
/// stood" is a copy rather than a description of one.
///
/// `Reflection` carries this, and so does every `ReflectionEntry`. That is the
/// snapshot rule made structural: an entry cannot accidentally point at the
/// live question, because it has no way to refer to one. Editing Sunday's
/// wording therefore cannot reach backwards into what was already written —
/// which would otherwise leave every past answer answering a question that was
/// never asked.
public struct ReflectionQuestion: Sendable, Hashable, Codable {
    public var title: String
    /// What to attend to during the day.
    public var notice: String
    /// What to write at the end of it.
    ///
    /// Six of the seven begin "At the end of the day, write down…". The text is
    /// the Brotherhood's and is not reworded, so an interface must not label
    /// this row with words that say the same thing again.
    public var task: String

    public init(title: String, notice: String, task: String) {
        self.title = title
        self.notice = notice
        self.task = task
    }
}

/// One weekday's reflection.
///
/// There is exactly one per weekday and there always will be: `weekday` is the
/// identity, not a field. Reflections are never added and never removed — only
/// rewritten — so there is no archived state and no ordering within a day.
public struct Reflection: Sendable, Hashable, Codable, Identifiable {
    public let weekday: Weekday
    public var question: ReflectionQuestion
    /// Set the first time the wording is changed from what it shipped with.
    /// nil means untouched since installation.
    public var editedAt: Date?

    public var id: Weekday { weekday }

    public init(weekday: Weekday, question: ReflectionQuestion, editedAt: Date? = nil) {
        self.weekday = weekday
        self.question = question
        self.editedAt = editedAt
    }

    public var title: String { question.title }
    public var notice: String { question.notice }
    public var task: String { question.task }

    public var isEdited: Bool { editedAt != nil }

    /// A rewrite of this reflection, stamped.
    ///
    /// Answers already written are untouched by construction — they hold their
    /// own copy of the question — so this needs no cascade and must not have one.
    public func rewritten(_ question: ReflectionQuestion, at now: Date = Date()) -> Reflection {
        Reflection(weekday: weekday, question: question, editedAt: now)
    }

    /// True when the wording has been returned to what it shipped with, whatever
    /// `editedAt` says. Used to answer "is this still the Brotherhood's text",
    /// which is a question about the words rather than about the history.
    public var matchesBundled: Bool {
        question == Reflection.bundled(for: weekday).question
    }
}

/// One answer, on one date, to one weekday's reflection.
///
/// Every field is `let`. An answer locks on save — it cannot be edited or
/// deleted afterwards — and making the type immutable means the interface
/// cannot offer that by accident.
public struct ReflectionEntry: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let weekday: Weekday
    public let date: CalendarDate
    public let text: String
    /// The question as it stood when this was written. See `ReflectionQuestion`.
    public let question: ReflectionQuestion
    public let writtenAt: Date

    public init(
        id: UUID = UUID(),
        weekday: Weekday,
        date: CalendarDate,
        text: String,
        question: ReflectionQuestion,
        writtenAt: Date = Date()
    ) {
        self.id = id
        self.weekday = weekday
        self.date = date
        self.text = text
        self.question = question
        self.writtenAt = writtenAt
    }

    /// An answer to the reflection as it currently stands, on a given day.
    ///
    /// The weekday comes from the date rather than being passed in, so an answer
    /// cannot be filed under a weekday its date does not fall on.
    public init(
        answering reflection: Reflection,
        on date: CalendarDate,
        text: String,
        id: UUID = UUID(),
        writtenAt: Date = Date()
    ) {
        self.init(
            id: id, weekday: date.weekday, date: date, text: text,
            question: reflection.question, writtenAt: writtenAt
        )
    }
}
