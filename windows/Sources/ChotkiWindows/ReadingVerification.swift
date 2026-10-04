import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func activateReaderLink(_ desired: ReaderLink) throws {
        let index = (readerLinkOwners[301] ?? []).firstIndex { readerLinks[$0] == desired }
        guard let index else { throw BootstrapError.verification("Missing inline reader link: \(desired)") }
        try require(ch_test_link(301, Int32(index)) == 1, "Inline reader link did not activate")
        ch_pump()
        try require(actionError == nil, actionError ?? "Inline reader action failed")
    }
    func verifyReadingSections() throws {
        calendarTask?.cancel(); calendarGeneration += 1
        let date = selectedDate
        guard let original = liturgical.cachedDay(for: date) else { throw BootstrapError.verification("Reading fixture date") }
        // The synthetic store alone receives longer sections, so a partial
        // scroll can distinguish a read Gospel from an unread Epistle.
        let gospelText = (1...55).map { "Gospel passage \($0). Blessed are the merciful, for they shall obtain mercy." }.joined(separator: "\n")
        let epistleText = (1...55).map { "Epistle passage \($0). Rejoice always. Pray without ceasing." }.joined(separator: "\n")
        let readings = [Reading(source: "Gospel", display: "Synthetic Gospel", shortDisplay: "Gospel", text: gospelText),
                        Reading(source: "Epistle", display: "Synthetic Epistle", shortDisplay: "Epistle", text: epistleText)]
        func cached(_ distance: Int, readings: [Reading]) throws {
            let day = LiturgicalDay(civilDate: date, reckoning: original.reckoning, observedDate: original.observedDate,
                tone: original.tone, title: original.title, summaryTitle: original.summaryTitle,
                saints: original.saints, feasts: original.feasts, fastLevel: original.fastLevel,
                fastLevelDescription: original.fastLevelDescription, fastException: original.fastException,
                fastExceptionDescription: original.fastExceptionDescription, abstentions: original.abstentions,
                feastLevel: original.feastLevel, feastLevelDescription: original.feastLevelDescription,
                readings: readings, paschaDistance: distance, fetchedAt: Date())
            try store.saveLiturgicalDay(day); try liturgical.loadSnapshot(around: date)
        }
        try cached(original.paschaDistance, readings: readings)
        var testRules: [Rule] = []
        for title in ["The day's Gospel", "The day's Epistle"] {
            let rule = RuleLibrary.shared.templates.first { $0.title == title }!.makeRule(source: "synthetic review")
            try store.save(rule); try store.save(Activation(ruleID: rule.id, from: date))
            testRules.append(rule)
        }
        page = .reading; readingBand=nil; try render()
        ch_test_scroll_end(301,1); ch_pump()
        for rule in testRules { try require(try store.occurrences(ruleID: rule.id, from: date, through: date).isEmpty, "Collapsed heading completed a rule") }
        try activateReaderLink(.readingSection(0)); try activateReaderLink(.readingSection(1))
        try require(expandedReadingBands == [0,1], "Opening an inline section collapsed its neighbor")
        let document = text(301)
        try require(document.range(of: "Gospel passage 55")!.lowerBound < document.range(of: "The day's Epistle")!.lowerBound && document.range(of: "The day's Epistle")!.lowerBound < document.range(of: "Epistle passage 1")!.lowerBound, "Reading bodies are detached from their headings")
        ch_test_scroll_end(301,0); ch_pump()
        let settledPaints = ch_test_reader_paint_count(301)
        let settledLine = ch_test_reader_first_line(301)
        _ = ch_test_reader_wheel_delta(301, -120, 3); ch_pump()
        try require(ch_test_reader_first_line(301) == settledLine && ch_test_reader_paint_count(301) == settledPaints,
                    "Overscrolling reading: line \(settledLine) to \(ch_test_reader_first_line(301)), paints \(settledPaints) to \(ch_test_reader_paint_count(301))")
        for rule in testRules { try require(try store.occurrences(ruleID: rule.id, from: date, through: date).isEmpty, "Programmatic inline scroll marked a rule") }
        let staleEpistle = readingCompletions.first { if case .band(1) = $0.value { return true }; return false }!.key
        try activateReaderLink(.readingSection(1))
        ch_post(-6,staleEpistle); ch_pump()
        try require(try store.occurrences(ruleID:testRules[1].id,from:date,through:date).isEmpty, "Stale completion marked a collapsed section")
        try activateReaderLink(.readingSection(1))
        ch_reader_scroll_line(301,0)
        let gospelEnd = document.range(of: "The day's Epistle")!.lowerBound
        let position = Int32(document[..<gospelEnd].replacingOccurrences(of: "\r\n", with: "\r").replacingOccurrences(of: "\n", with: "\r").utf16.count)-1
        ch_test_scroll_character(301,position,1); ch_pump()
        try require(try store.occurrences(ruleID:testRules[0].id,from:date,through:date).first?.status == .completed, "Partial scroll did not finish the Gospel")
        try require(try store.occurrences(ruleID:testRules[1].id,from:date,through:date).isEmpty, "Finishing the Gospel completed the unread Epistle")
        try activateReaderLink(.readingSection(0))
        try require(expandedReadingBands == [1], "Independent inline collapse")
        ch_test_scroll_end(301,1); ch_pump()
        try require(try store.occurrences(ruleID:testRules[1].id,from:date,through:date).first?.status == .completed, "Epistle completion after its neighbor collapsed")
        ch_reader_scroll_line(301,0)
        let readingFirstLine=ch_test_reader_first_line(301)
        try require(ch_test_reader_wheel(301,2)>readingFirstLine,"Reading mouse wheel did not move the reader")
        // Restore public text for visual review.
        try cached(original.paschaDistance, readings: original.readings)
        expandedReadingBands=[0,1]; try render(); ch_reader_scroll_line(301,0)
        try captureReview("reading-inline")

        guard let template = RuleLibrary.shared.templates.first(where: { $0.makeRule(source: nil).reference == .psalter }) else { throw BootstrapError.verification("Psalter template") }
        let psalter = template.makeRule(source: "synthetic review")
        try store.save(psalter); try store.save(Activation(ruleID: psalter.id, from: date))
        page = .prayers; showPsalter=true; appointedKathisma=nil; manualKathisma=nil
        try render(); ch_test_scroll_end(301,1); ch_pump()
        try require(try store.occurrences(ruleID:psalter.id,from:date,through:date).isEmpty, "Psalter headings completed the rule")
        let first = appointedPsalter.first!.kathismata.first!
        try require(ch_test_link_key(301) == 1, "Keyboard appointed disclosure")
        ch_pump()
        try require(appointedKathisma == first, "Enter did not expand the appointed kathisma")
        try require(ch_test_link_key(301) == 1, "Keyboard appointed collapse")
        ch_pump()
        try require(appointedKathisma == nil && readingCompletions.isEmpty, "Enter did not close the appointed kathisma")
        try activateReaderLink(.kathisma(first,manual:false))
        try require(appointedKathisma == first && text(301).contains("Psalm \(Kathisma.psalms(in:first)!.lowerBound)"), "Appointed kathisma did not open its psalms")
        ch_test_scroll_end(301,0); ch_pump()
        try require(try store.occurrences(ruleID:psalter.id,from:date,through:date).isEmpty, "Programmatic kathisma scroll completed a rule")
        ch_test_scroll_end(301,1); ch_pump()
        try require(try store.occurrences(ruleID:psalter.id,from:date,through:date).first?.status == .completed, "Last kathisma verse did not complete the Psalter rule")
        try store.removeOccurrence(ruleID:psalter.id,date:date)
        for number in 1...20 {
            try choose(781,number)
            let psalms = Psalter.kathisma(number)
            let shown = text(301)
            try require(manualKathisma == number && shown.contains(psalms.first!.verses.first!.text) && shown.contains(psalms.last!.verses.last!.text), "Manual kathisma \(number) is missing its first or last verse")
        }
        ch_pump()
        try require(try store.occurrences(ruleID:psalter.id,from:date,through:date).isEmpty, "Choosing a manual kathisma completed its rule")
        try choose(781,17)
        try require(manualKathisma == 17 && appointedKathisma == first && text(301).contains("Chosen for Reading") && text(301).contains("Psalm 118"), "Manual kathisma replaced the appointed choice or has the wrong range")
        try activateReaderLink(.kathisma(17,manual:true))
        try require(manualKathisma == nil && appointedKathisma == first, "Closing manual reading changed the appointed kathisma")
        ch_reader_scroll_line(301,0); try captureReview("psalter")
        ch_test_resize(620,540); ch_reader_scroll_line(301,0); try captureReview("psalter-narrow")
        ch_test_resize(1100,860)
        // Same civil date, changed cached season: use the calendar's distance,
        // not a second local calculation or a duplicated appointment table.
        try cached(2, readings: original.readings); appointedKathisma=nil; try render()
        try require(appointedPsalter.isEmpty && text(301).contains("The Psalter is not read through Bright Week."), "Bright Week appointment differs from the shared calendar")
        try captureReview("psalter-bright-week")
        try store.removeOccurrence(ruleID:psalter.id,date:date)
        try choose(781,20)
        try require(text(301).contains("Psalm 150") && !text(301).contains("Psalm 151"), "Manual kathisma range includes the unappointed Psalm 151")
        try store.save(Occurrence(ruleID:psalter.id,date:date,status:.skipped))
        ch_test_scroll_end(301,1); ch_pump()
        try require(try store.occurrences(ruleID:psalter.id,from:date,through:date).first?.status == .skipped, "Kathisma completion overwrote a stood-down day")
        try cached(original.paschaDistance, readings: original.readings)
        for var rule in testRules + [psalter] { rule.archivedAt=Date(); try store.save(rule) }
        appointedKathisma=nil; manualKathisma=nil; expandedReadingBands.removeAll()
        try press(779)
        try require(!showPsalter && rope.selection != nil, "Psalter return lost the prayer selection")
        print("Inline reading/Psalter UI passed: independent disclosures, per-section deliberate-scroll completion, programmatic-scroll rejection, appointed services, all 20 manual kathismata, cached Bright Week, responsive reader and stood-down preservation.")
    }
}
