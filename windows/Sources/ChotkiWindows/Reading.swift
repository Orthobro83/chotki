import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    var readingBands: [Int] {
        get throws {
            var result: [Int] = []
            if let day=liturgical.cachedDay(for:selectedDate) {
                let held=Set(try practice.entries(on:selectedDate).compactMap { ReadingOrder.band(ofTitle:$0.rule.title) })
                result=ReadingOrder.orderedBands(held:held).filter { band in day.readings.contains { ReadingOrder.band(source:$0.source)==band } }
                result.append(ReadingOrder.saintLifeBand)
                if settings.jurisdiction.tradition.isSlavic || held.contains(ReadingOrder.departedBand) { result.append(ReadingOrder.departedBand) }
            }
            if liturgical.akathistWeek(selectedDate) != nil { result.append(ReadingOrder.akathistBand) }
            return result
        }
    }
    func renderReading() throws {
        title("Reading",subtitle:Format.longDate(selectedDate))
        let day=liturgical.cachedDay(for:selectedDate)
        control(760,0,day?.title ?? (day == nil ? "No reading stored for this day yet." : ""),contentLeft,115,contentWidth,24)
        ch_style(760,64)
        var document = ReaderDocument()
        if let day {
            document.prose(day.summaryTitle, matches: glossary.scan(day.summaryTitle), flags: 8, size: 22)
            if settings.observances.fasting.isVisible && day.isFast {
                document.line("The calendar marks this as \(day.fastDescription).", flags: 1024 | 16, size: 13)
                if !day.abstentions.isEmpty { document.line("Customarily set aside: \(day.abstentions.joined(separator: ", ")).", flags: 4 | 16, size: 13) }
            }
        }
        for band in try readingBands {
            let expanded = expandedReadingBands.contains(band)
            let sources = day?.readings.filter { ReadingOrder.band(source: $0.source) == band }.map(\.source) ?? []
            document.disclosure(ReadingOrder.sectionTitle(band: band, sources: sources), expanded: expanded,
                                flags: 128, size: 22, link: .readingSection(band))
            if expanded {
                if let text = readingDocument(band: band) {
                    document.append(text); document.finish(.band(band))
                } else {
                    if band == ReadingOrder.saintLifeBand, let day {
                        document.line(day.saints.joined(separator: " · "), flags: 4, size: 16)
                    }
                    document.line("No reading is stored for this section.", flags: 4 | 16, size: 13)
                }
            }
        }
        if day == nil {
            document.line("Connect to the internet to fetch the church calendar. Previously fetched readings remain available offline.", flags: 4 | 16, size: 13)
        }
        if day != nil, let patristic = PatristicReadings.shared.reading(for: selectedDate) {
            document.line("From the Fathers", flags: 4 | 16, size: 13)
            document.line(patristic.text)
            document.line("\(patristic.author) · \(patristic.source)", flags: 4 | 16, size: 13)
        }
        if let day {
            let calendar = liturgical.isOffline ? "cached" : settings.jurisdiction.reckoning == .julian ? "old calendar" : "new calendar"
            document.line("\(day.paschaDistance) days since Pascha" + (day.tone.map { " · tone \($0)" } ?? "") + " · \(calendar)", flags: 4 | 16, size: 12)
        }
        for index in document.runs.indices where document.runs[index].flags == 0 { document.runs[index].flags = 512 }
        reader(document, x: contentLeft, y: 145, width: contentWidth, height: max(150,ch_height()-235))
        control(778,1,"The Psalter",contentLeft,ch_height()-72,160,28)
        requestCalendar()
    }
    func handleReading(control id:Int32,event:Int32) -> Bool {
        guard event==0 && id==778 else { return false }
        openPsalter()
        do { try render() } catch { actionError=error.localizedDescription }
        return true
    }
    enum CompletionTarget { case band(Int), prayer(String), psalter }
    func trackReading(_ target:CompletionTarget) {
        readingToken += 1; readingTarget=target
        readingCompletions[readingToken]=target
        ch_track_reading(301,readingToken)
    }
    func completeReading(token:Int32) throws {
        guard let target=readingCompletions[token] else { return }
        let entries=try practice.entries(on:selectedDate)
        for entry in entries where !entry.isKept && !entry.isDispensed && !entry.isStoodDown {
            let matches:Bool
            switch target {
            case .band(let band): matches=ReadingOrder.band(ofTitle:entry.rule.title)==band
            case .psalter: matches=entry.rule.reference == .psalter
            case .prayer(let selection): matches=ReadingCompletion.matches(entry.rule,prayer:selection,counted:false)
            }
            if matches { try store.save(Occurrence(ruleID:entry.rule.id,date:entry.date,status:.completed,completedAt:Date())) }
        }
        try refreshReminders()
    }
}
