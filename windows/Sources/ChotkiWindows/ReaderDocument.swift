import Foundation
import ChotkiCore
import WindowsUI

enum ReaderLink: Equatable { case term(String), source(String), readingSection(Int), kathisma(Int, manual: Bool) }
@MainActor
struct ReaderRun {
    var text: String
    var flags: Int32 = 0
    var size: Int32 = 18
    var link: ReaderLink? = nil
    var completion: WindowsApp.CompletionTarget? = nil
}
@MainActor
struct ReaderDocument {
    var runs: [ReaderRun] = []
    mutating func line(_ text: String, flags: Int32 = 0, size: Int32 = 18, link: ReaderLink? = nil) {
        runs.append(ReaderRun(text: text, flags: flags, size: size, link: link))
        runs.append(ReaderRun(text: "\n", size: size))
    }
    mutating func disclosure(_ title: String, expanded: Bool, flags: Int32, size: Int32, link: ReaderLink) {
        runs.append(ReaderRun(text: title, flags: flags | 64, size: size, link: link))
        // Charter and Segoe UI lack these chevrons; Segoe UI Symbol has them.
        runs.append(ReaderRun(text: expanded ? "  ⌃" : "  ⌄", flags: 8 | 16 | 64 | 256, size: 13, link: link))
        runs.append(ReaderRun(text: "\n", size: size))
    }
    mutating func prose(_ text: String, matches: [TermMatch], flags: Int32 = 0, size: Int32 = 18) {
        var cursor = text.startIndex
        for match in matches {
            if cursor < match.range.lowerBound { runs.append(ReaderRun(text: String(text[cursor..<match.range.lowerBound]), flags: flags, size: size)) }
            runs.append(ReaderRun(text: String(text[match.range]), flags: flags, size: size, link: .term(match.slug)))
            cursor = match.range.upperBound
        }
        if cursor < text.endIndex { runs.append(ReaderRun(text: String(text[cursor...]), flags: flags, size: size)) }
        runs.append(ReaderRun(text: "\n"))
    }
    mutating func finish(_ target: WindowsApp.CompletionTarget) {
        guard !runs.isEmpty else { return }
        runs[runs.count-1].completion = target
    }
    mutating func append(_ document: ReaderDocument) { runs.append(contentsOf: document.runs) }
    mutating func source(_ title: String, url: String?) {
        line(title, flags: 4 | 16, size: 12, link: url.map { .source($0) })
    }
}

extension WindowsApp {
    func reader(_ document: ReaderDocument, id: Int32 = 301, x: Int32, y: Int32, width: Int32, height: Int32) {
        for link in readerLinkOwners[id] ?? [] { readerLinks.removeValue(forKey: link) }
        readerLinkOwners[id] = []
        // Rich Edit indexes UTF-16 with a single CR for each paragraph boundary.
        let normalized = document.runs.map { run -> ReaderRun in
            var result = run
            result.text = run.text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r")
            return result
        }
        control(id, 19, normalized.map(\.text).joined(), x, y, width, height)
        var start: Int32 = 0
        var precedingLink: ReaderLink?
        var precedingLinkID: Int32 = -1
        for run in normalized {
            let length = Int32(run.text.utf16.count)
            var linkID: Int32 = -1
            if let link = run.link {
                if link == precedingLink { linkID = precedingLinkID }
                else {
                    linkID = nextReaderLink; nextReaderLink += 1; readerLinks[linkID] = link
                    readerLinkOwners[id, default: []].append(linkID)
                }
            }
            precedingLink=run.link; precedingLinkID=linkID
            ch_rich_style(id, start, length, run.flags, run.size, linkID)
            start += length
            if let target = run.completion {
                readingToken += 1
                readingCompletions[readingToken] = target
                readingTarget = target
                ch_track_reading_range(id, max(0, start-1), readingToken)
            }
        }
        ch_rich_finish(id)
    }
    func prayerDocument(_ prayers: [Prayer]) -> ReaderDocument {
        let matches = Glossary.shared(for: settings.jurisdiction.tradition).scanOnce(across: prayers.map(\.paragraphs))
        var document = ReaderDocument()
        for (index, prayer) in prayers.enumerated() {
            document.line(prayer.title, flags: 8 | 16, size: 13)
            if let rubric = prayer.rubric { document.line(rubric, flags: 2 | 4, size: 13) }
            for (paragraph, text) in prayer.paragraphs.enumerated() { document.prose(text, matches: matches[index][paragraph]) }
            document.source("Source · \(prayer.source)", url: prayer.sourceURL)
        }
        return document
    }
    func readingDocument(band: Int) -> ReaderDocument? {
        var document = ReaderDocument()
        if band == ReadingOrder.akathistBand, let week = liturgical.akathistWeek(selectedDate) {
            document.line(Akathist.heading(week: week), flags: 8, size: 20)
            if let note = Akathist.fallbackNote(for: settings.jurisdiction.tradition) { document.line(note, flags: 4 | 16, size: 13) }
            let paragraphs = Akathist.paragraphs(week: week)
            let matches = Glossary.shared(for: settings.jurisdiction.tradition).scanOnce(paragraphs)
            for (index, paragraph) in paragraphs.enumerated() { document.prose(paragraph, matches: matches[index]) }
            document.source(Akathist.source, url: Akathist.sourceURL)
            return document
        }
        guard let day = liturgical.cachedDay(for: selectedDate) else { return nil }
        switch band {
        case 0...3:
            let readings = day.readings.filter { ReadingOrder.band(source: $0.source) == band && !$0.text.isEmpty }
            guard !readings.isEmpty else { return nil }
            for reading in readings {
                document.line("\(reading.source) · \(reading.display)", flags: 4 | 16, size: 13)
                document.line(reading.text)
            }
        case ReadingOrder.saintLifeBand:
            guard let life = SaintLives.reading(on: day.observedDate) else { return nil }
            document.line(life.dates, flags: 8, size: 19)
            if let preface = life.preface { document.line(preface) }
            for section in life.sections {
                document.line(section.heading, flags: 1, size: 18)
                for block in section.blocks {
                    if let text = block.text { document.line(text, flags: block.kind == "heading" ? 1 : 0, size: 17) }
                    else {
                        for row in block.rows ?? [block.spans ?? []] {
                            for span in row { document.runs.append(ReaderRun(text: span.text, flags: (span.bold ? 1 : 0) | (span.italic ? 2 : 0))) }
                            document.line("")
                        }
                    }
                }
            }
            document.source(life.source, url: life.sourceURL)
            document.line(life.licenseNote, flags: 4 | 16, size: 12)
            document.source(life.license, url: life.licenseURL)
        case ReadingOrder.departedBand:
            document.line(DepartedCommemoration.rubric, flags: 4 | 16, size: 13)
            for paragraph in DepartedCommemoration.paragraphs { document.line(paragraph) }
            document.source(DepartedCommemoration.source, url: DepartedCommemoration.sourceURL)
        default: return nil
        }
        return document
    }
}
