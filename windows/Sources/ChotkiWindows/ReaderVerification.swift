import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func verifyReaderControls() throws {
        try press(102); try choosePrayer("morning")
        let book = PrayerBook.shared.scoped(to: settings.jurisdiction.tradition)
        let morning = book.sequence(id: "morning")!
        let prayers = book.prayers(of: morning)
        let document = prayerDocument(prayers)
        let terms = document.runs.compactMap { run -> String? in
            if case .term(let slug) = run.link { return slug }; return nil
        }
        try require(!terms.isEmpty && Set(terms).count == terms.count, "Prayer terms must link only once across the whole sequence")
        let count = rope.count, selection = rope.selection

        ch_test_scroll_end(301, 0); ch_pump()
        let position = ch_first_visible_line(301)
        let identity = ch_test_reader_identity(301)
        for _ in 0..<40 {
            try render()
            try require(ch_test_reader_identity(301) == identity && ch_first_visible_line(301) == position,
                        "Reader redraw replaced its native control or lost position")
        }
        for _ in 0..<20 {
            try require(ch_test_link(301, 0) == 1, "Repeated glossary link")
            ch_pump()
            try require(glossaryDetouring, "Repeated glossary detour")
            try press(6063)
            try require(ch_test_reader_identity(301) == identity && ch_first_visible_line(301) == position,
                        "Repeated glossary return lost the native reader")
        }
        try require(position > 0, "Reader scroll fixture")
        let first = document.runs.first { $0.link != nil }!
        guard case .term(let slug) = first.link else { throw BootstrapError.verification("First prayer link") }

        try require(ch_test_link(301, 0) == 1, "Native prayer hyperlink")
        ch_pump()
        try require(glossaryDetouring && glossarySlug == slug && text(6014).contains(glossary.entry(slug: slug)!.term), "Prayer term did not open its glossary definition")

        try captureReview("glossary-detour")

        ch_test_resize(1100,820)
        try require(glossaryDetouring && glossarySlug == slug, "Resize closed the glossary detour")
        ch_test_resize(1100,860)

        try press(6062)
        try require(glossarySlug == nil && text(6014).contains("The church year"), "All terms re-opened the original slug")

        enter(6060, "zzzz-no-match")
        try require(text(6014).contains("No matching terms."), "Glossary search did not filter terms")
        enter(6060, "Pascha")
        try require(text(6014).contains("Pascha") && !text(6014).contains("No matching terms."), "Glossary term search")
        try require(ch_test_link(6014, 0) == 1, "Search-result hyperlink")
        ch_pump()
        try require(glossarySlug != nil, "Search result did not open a definition")
        if let entry = glossarySlug.flatMap({ glossary.entry(slug: $0) }), !glossary.related(to: entry).isEmpty {
            let next = glossary.related(to: entry)[0].slug
            try require(ch_test_link(6014, 0) == 1, "Related-term hyperlink"); ch_pump()
            try require(glossarySlug == next, "Related glossary term did not navigate")
        }

        try press(6063)
        try require(!glossaryDetouring && ch_first_visible_line(301) == position && rope.count == count && rope.selection == selection,
                    "Glossary return lost reading position or prayer count")

        try require(ch_test_link_key(301) == 1, "Keyboard glossary link")
        ch_pump()
        try require(glossaryDetouring, "Enter did not open the focused glossary term")

        try press(6063)
        // Native character ranges count UTF-16, including a supplementary character.
        var sample = ReaderDocument()
        sample.line("A 😀 rubric", flags: 2, size: 13)
        sample.line("Amen", flags: 1, link: .term("amen"))
        sample.source("Public source", url: "https://example.org/source")
        ch_remove(301)
        reader(sample, x: contentLeft, y: 180, width: contentWidth, height: 350)
        try require(ch_test_rich_flags(301, 0) & 2 != 0, "Rubric italic style")
        let termStart = Int32("A 😀 rubric\r".utf16.count)
        try require(ch_test_rich_flags(301, termStart) & 33 == 33, "Unicode offsets lost bold/link formatting")
        reviewedSourceURL = nil

        try require(ch_test_link(301, 1) == 1, "Source-credit hyperlink"); ch_pump()
        try require(reviewedSourceURL == "https://example.org/source", "Source did not use the browser route")

        try press(106)
        try require(!glossaryDetouring && text(6014).contains("The church year"), "Standalone categorized glossary")
        try captureReview("glossary")
        page = .prayers; try render(); try captureReview("prayers")
        print("Reader UI passed: styled rubrics/headings, UTF-16 link ranges, once-per-sequence terms, glossary/search/related navigation, preserved scroll and rope state, and clickable source credits.")
    }
}
