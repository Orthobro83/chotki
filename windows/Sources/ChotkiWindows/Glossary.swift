import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    var glossary: Glossary { Glossary.shared(for: settings.jurisdiction.tradition) }
    func followReaderLink(_ id: Int32) throws {
        guard let link = readerLinks[id] else { return }
        switch link {
        case .readingSection(let band):
            guard page == .reading && !glossaryDetouring else { return }
            let line = ch_first_visible_line(301)
            if expandedReadingBands.contains(band) { expandedReadingBands.remove(band) }
            else { expandedReadingBands.insert(band) }
            try render(); ch_reader_scroll_line(301, line)
        case .kathisma(let number, let manual):
            guard page == .prayers && showPsalter && !glossaryDetouring else { return }
            let line = ch_first_visible_line(301)
            if manual { manualKathisma = manualKathisma == number ? nil : number }
            else { appointedKathisma = appointedKathisma == number ? nil : number }
            try render(); ch_reader_scroll_line(301, line)
        case .term(let slug):
            showGlossaryTerm(slug)
        case .source(let address):
            guard let url = URL(string: address), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return }
            if review { reviewedSourceURL = address }
            else if address.withCString({ ch_open_url($0) }) == 0 { throw RuleInputError(message: "The source could not be opened in your browser.") }
        }
    }
    func showGlossaryTerm(_ slug:String) {
            guard glossary.entry(slug: slug) != nil else { return }
            glossarySlug = slug; glossaryQuery = ""
            if page != .glossary && !glossaryDetouring {
                glossaryDetouring = true
                ch_glossary_begin(contentLeft, 16, contentWidth, ch_height()-32)
                control(6063, 1, "‹ Back to \(page == .prayers ? "Prayers" : page == .library ? "Library" : page == .home ? "Home" : "Reading")", 12, 12, 210)
                control(6064, 0, "Search terms", 12, 48, contentWidth-24, 16)
                ch_style(6064,64)
                control(6060, 3, "", 12, 70, max(180, contentWidth-24))
                control(6062, 1, "All terms", 12, 114, 140, 28)
            }
            renderGlossaryBody()
            ch_focus(6014)
    }
    func renderGlossary() {
        title("Glossary", subtitle: "Words used in prayer and the church calendar")
        control(6064, 0, "Search terms", contentLeft, 96, contentWidth, 18)
        ch_style(6064,64)
        control(6060, 3, glossaryQuery, contentLeft, 115, contentWidth)
        control(6062, 1, "All terms", contentLeft, 158, 140, 28)
        renderGlossaryBody()
    }
    func renderGlossaryBody() {
        var document = ReaderDocument()
        if let slug = glossarySlug, let entry = glossary.entry(slug: slug) {
            document.line(entry.term, flags: 8, size: 24)
            if let pronunciation = entry.pronunciation { document.line(pronunciation, flags: 4 | 16, size: 13) }
            document.line(entry.full, size: 18)
            let related = glossary.related(to: entry)
            if !related.isEmpty {
                document.line("See also", flags: 4 | 16, size: 13)
                for other in related { document.line(other.term, flags: 8 | 16, size: 14, link: .term(other.slug)) }
            }
        } else {
            let found = glossaryQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? glossary.entries : glossary.search(glossaryQuery)
            let visible = Set(found.map(\.slug))
            for (category, entries) in glossary.byCategory {
                let matching = entries.filter { visible.contains($0.slug) }
                guard !matching.isEmpty else { continue }
                document.line(category.displayName, flags: 8 | 16, size: 13)
                for entry in matching {
                    document.line(entry.term, flags: 1, size: 18, link: .term(entry.slug))
                    document.line(entry.short, flags: 4 | 16, size: 13)
                }
            }
            if found.isEmpty { document.line("No matching terms.", flags: 4, size: 16) }
        }
        ch_remove(6014)
        let x: Int32 = glossaryDetouring ? 12 : contentLeft
        let y: Int32 = glossaryDetouring ? 155 : 202
        reader(document, id: 6014, x: x, y: y, width: glossaryDetouring ? contentWidth-24 : contentWidth,
               height: max(120, ch_height()-y-(glossaryDetouring ? 70 : 55)))
    }
    func handleGlossary(_ id: Int32, event: Int32) -> Bool {
        guard page == .glossary || glossaryDetouring else { return false }
        if id == 6063 && event == 0 {
            glossaryDetouring = false; glossarySlug = nil; glossaryQuery = ""
            for link in readerLinkOwners.removeValue(forKey: 6014) ?? [] { readerLinks.removeValue(forKey: link) }
            ch_glossary_close()
            if glossaryResized {
                glossaryResized = false
                do { try render() } catch { actionError = error.localizedDescription }
            }
            return true
        }
        if id == 6062 && event == 0 {
            glossarySlug = nil; renderGlossaryBody(); return true
        }
        if id == 6060 && event == 768 {
            glossaryQuery = text(6060); glossarySlug = nil; renderGlossaryBody(); return true
        }
        return false
    }
}
