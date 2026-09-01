import Testing
import Foundation
@testable import ChotkiCore

private func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDate {
    CalendarDate(year: y, month: m, day: day)!
}

private func q(_ title: String) -> ReflectionQuestion {
    ReflectionQuestion(title: title, notice: "notice \(title)", task: "task \(title)")
}

/// September 2026 begins on a Tuesday, so its Sundays are the 6th, 13th, 20th
/// and 27th.
private func sundays(_ days: [Int], text: (Int) -> String = { "answer \($0)" }) -> [ReflectionEntry] {
    days.map { day in
        let date = d(2026, 9, day)
        return ReflectionEntry(
            weekday: date.weekday, date: date, text: text(day),
            question: q("Notice the Resistance"), writtenAt: Date()
        )
    }
}

@Suite("The seven as they shipped")
struct ReflectionContentTests {

    @Test("there is exactly one for every weekday, and no weekday is missed")
    func sevenOfThem() {
        #expect(Reflection.bundled.count == 7)
        #expect(Set(Reflection.bundled.map(\.weekday)) == Set(Weekday.allCases))
    }

    @Test("they are in weekday order, Sunday first")
    func inOrder() {
        #expect(Reflection.bundled.map(\.weekday) == Weekday.allCases)
        #expect(Reflection.bundled.first?.weekday == .sunday)
        #expect(Reflection.bundled.last?.weekday == .saturday)
    }

    /// The titles are the Brotherhood's; the mapping to weekdays was Ryan's
    /// instruction — the first is Sunday, running through to Saturday.
    @Test("the titles land on the weekdays they were given for")
    func titles() {
        #expect(Reflection.bundled(for: .sunday).title == "Notice the Resistance")
        #expect(Reflection.bundled(for: .monday).title == "Notice the Quiet")
        #expect(Reflection.bundled(for: .tuesday).title == "Notice the Comfort")
        #expect(Reflection.bundled(for: .wednesday).title == "Notice the Avoidance")
        #expect(Reflection.bundled(for: .thursday).title == "Notice the Pattern")
        #expect(Reflection.bundled(for: .friday).title == "Notice the Cost")
        #expect(Reflection.bundled(for: .saturday).title == "Bring It Forward")
    }

    @Test("every one carries both halves, and none is a placeholder")
    func bothHalves() {
        for reflection in Reflection.bundled {
            #expect(!reflection.title.isEmpty)
            #expect(reflection.notice.count > 40, "\(reflection.weekday) notice looks like a stub")
            #expect(reflection.task.count > 30, "\(reflection.weekday) task looks like a stub")
            #expect(!reflection.notice.lowercased().contains("placeholder"))
        }
    }

    /// Saturday's directs the reader to liturgy and confession. If that is ever
    /// lost in an edit the section quietly stops being what it was for.
    @Test("Saturday still points to liturgy and confession")
    func saturdayPointsOnward() {
        let saturday = Reflection.bundled(for: .saturday).notice.lowercased()
        #expect(saturday.contains("confession"))
        #expect(saturday.contains("liturgy"))
    }

    @Test("nothing shipped is marked as edited")
    func notEdited() {
        for reflection in Reflection.bundled {
            #expect(reflection.editedAt == nil)
            #expect(reflection.isEdited == false)
            #expect(reflection.matchesBundled)
        }
    }
}

@Suite("Rewriting a reflection")
struct ReflectionRewriteTests {

    @Test("a rewrite is stamped and no longer matches what shipped")
    func rewriting() {
        let now = Date()
        let sunday = Reflection.bundled(for: .sunday)
        let after = sunday.rewritten(q("Something of my own"), at: now)

        #expect(after.weekday == .sunday)
        #expect(after.title == "Something of my own")
        #expect(after.editedAt == now)
        #expect(after.isEdited)
        #expect(after.matchesBundled == false)
    }

    /// The snapshot rule, and the one that matters most: it is what stops a past
    /// answer from silently answering a question that was never asked.
    @Test("rewriting the question cannot reach an answer already written")
    func rewritingLeavesAnswersAlone() {
        let sunday = Reflection.bundled(for: .sunday)
        let entry = ReflectionEntry(answering: sunday, on: d(2026, 9, 6), text: "what I saw")

        _ = sunday.rewritten(q("Rewritten"))

        #expect(entry.question == sunday.question)
        #expect(entry.question.title == "Notice the Resistance")
    }

    @Test("returning the wording by hand matches what shipped again")
    func rewritingBack() {
        let sunday = Reflection.bundled(for: .sunday)
        let away = sunday.rewritten(q("elsewhere"))
        let back = away.rewritten(sunday.question)

        #expect(back.matchesBundled)
        // The stamp survives even though the words match again: whether it was
        // touched is a different question from whether it differs.
        #expect(back.isEdited)
    }
}

@Suite("An answer")
struct ReflectionEntryTests {

    @Test("takes its weekday from its date, so it cannot be misfiled")
    func weekdayFromDate() {
        let sunday = ReflectionEntry(
            answering: Reflection.bundled(for: .sunday), on: d(2026, 9, 6), text: "x")
        #expect(sunday.weekday == .sunday)

        // Answering Sunday's question on a Wednesday files it under Wednesday
        // and keeps Sunday's wording. That is the snapshot doing its job rather
        // than a bug: what was answered is recorded, and so is when.
        let strayed = ReflectionEntry(
            answering: Reflection.bundled(for: .sunday), on: d(2026, 9, 9), text: "x")
        #expect(strayed.weekday == .wednesday)
        #expect(strayed.question.title == "Notice the Resistance")
    }

    @Test("carries the question as it stood, not a reference to it")
    func carriesTheQuestion() {
        let entry = ReflectionEntry(
            answering: Reflection.bundled(for: .friday), on: d(2026, 9, 4), text: "the cost")
        #expect(entry.question == Reflection.bundled(for: .friday).question)
    }
}

@Suite("A period")
struct ReflectionPeriodTests {

    @Test("all of it contains everything")
    func all() {
        #expect(ReflectionPeriod.all.isAll)
        #expect(ReflectionPeriod.all.contains(d(1999, 1, 1)))
        #expect(ReflectionPeriod.all.contains(d(2026, 9, 6)))
    }

    @Test("a year on its own takes every month in it")
    func yearOnly() {
        let period = ReflectionPeriod(year: 2026)
        #expect(period.contains(d(2026, 1, 1)))
        #expect(period.contains(d(2026, 12, 31)))
        #expect(period.contains(d(2025, 12, 31)) == false)
        #expect(period.isAll == false)
    }

    @Test("a month on its own takes that month in every year")
    func monthOnly() {
        let period = ReflectionPeriod(month: 9)
        #expect(period.contains(d(2026, 9, 6)))
        #expect(period.contains(d(2019, 9, 30)))
        #expect(period.contains(d(2026, 8, 31)) == false)
    }

    @Test("both together take one month of one year")
    func both() {
        let period = ReflectionPeriod(year: 2026, month: 9)
        #expect(period.contains(d(2026, 9, 1)))
        #expect(period.contains(d(2026, 8, 31)) == false)
        #expect(period.contains(d(2025, 9, 1)) == false)
    }
}

@Suite("Stepping through one weekday's answers")
struct ReflectionSeriesTests {

    private var series: ReflectionSeries {
        ReflectionJournal.series(sundays([6, 13, 20]), on: .sunday)
    }

    @Test("newest first")
    func order() {
        #expect(series.entries.map(\.date.day) == [20, 13, 6])
        #expect(series.count == 3)
    }

    /// The direction is the part that is easy to get backwards, and was got
    /// backwards once in the mockup before this type existed. Entries are
    /// newest first, so older means a **higher** index.
    @Test("the older arrow walks back in time")
    func older() {
        #expect(series.older(than: 0) == 1)
        #expect(series.entry(at: series.older(than: 0)!)?.date.day == 13)
        #expect(series.older(than: 1) == 2)
        #expect(series.entry(at: series.older(than: 1)!)?.date.day == 6)
    }

    @Test("the newer arrow walks forward in time")
    func newer() {
        #expect(series.newer(than: 2) == 1)
        #expect(series.newer(than: 1) == 0)
        #expect(series.entry(at: series.newer(than: 1)!)?.date.day == 20)
    }

    /// Wrapping would make a journal feel like a carousel. The arrows disable.
    @Test("it stops at both ends rather than wrapping")
    func endsAreEnds() {
        #expect(series.newer(than: 0) == nil)
        #expect(series.older(than: 2) == nil)
    }

    @Test("position reads one-based, for '2 of 3'")
    func position() {
        #expect(series.position(of: 0)?.ordinal == 1)
        #expect(series.position(of: 0)?.total == 3)
        #expect(series.position(of: 2)?.ordinal == 3)
        #expect(series.position(of: 3) == nil)
    }

    @Test("an empty series has no position and no steps")
    func empty() {
        let none = ReflectionJournal.series([], on: .sunday)
        #expect(none.isEmpty)
        #expect(none.position(of: 0) == nil)
        #expect(none.older(than: 0) == nil)
        #expect(none.newer(than: 0) == nil)
        #expect(none.entry(at: 0) == nil)
    }

    @Test("a date can be found in it")
    func findingADate() {
        #expect(series.index(of: d(2026, 9, 13)) == 1)
        #expect(series.index(of: d(2026, 9, 7)) == nil)
    }
}

@Suite("What the record says")
struct ReflectionJournalTests {

    @Test("a weekday's series holds only that weekday")
    func onlyThatWeekday() {
        var all = sundays([6, 13])
        let wednesday = d(2026, 9, 9)
        all.append(ReflectionEntry(
            weekday: wednesday.weekday, date: wednesday, text: "w",
            question: q("Notice the Avoidance")))

        #expect(ReflectionJournal.series(all, on: .sunday).count == 2)
        #expect(ReflectionJournal.series(all, on: .wednesday).count == 1)
        #expect(ReflectionJournal.series(all, on: .friday).isEmpty)
    }

    @Test("a period scopes the series")
    func periodScopes() {
        var all = sundays([6, 13])
        let august = d(2026, 8, 30)
        all.append(ReflectionEntry(
            weekday: august.weekday, date: august, text: "august", question: q("t")))

        #expect(ReflectionJournal.series(all, on: .sunday).count == 3)
        #expect(ReflectionJournal.series(all, on: .sunday, in: ReflectionPeriod(month: 9)).count == 2)
        #expect(ReflectionJournal.series(all, on: .sunday, in: ReflectionPeriod(month: 8)).count == 1)
        #expect(ReflectionJournal.series(all, on: .sunday, in: ReflectionPeriod(year: 2025)).isEmpty)
    }

    /// "When did I last write this one" is a question about the record, not
    /// about the filter, so a period must not be able to change the answer.
    @Test("the most recent answer ignores the period entirely")
    func mostRecentIgnoresPeriod() {
        let all = sundays([6, 13, 20])
        #expect(ReflectionJournal.mostRecent(all, on: .sunday)?.date.day == 20)
        #expect(ReflectionJournal.mostRecent([], on: .sunday) == nil)
    }

    @Test("a date already answered is known to be answered")
    func hasEntry() {
        let all = sundays([6, 13])
        #expect(ReflectionJournal.hasEntry(all, on: d(2026, 9, 6)))
        #expect(ReflectionJournal.hasEntry(all, on: d(2026, 9, 20)) == false)
    }

    @Test("only years and months that hold something are offered")
    func yearsAndMonths() {
        var all = sundays([6, 13])
        for (y, m, day) in [(2025, 11, 16), (2026, 7, 26)] {
            let date = d(y, m, day)
            all.append(ReflectionEntry(
                weekday: date.weekday, date: date, text: "x", question: q("t")))
        }
        #expect(ReflectionJournal.years(all) == [2026, 2025])
        #expect(ReflectionJournal.months(all, year: 2026) == [7, 9])
        #expect(ReflectionJournal.months(all, year: 2025) == [11])
        #expect(ReflectionJournal.months(all, year: 2024) == [])
    }
}

@Suite("Merging a journal in")
struct ReflectionMergeTests {

    /// The rule the artifact learned first: an import is additive. A file from
    /// a stale export must never be able to overwrite an answer written since.
    @Test("what is already held always wins")
    func neverDiscards() {
        let existing = sundays([6, 13]) { "mine \($0)" }
        let incoming = sundays([6, 20]) { "theirs \($0)" }

        let added = ReflectionJournal.merge(existing: existing, incoming: incoming)
        #expect(added.count == 1)
        #expect(added.first?.date.day == 20)
        #expect(added.first?.text == "theirs 20")
    }

    @Test("importing the same file twice adds nothing the second time")
    func idempotent() {
        let existing = sundays([6])
        let incoming = sundays([6, 13])

        let first = ReflectionJournal.merge(existing: existing, incoming: incoming)
        #expect(first.count == 1)

        let second = ReflectionJournal.merge(existing: existing + first, incoming: incoming)
        #expect(second.isEmpty)
    }

    @Test("nothing incoming leaves the record alone")
    func nothingIncoming() {
        #expect(ReflectionJournal.merge(existing: sundays([6]), incoming: []).isEmpty)
    }
}

@Suite("Reflections in the library")
struct ReflectionLibraryTests {

    private var template: RuleTemplate? {
        RuleLibrary.bundled.first { $0.id == "reflection" }
    }

    /// One entry, not seven. Seven near-identical rows, each repeating the same
    /// explanation, was noise in a list people scroll to choose from.
    @Test("there is exactly one, and it is called Reflection")
    func oneEntry() throws {
        let found = try #require(template, "no library rule for Reflections")
        #expect(found.title == reflectionRuleTitle)
        #expect(found.title == "Reflection")
        #expect(found.category == .life)

        let perWeekday = RuleLibrary.bundled.filter { $0.id.hasPrefix("reflection-") }
        #expect(perWeekday.isEmpty, "the seven-per-weekday entries are gone")
    }

    /// "adds all 7 days (recurring)" — which is one rule that recurs every day,
    /// reading simply "Reflection" on each of them. Which question is being
    /// asked is the section's business, not the rule list's.
    @Test("it recurs every day")
    func daily() throws {
        let found = try #require(template)
        #expect(found.recurrence == .daily)
    }

    /// A reflection is noticed through the day, not answered on a schedule.
    @Test("it does not ring")
    func silent() throws {
        let found = try #require(template)
        #expect(found.reminders == .silent)
        #expect(found.timeOfDay == nil)
    }

    @Test("its note is short and points at the section for the rest")
    func shortNote() throws {
        let found = try #require(template)
        let note = try #require(found.note)
        #expect(note == Reflection.libraryNote)
        #expect(note.contains("Click on the Reflections tab to learn more."))
    }

    @Test("it links the terms it sends you to")
    func linksItsTerms() throws {
        let found = try #require(template)
        #expect(found.glossarySlugs.contains("confession"))
        #expect(found.glossarySlugs.contains("spiritual-father"))
    }

    /// The row has to offer a way through to the section, on every surface.
    /// Deciding that here rather than in each interface is what stops one
    /// platform having the link and the other not.
    @Test("a rule of this title points at Reflections")
    func pointsAtTheSection() throws {
        let found = try #require(template)
        #expect(found.makeRule().reference == .reflections)
    }

    /// Renaming it makes it his rule rather than this one, and the way through
    /// goes with it. Same as the Psalter rule, for the same reason.
    @Test("a renamed copy is an ordinary rule again")
    func renamedLosesTheLink() throws {
        let found = try #require(template)
        var rule = found.makeRule()
        rule.title = "My own reflections"
        #expect(rule.reference == .none)
    }

    /// Nothing is enabled by default. The seven questions are seeded because
    /// they are the section's content; the rule is not, because taking a rule
    /// on is always deliberate.
    @Test("it is offered, not enabled")
    func offeredNotEnabled() throws {
        let store = InMemoryStore()
        try store.seedReflections()
        #expect(try store.reflections().count == 7)
        #expect(try store.rules(includeArchived: true).isEmpty)
    }
}

@Suite("What the section says it is for")
struct ReflectionExplainerTests {

    private var whole: String {
        Reflection.explainer.flatMap { $0.spans.map(\.text) }.joined()
    }

    @Test("it is three paragraphs and none of them is empty")
    func shape() {
        #expect(Reflection.explainer.count == 3)
        for paragraph in Reflection.explainer {
            #expect(!paragraph.spans.isEmpty)
            #expect(paragraph.spans.allSatisfy { !$0.text.isEmpty })
        }
    }

    /// Ryan's words, and his correction: "aspects", not "aspect".
    @Test("the text is as he wrote it")
    func hisWords() {
        #expect(whole.hasPrefix("Most people walk into Christianity expecting peace and comfort."))
        #expect(whole.contains("reflect on aspects of your spiritual life"))
        #expect(whole.contains("aspect of your") == false, "the singular was corrected")
        #expect(whole.contains("in consultation with your priest or spiritual father"))
    }

    /// One link, and it is the address already in `Welcome` — not a second one
    /// found for the same place.
    @Test("the Brotherhood is linked, once, to the address the app already uses")
    func theLink() {
        let linked = Reflection.explainer.flatMap(\.spans).filter { $0.url != nil }
        #expect(linked.count == 1)
        #expect(linked.first?.text == "Brotherhood of the Narrow Path")
        #expect(linked.first?.url == Welcome.brotherhoodURL)
    }

    /// The last line tells the reader to click a button. If the button is
    /// renamed and this is not, it tells them to click something that is not
    /// there — so both come from one constant, and this proves it.
    @Test("it names the button by the button's own name")
    func namesTheButton() {
        #expect(Reflection.addAsRuleLabel == "Add this as a daily rule")
        #expect(whole.contains("\"\(Reflection.addAsRuleLabel)\""))
    }

    /// The library gets a short version and sends people here for the rest.
    /// Repeating three paragraphs in a list is what made the library unreadable.
    @Test("the library note is short, and points back at this")
    func libraryNote() {
        #expect(!Reflection.libraryNote.isEmpty)
        #expect(Reflection.libraryNote.count < whole.count / 2)
        #expect(Reflection.libraryNote.contains("Click on the Reflections tab to learn more."))
    }
}
