import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    var psalterSeason: Kathisma.Season {
        liturgical.cachedDay(for: selectedDate).map { Kathisma.season(paschaDistance: $0.paschaDistance) } ?? .ordinary
    }
    var appointedPsalter: [Kathisma.Appointed] {
        Kathisma.appointed(weekday: selectedDate.weekday, season: psalterSeason)
    }
    func openPsalter() {
        page = .prayers; showPsalter=true; rulePrayerID=nil; selectedRow=0
        appointedKathisma=nil; manualKathisma=nil
    }
    func renderPsalter() {
        title("The Psalter", subtitle: Format.longDate(selectedDate))
        choice(781, ["Browse All Kathismata"] + (1...20).map { "Kathisma \($0)" },
               selected: 0, x: contentLeft, y: 115, width: min(260,contentWidth))
        var document = ReaderDocument()
        if let number = manualKathisma {
            document.line("Chosen for Reading", flags: 4 | 16, size: 13)
            appendKathisma(number, manual: true, to: &document)
        }
        let appointed = appointedPsalter
        if appointed.isEmpty {
            document.line("No kathisma is appointed today.", flags: 4, size: 18)
            document.line(psalterSeason == .brightWeek ? "The Psalter is not read through Bright Week." : "Nothing is appointed for this day.", flags: 4 | 16, size: 12)
        } else {
            for entry in appointed {
                document.line(entry.service.displayName, flags: 8 | 16, size: 12)
                for number in entry.kathismata { appendKathisma(number, manual: false, to: &document) }
            }
        }
        document.source(Psalter.source, url: Psalter.sourceURL)
        reader(document, x: contentLeft, y: 165, width: contentWidth, height: max(150,ch_height()-255))
        control(779,1,"Back to Prayers",contentLeft,ch_height()-72,180,28)
        requestCalendar()
    }
    func appendKathisma(_ number: Int, manual: Bool, to document: inout ReaderDocument) {
        guard let range = Kathisma.psalms(in: number) else { return }
        let expanded = manual ? manualKathisma == number : appointedKathisma == number
        let caption = range.lowerBound == range.upperBound ? "Psalm \(range.lowerBound)" : "Psalms \(range.lowerBound)–\(range.upperBound)"
        document.disclosure("Kathisma \(number) · \(caption)", expanded: expanded, flags: 128, size: 18,
                            link: .kathisma(number, manual: manual))
        guard expanded else { return }
        let psalms = Psalter.kathisma(number)
        for psalm in psalms {
            document.line("Psalm \(psalm.number)", flags: 8 | 16, size: 12)
            if let title = psalm.superscription { document.line(title, flags: 2 | 4, size: 12) }
            for verse in psalm.verses { document.line("\(verse.number)  \(verse.text)", size: 12) }
        }
        if !psalms.isEmpty { document.finish(.psalter) }
    }
    func handlePsalter(control id: Int32, event: Int32) -> Bool {
        guard id == 781 && event == 1 else { return false }
        let number = Int(ch_selected(781))
        guard (1...20).contains(number) else { return true }
        manualKathisma = number
        do { try render() } catch { actionError=error.localizedDescription }
        return true
    }
}
