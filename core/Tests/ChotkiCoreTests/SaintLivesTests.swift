import Testing
import Foundation
@testable import ChotkiCore

@Suite("Lives of the day's saints")
struct SaintLivesTests {
    @Test("every church day is present, and February 29 is not in the prologue")
    func everyDay() {
        // The published page for February 29 says the reading could not be found.
        // A leap day on the Old Calendar observes February 16, which is present.
        #expect(SaintLives.availableDayCount == 365)
        #expect(SaintLives.reading(on: CalendarDate(year: 2024, month: 2, day: 29)!) == nil)
        #expect(SaintLives.reading(on: CalendarDate(year: 2024, month: 2, day: 16)!) != nil)
        #expect(SaintLives.reading(on: CalendarDate(year: 2023, month: 2, day: 28)!) != nil)
    }

    @Test("the old calendar and the new calendar are both recorded, and the text is the page's")
    func calendarsAndText() throws {
        let boniface = try #require(SaintLives.reading(on: CalendarDate(year: 2026, month: 12, day: 19)!))
        #expect(boniface.dates == "December 19 / January 1")
        #expect(boniface.gregorianMonth == 1 && boniface.gregorianDay == 1)
        #expect(boniface.sourceURL == "https://app.ochrid.com/prologue?day=01-01")
        #expect(boniface.license == "CC BY-SA 4.0")
        #expect(boniface.licenseURL == "https://creativecommons.org/licenses/by-sa/4.0/")
        #expect(boniface.licenseNote.contains("The text is unchanged."))
        let opening = try #require(prose(of: boniface).first)
        #expect(opening.hasPrefix("Martyrdom for Christ makes a saint out of a sinner. This is shown by the example of Saint Boniface."))
        #expect(opening.contains("upon parting with Aglaida Boniface said to her: If I cannot find any martyr, and if they bring you my body tormented for Christ, will you receive it with honor?"))
        let spoken = boniface.sections.flatMap(\.blocks).flatMap { $0.spans ?? [] }.first { $0.italic }
        #expect(spoken?.text == "If I cannot find any martyr, and if they bring you my body tormented for Christ, will you receive it with honor?")

        // Civil January 1 on the New Calendar observes January 1, not December 19.
        let circumcision = try #require(SaintLives.reading(on: CalendarDate(year: 2026, month: 1, day: 1)!))
        #expect(circumcision.dates == "January 1 / January 14")
        #expect(circumcision.gregorianMonth == 1 && circumcision.gregorianDay == 14)
        #expect(circumcision.sourceURL == "https://app.ochrid.com/prologue?day=01-14")
        #expect(prose(of: circumcision).first?.hasPrefix("On the eighth day after His birth") == true)

        // The same church day is what the Old Calendar observes thirteen days later.
        #expect(SaintLives.reading(on: CalendarDate(year: 2026, month: 1, day: 1)!)?.dates
                == circumcision.dates)
    }

    @Test("the bundled words contain no markup")
    func noMarkup() {
        for life in lives {
            #expect(!life.dates.contains("*"))
            for section in life.sections {
                #expect(!section.heading.contains("*"))
                for block in section.blocks {
                    #expect(block.text?.contains("*") != true)
                    for span in (block.spans ?? []) + (block.rows ?? []).flatMap({ $0 }) {
                        #expect(!span.text.contains("*"), "markup left in \(life.dates)")
                        #expect(!span.text.contains("<"), "a tag left in \(life.dates)")
                    }
                }
            }
        }
    }

    private var lives: [SaintLife] {
        (1...12).flatMap { month in
            (1...31).compactMap { day in
                CalendarDate(year: 2024, month: month, day: day).flatMap { SaintLives.reading(on: $0) }
            }
        }
    }

    private func prose(of life: SaintLife) -> [String] {
        life.sections.flatMap(\.blocks).compactMap { block in
            block.spans.map { $0.map(\.text).joined() }
        }
    }
}
