import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    struct PrayerChoice {
        let selection: String?
        let title: String
        let group: String
    }
    var prayerChoices: [PrayerChoice] {
        let book = PrayerBook.shared.scoped(to: settings.jurisdiction.tradition)
        return [PrayerChoice(selection:nil,title:"The rope alone",group:"")]
            + PrayerBook.shared.sequences.map { PrayerChoice(selection:$0.id,title:$0.title,group:"Rules") }
            + book.forRope().map { PrayerChoice(selection:$0.id,title:$0.title,group:"On the rope") }
            + book.notForRope().map { PrayerChoice(selection:$0.id,title:$0.title,group:"Read") }
    }
    func renderPrayers() throws {
        if let id=rulePrayerID { try renderRulePrayers(id); return }
        if showPsalter { renderPsalter(); return }
        title("Prayers",subtitle:"")
        let book = PrayerBook.shared.scoped(to: settings.jurisdiction.tradition)
        let choices = prayerChoices
        let index = choices.firstIndex { $0.selection == rope.selection } ?? 0
        let width = min(760,contentWidth), left = contentLeft+(contentWidth-width)/2
        control(321,24,choices[index].title,left+(width-min(250,width))/2,110,min(250,width),34)
        for (index, choice) in choices.enumerated() {
            choice.title.withCString { title in choice.group.withCString { group in ch_choice_add(321,title,group,Int32(index)) } }
        }
        ch_select(321,Int32(index))
        let shown = rope.showsRope(in:book)
        let compact = ch_height()<700
        var y: Int32 = compact ? 150 : 160
        if shown {
            let rows = Int32((rope.target+9)/10)
            let panelHeight: Int32 = (compact ? 66 : 100)+rows*(compact ? 9 : 12)
            control(426,20,"",left,y,width,panelHeight)
            ch_style(426,compact ? 1 : 0)
            ch_rope_update(426,Int32(rope.count),Int32(rope.target))
            y += panelHeight+10
            control(420,22,"Count",left,y,width,compact ? 34 : 42)
            y += compact ? 40 : 48
            control(427,25,"Click, or press space.",left,y,width,22)
            ch_style(427,64)
            y += compact ? 26 : 34
        }
        if let selection = rope.selection {
            let sequence = book.sequence(id:selection)
            let held = sequence.map { book.prayers(of:$0) } ?? book.prayer(id:selection).map { [$0] } ?? []
            let document = sequence != nil ? prayerDocument(held) : held.first.map(singlePrayerDocument) ?? ReaderDocument()
            reader(document,x:left,y:y,width:width,height:max(60,ch_height()-y-105))
            if sequence == nil { ch_rich_center(301) }
            if let sequence { trackReading(.prayer(sequence.id)) }
        }
        let footerY = ch_height()-88
        if shown {
            for (index,target) in PrayerScreen.targets.enumerated() {
                let id = Int32(422+index)
                control(id,23,"\(target)",left+Int32(index)*48,footerY,42,26)
                ch_style(id,rope.target == target ? 1 : 0)
            }
            control(421,18,"Start again",left+150,footerY,100,26)
            ch_style(421,64)
        }
        control(425,18,shown ? "Hide rope" : "Show rope",left+width-95,footerY,95,26)
        control(779,18,"The Psalter",left,ch_height()-52,110,25)
        ch_prayer_keys(shown ? 1 : 0)
    }
    func renderRulePrayers(_ id:UUID) throws {
        title("Prayers",subtitle:"")
        var document=ReaderDocument()
        if let rule=try store.rule(id:id),rule.hasPrayers {
            let prayers=rule.prayers
            let matches=glossary.scanOnce(across:prayers.map(\.paragraphs))
            for (index,prayer) in prayers.enumerated() {
                document.line(prayer.title,flags:8|16,size:11)
                if let rubric=prayer.rubric { document.line(rubric,flags:4|16|2,size:11) }
                for (paragraph,text) in prayer.paragraphs.enumerated() { document.prose(text,matches:matches[index][paragraph],size:15) }
                document.source("Source · \(prayer.source)",url:prayer.sourceURL)
                document.line("",size:15)
            }
            document.line("These are the prayers common to almost every form of this rule. Prayer books differ, and the full rule is settled with your priest or spiritual father.",flags:4|16,size:11)
            document.line("Where to read more",flags:4|16,size:11)
            for source in PrayerSources.further {
                document.line(source.title,flags:8|16,size:11,link:.source(source.url))
                document.line(source.organisation,flags:4|16,size:10)
            }
        } else {
            document.line("No prayers are attached to this rule.",flags:4|16,size:12)
            document.line("Rules you write yourself carry none unless you add them.",flags:4|16,size:11)
        }
        let left=contentLeft,width=contentWidth,height=max(150,ch_height()-220)
        control(23990,26,"",left,110,width,height)
        reader(document,x:left+44,y:144,width:max(120,width-88),height:max(82,height-68))
        // Received prayers can be consulted without recording the rule as kept.
        ch_prayer_keys(0)
        control(23991,18,"Back to Prayers",left,ch_height()-72,160,28)
    }
    func singlePrayerDocument(_ prayer:Prayer) -> ReaderDocument {
        var document=ReaderDocument()
        let matches=glossary.scanOnce(prayer.paragraphs)
        for (index,text) in prayer.paragraphs.enumerated() { document.prose(text,matches:matches[index],size:20) }
        document.source("Source · \(prayer.source)",url:prayer.sourceURL)
        return document
    }
    func handlePrayer(_ id:Int32,event:Int32) throws -> Bool {
        if page == .prayers && id==23991 && event==0 { rulePrayerID=nil; try render(); return true }
        guard rulePrayerID==nil && page == .prayers && !showPsalter && editor == nil && !glossaryDetouring else { return false }
        if id == 321 {
            if event == 0 { ch_choice_popup(321); return true }
            if event == 1 {
                let index = Int(ch_selected(321))
                guard prayerChoices.indices.contains(index) else { return true }
                rope.choose(prayerChoices[index].selection); try render(); return true
            }
        }
        guard event == 0 else { return false }
        if id == 425 {
            rope.showRope(!rope.showsRope(in:PrayerBook.shared.scoped(to:settings.jurisdiction.tradition)))
            try render(); return true
        }
        guard (420...424).contains(id) else { return false }
        guard rope.showsRope(in:PrayerBook.shared.scoped(to:settings.jurisdiction.tradition)) else { return true }
        if id == 420 {
            let before=rope.count
            let completed=rope.advance()
            if rope.count != before {
                if completed { if settings.chimeOnCompletion { _=ch_sound_play(1) } }
                else if settings.tickEachKnot { _=ch_sound_play(0) }
            }
            if completed, let selection = rope.selection {
                for entry in try practice.entries(on:selectedDate) where !entry.isKept && !entry.isDispensed && !entry.isStoodDown && ReadingCompletion.matches(entry.rule,prayer:selection,counted:true) {
                    try store.save(Occurrence(ruleID:entry.rule.id,date:entry.date,status:.completed,completedAt:Date()))
                }
            }
        } else if id == 421 { rope.startAgain() }
        else { rope.aim(at:PrayerScreen.targets[Int(id)-422]); try render(); return true }
        // Counting and resetting update only the counter, retaining text,
        // native focus, selection and reading position.
        ch_rope_update(426,Int32(rope.count),Int32(rope.target))
        try refreshReminders()
        return true
    }
    func choosePrayer(_ selection:String?) throws {
        guard let index = prayerChoices.firstIndex(where: { $0.selection == selection }) else { throw BootstrapError.verification("Prayer choice") }
        try choose(321,index)
    }
}
