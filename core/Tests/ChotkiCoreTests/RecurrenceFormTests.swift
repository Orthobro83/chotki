import Testing
import Foundation
@testable import ChotkiCore

@Suite("Editing a rule loses nothing")
struct RecurrenceFormTests {

    private static let shapes: [Recurrence] = [
        .daily,
        .once(CalendarDate(year: 2026, month: 8, day: 19)!),
        .weekly(days: [.sunday]),
        .weekly(days: [.wednesday, .friday]),
        .monthly(day: 1, whenShort: .lastDay),
        .monthly(day: 31, whenShort: .lastDay),
        .monthly(day: 31, whenShort: .skip),
        .liturgical(.fastDay),
        .liturgical(.greatFeast),
        .liturgical(.season(.greatLent)),
        .liturgical(.season(.nativityFast)),
        .liturgical(.season(.apostlesFast)),
        .liturgical(.season(.dormitionFast))
    ]

    @Test("every recurrence survives a load and save unchanged", arguments: shapes)
    func roundTrip(recurrence: Recurrence) {
        let fallback = CalendarDate(year: 2026, month: 1, day: 1)!
        let form = RecurrenceForm(recurrence)
        #expect(form.recurrence(fallback: fallback) == recurrence)
    }

    @Test("a one-off day never becomes a repeating rule")
    func onceStaysOnce() {
        let day = CalendarDate(year: 2026, month: 8, day: 19)!
        let form = RecurrenceForm(.once(day))
        #expect(form.kind == .once)
        #expect(form.recurrence(fallback: CalendarDate(year: 2020, month: 1, day: 1)!) == .once(day))
    }

    @Test("a season keeps which season it was")
    func seasonKeepsItsIdentity() {
        for season in [FastingSeason.greatLent, .nativityFast, .apostlesFast, .dormitionFast] {
            let form = RecurrenceForm(.liturgical(.season(season)))
            #expect(form.kind == .season)
            #expect(form.season == season)
        }
    }

    @Test("the short-month policy is carried through, though nothing shows it")
    func policySurvives() {
        let form = RecurrenceForm(.monthly(day: 31, whenShort: .skip))
        #expect(form.shortMonthPolicy == .skip)
        let saved = form.recurrence(fallback: CalendarDate(year: 2026, month: 1, day: 1)!)
        #expect(saved == .monthly(day: 31, whenShort: .skip))
    }

    @Test("clearing every weekday falls back rather than making a rule that never runs")
    func emptyWeekdaysFallBack() {
        var form = RecurrenceForm(.weekly(days: [.sunday]))
        form.weekdays = []
        let saved = form.recurrence(fallback: CalendarDate(year: 2026, month: 1, day: 1)!)
        #expect(saved == .weekly(days: [.sunday]))
    }

    @Test("every kind the picker offers can be saved")
    func everyKindIsReachable() {
        let fallback = CalendarDate(year: 2026, month: 8, day: 19)!
        for kind in RecurrenceForm.Kind.allCases {
            var form = RecurrenceForm()
            form.kind = kind
            _ = form.recurrence(fallback: fallback)   // must not trap
        }
    }
}

/// A day still in progress is not a verdict. Progress speaks only about days
/// that are finished — otherwise a rule added this morning and not yet kept
/// counts against someone before they have had the chance.
