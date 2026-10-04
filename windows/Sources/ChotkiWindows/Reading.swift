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
    func readingText(band:Int) -> String? {
        guard let day=liturgical.cachedDay(for:selectedDate) else {
            if band==ReadingOrder.akathistBand,let week=liturgical.akathistWeek(selectedDate) {
                return (Akathist.paragraphs(week:week)+[Akathist.source,Akathist.sourceURL]).joined(separator:"\n\n")
            }
            return nil
        }
        switch band {
        case 0...3:
            let readings=day.readings.filter { ReadingOrder.band(source:$0.source)==band && !$0.text.isEmpty }
            guard !readings.isEmpty else { return nil }
            return readings.map { "\($0.source) · \($0.display)\n\n\($0.text)" }.joined(separator:"\n\n")
        case ReadingOrder.saintLifeBand:
            guard let life=SaintLives.reading(on:day.observedDate) else { return nil }
            var paragraphs=[life.dates]+[life.preface].compactMap { $0 }
            for section in life.sections {
                paragraphs.append(section.heading)
                for block in section.blocks {
                    if let text=block.text { paragraphs.append(text) }
                    else if let rows=block.rows { paragraphs.append(rows.map { $0.map(\.text).joined() }.joined(separator:"\n")) }
                    else { paragraphs.append((block.spans ?? []).map(\.text).joined()) }
                }
            }
            return (paragraphs+[life.source,life.sourceURL,life.licenseNote,life.license,life.licenseURL]).joined(separator:"\n\n")
        case ReadingOrder.departedBand:
            return ([DepartedCommemoration.rubric]+DepartedCommemoration.paragraphs+[DepartedCommemoration.source,DepartedCommemoration.sourceURL]).joined(separator:"\n\n")
        case ReadingOrder.akathistBand:
            guard let week=liturgical.akathistWeek(selectedDate) else { return nil }
            return ([Akathist.fallbackNote(for:settings.jurisdiction.tradition)].compactMap { $0 }+Akathist.paragraphs(week:week)+[Akathist.source,Akathist.sourceURL]).joined(separator:"\n\n")
        default: return nil
        }
    }
    func renderReading() throws {
        title("Reading",subtitle:Format.longDate(selectedDate))
        let day=liturgical.cachedDay(for:selectedDate)
        control(760,0,day?.summaryTitle ?? "No reading stored for this day yet.",contentLeft,115,contentWidth,40)
        ch_style(760,day == nil ? 64 : 128)
        let bands=try readingBands
        var y:Int32=165
        for band in bands {
            control(Int32(770+band),1,"\(readingBand == band ? "⌃" : "⌄")  \(ReadingOrder.sectionTitle(band:band))",contentLeft,y,contentWidth,36)
            y += 44
        }
        if let band=readingBand, bands.contains(band) {
            let text=readingText(band:band)
            control(301,4,(text ?? "No life is stored for this day.").replacingOccurrences(of:"\n",with:"\r\n"),contentLeft,y,contentWidth,max(100,ch_height()-y-90))
            if text != nil { trackReading(.band(band)) }
        } else if day == nil {
            control(761,0,"Connect to the internet to fetch the church calendar. Previously fetched readings remain available offline.",contentLeft,y+15,contentWidth,80)
            ch_style(761,64)
        } else if let patristic=PatristicReadings.shared.reading(for:selectedDate) {
            control(301,4,"From the Fathers\r\n\r\n\(patristic.text)\r\n\r\n\(patristic.author) · \(patristic.source)",contentLeft,y+14,contentWidth,max(100,ch_height()-y-110))
        }
        control(778,1,"The Psalter",contentLeft,ch_height()-72,160,28)
        requestCalendar()
    }
    func handleReading(control id:Int32,event:Int32) -> Bool {
        guard event==0 && ((770...776).contains(id) || id==778) else { return false }
        do {
            if id==778 { page = .prayers; showPsalter=true; selectedRow=0 }
            else { let band=Int(id-770); readingBand=readingBand == band ? nil : band }
            try render()
        } catch { actionError=error.localizedDescription }
        return true
    }
    func renderPsalter() {
        title("The Psalter",subtitle:"Brenton's Septuagint · Public domain")
        list(Psalter.all.map { "Psalm \($0.number)" },selected:selectedRow)
        let psalm=Psalter.all[min(selectedRow,Psalter.all.count-1)]
        body(([psalm.superscription].compactMap { $0 }+psalm.verses.map { "\($0.number). \($0.text)" }).joined(separator:"\n\n"))
        control(779,1,"Back to Prayers",260,595,180)
        let appointed=Kathisma.appointed(weekday:selectedDate.weekday,season:Kathisma.season(paschaDistance:Pascha.distance(on:selectedDate)))
        control(780,0,"Appointed today: "+appointed.map { "\($0.service.displayName): \($0.kathismata.map(String.init).joined(separator:", "))" }.joined(separator:" · "),260,625,770)
    }
    enum CompletionTarget { case band(Int), prayer(String) }
    func trackReading(_ target:CompletionTarget) {
        readingToken += 1; readingTarget=target
        ch_track_reading(301,readingToken)
    }
    func completeReading(token:Int32) throws {
        guard token==readingToken,let target=readingTarget else { return }
        let entries=try practice.entries(on:selectedDate)
        for entry in entries where !entry.isKept && !entry.isDispensed && !entry.isStoodDown {
            let matches:Bool
            switch target {
            case .band(let band): matches=ReadingOrder.band(ofTitle:entry.rule.title)==band
            case .prayer(let selection): matches=ReadingCompletion.matches(entry.rule,prayer:selection,counted:false)
            }
            if matches { try store.save(Occurrence(ruleID:entry.rule.id,date:entry.date,status:.completed,completedAt:Date())) }
        }
    }
    func renderPrayers() {
        if showPsalter { renderPsalter(); return }
        title("Prayers",subtitle:"\(rope.count) of \(rope.target) knots")
        let book=PrayerBook.shared.scoped(to:settings.jurisdiction.tradition)
        let sequence=rope.selection.flatMap { book.sequence(id:$0) }
        choice(321,["Morning prayers","Evening prayers"]+prayers.map(\.title),
               selected:sequence?.id == "morning" ? 0 : sequence?.id == "evening" ? 1 : (prayers.firstIndex { $0.id == rope.selection } ?? 0)+2,
               x:contentLeft,y:125,width:contentWidth)
        let held=sequence.map { book.prayers(of:$0) } ?? rope.selection.flatMap { book.prayer(id:$0) }.map { [$0] } ?? []
        let text=held.map { "\($0.title)\n\n\($0.text)\n\n\($0.source)" }.joined(separator:"\n\n")
        control(301,4,text.replacingOccurrences(of:"\n",with:"\r\n"),contentLeft,180,contentWidth,max(150,ch_height()-290))
        if let sequence { trackReading(.prayer(sequence.id)) }
        if rope.showsRope(in:book) {
            control(420,1,"Count a Knot",contentLeft,ch_height()-95,155)
            control(421,1,"Start Again",contentLeft+170,ch_height()-95,155)
            for (i,target) in PrayerScreen.targets.enumerated() { control(Int32(422+i),1,"\(target) knots",contentLeft+350+Int32(i)*110,ch_height()-95,100) }
        }
        control(779,1,"The Psalter",contentLeft,ch_height()-52,150,25)
    }
}
