import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    static let customCautionText = "This section is for personalized routines aimed at improving your overall physical, mental, and spiritual health. It is not intended to enable you to manufacture your own Orthodoxy. We strongly recommend that where appropriate, custom rules be discussed with your priest or spiritual father. If that is not possible, keep these custom rules simple and attainable (e.g., jogging, swimming, sobriety)."

    func beginCustomRule() {
        if settings.customCautionDismissed { openEditor() }
        else { libraryCaution = true; ch_reset_home_scroll() }
    }
    func prepareTemplate(_ index: Int) throws {
        guard templates.indices.contains(index) else { return }
        let template = templates[index]
        let matches = try store.rules(includeArchived: true).filter {
            $0.title.compare(template.title, options: .caseInsensitive) == .orderedSame
        }
        guard try !matches.contains(where: { try ruleIsActive($0) }) else { return }
        if let resting = matches.first(where: { (try? practice.isPaused($0)) == true }) {
            try takeUp(resting); page = .home; ch_reset_home_scroll(); return
        }
        var draft = RuleDraft(nil, on: selectedDate, father: settings.spiritualFatherName)
        draft.presetHeading = template.title.capitalized
        draft.rule = template.makeRule(source: "the library")
        draft.form = RecurrenceForm(draft.rule.recurrence)
        draft.hasTime = draft.rule.timeOfDay != nil
        draft.hour = draft.rule.timeOfDay?.hour ?? 6
        draft.minute = draft.rule.timeOfDay?.minute ?? 30
        draft.reminders = draft.rule.effectiveReminders.enabled
        draft.leads = Set(draft.rule.effectiveReminders.leads)
        editor = draft; notice = ""; ch_reset_home_scroll()
    }
    func renderLibrary() throws {
        title(libraryCaution ? "Writing Your Own Rule" : "Library", subtitle: libraryCaution ? "Keep it simple and attainable." : "Select a prayer, reading, or discipline to add to your routine.")
        let width = min(780,contentWidth)-44
        if libraryCaution {
            var document=ReaderDocument()
            document.line(Self.customCautionText, size:17)
            reader(document,x:contentLeft+14,y:140,width:width,height:max(130,ch_height()-300))
            checkbox(16600,"Don't Show Again",checked:false,x:contentLeft+14,y:ch_height()-145,width:width)
            control(16601,22,"I Understand",contentLeft+14,ch_height()-94,150,36)
            control(16602,18,"Cancel",contentLeft+184,ch_height()-94,100,36)
            return
        }
        let own = try customEntries
        let rules = try store.rules(includeArchived:true)
        let groups = RuleLibrary.shared.scoped(to:settings.jurisdiction.tradition).byCategory()
        func rows(draw: Bool) throws -> Int32 {
            var y:Int32=0, labelID:Int32=17000
            func label(_ text:String, flags:Int32=64, inset:Int32=0, available:Int32?=nil) {
                let w=available ?? width-inset
                let h=max(18,text.withCString { ch_measure_text($0,w,flags) })
                if draw { control(labelID,0,text,14+inset,y,w,h); ch_style(labelID,flags) }
                labelID += 1; y += h+3
            }
            for (category, items) in groups {
                y += 12; label(category.displayName,flags:128)
                for template in items {
                    guard let index=templates.firstIndex(where:{$0.id==template.id}) else { continue }
                    let taken = try rules.contains { rule in
                        guard rule.title.compare(template.title,options:.caseInsensitive) == .orderedSame else { return false }
                        return try ruleIsActive(rule)
                    }
                    let top=y, titleID=labelID; label(template.title,flags:2048 | (taken ? 64 : 0),inset:4,available:width-150)
                    if draw {
                        if taken { control(Int32(18000+index),0,"On your rule",width-116,top,125,24); ch_style(Int32(18000+index),128|512) }
                        else { control(Int32(11000+index),1,"Take on",width-78,top,64,24) }
                    }
                    label(template.summary,inset:4,available:width-150)
                    if let trigger=template.requiredTrigger, !settings.observances.setting(for:trigger).drivesRules, !taken {
                        label("Taking this on will start observing \(ObservanceSettings.name(for:trigger)).",flags:128,inset:4,available:width-150)
                    }
                    if let note=template.note { label(note,flags:64|16384,inset:4,available:width-150) }
                    if !template.glossarySlugs.isEmpty {
                        var x:Int32=18
                        for (term,slug) in template.glossarySlugs.prefix(3).enumerated() {
                            let text=glossary.entry(slug:slug)?.term ?? slug.replacingOccurrences(of:"-",with:" ")
                            let w=min(width/3-8,Int32(text.count)*6+8)
                            if draw { control(Int32(19000+index*3+term),18,text,x,y,w,18); ch_font_size(Int32(19000+index*3+term),12,0,0); ch_show(Int32(19000+index*3+term),0) }
                            x += w+6
                        }
                        if draw { ch_library_hover(titleID,Int32(19000+index*3),Int32(min(3,template.glossarySlugs.count)),max(38,y-top+20)) }
                        y += 8
                    }
                    y=max(y,top+36)+12
                }
            }
            if !own.isEmpty {
                y += 12; label("Custom",flags:128)
                label("Custom routines are usually taken on the advice of your priest or spiritual father.")
                for (index,rule) in own.enumerated() {
                    let active=try ruleIsActive(rule), top=y
                    if draw {
                        control(Int32(14000+index),18,rule.title,18,top,width-165,28)
                        ch_style(Int32(14000+index),active ? 64 : 0)
                        if active { control(Int32(18000+templates.count+index),0,"On your rule",width-126,top,102,24); ch_style(Int32(18000+templates.count+index),128|512) }
                        else { control(Int32(12000+index),1,"Take on",width-78,top,64,24) }
                        control(Int32(13000+index),18,"×",width-22,top,30,28)
                    }
                    y += max(28,rule.title.withCString { ch_measure_text($0,width-165,0) })+2
                    label(rule.timeOfDay.map { Format.time($0,settings.clockStyle) } ?? "All day",inset:4)
                    if let note=rule.note,!note.isEmpty { label(note,inset:4) }
                    if let attribution=rule.suggestedByLabel(currentFather:settings.spiritualFatherName) { label(attribution,flags:128|512,inset:4) }
                    if draw { control(Int32(15000+index),18,active ? "Pause" : "Resume",18,y,80,24) }
                    y += 38
                }
            }
            y += 12
            if draw { control(414,18,"+  Write your own rule",14,y,width,34) }
            return y+58
        }
        let height=try rows(draw:false)
        ch_home_begin(contentLeft,128,contentWidth,max(120,ch_height()-168),height)
        _ = try rows(draw:true)
        ch_home_end()
    }
    func handleLibrary(_ id:Int32,event:Int32) throws -> Bool {
        guard event==0 else { return false }
        if id==16601 {
            if ch_checked(16600)==1 { try saveSettings { $0.customCautionDismissed=true } }
            libraryCaution=false; openEditor()
        } else if id==16602 { libraryCaution=false }
        else if (11000..<12000).contains(id) { try prepareTemplate(Int(id-11000)) }
        else if (12000..<16000).contains(id) {
            let index=Int(id%1000), own=try customEntries
            guard own.indices.contains(index) else { return true }
            let rule=own[index]
            switch id/1000 {
            case 12: try takeUp(rule)
            case 13: try store.save(CustomLibrary.settingAside(rule)); notice="\(rule.title) is no longer offered in the library. Its record is unchanged."
            case 14: openEditor(rule)
            case 15: try togglePause(rule)
            default: break
            }
        } else if (19000..<20000).contains(id) {
            let index=Int(id-19000)/3, term=Int(id-19000)%3
            guard templates.indices.contains(index),templates[index].glossarySlugs.indices.contains(term) else { return true }
            let linkID=nextReaderLink; nextReaderLink += 1
            readerLinks[linkID] = .term(templates[index].glossarySlugs[term])
            try followReaderLink(linkID); return true
        } else { return false }
        try render(); return true
    }
}
