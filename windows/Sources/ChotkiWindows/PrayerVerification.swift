import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func verifyPrayerControls() throws {
        try press(102)
        try require(ch_test_prayer_menu(321)==1,"Prayer menu lacks its disabled Rules/On the rope/Read groups")
        try choosePrayer("jesus-prayer")
        rope.startAgain(); try render()
        let identity=ch_test_reader_identity(301)
        let count=rope.count
        try require(ch_test_space(301,0)==1 && rope.count==count+1,"Space in the prayer reader did not count")
        for _ in 0..<12 { try require(ch_test_space(301,1)==1,"Held Space was not consumed") }
        try require(rope.count==count+1,"Keyboard repeat counted additional knots")
        try press(420)
        try require(rope.count==count+1,"Fast consecutive inputs bypassed the one-second guard")
        try require(ch_test_reader_identity(301)==identity,"Counting replaced the native prayer reader")
        for modifier:Int32 in [0x10,0x11,0x12,0x5B] {
            try require(ch_test_space_modifier(301,modifier)==0 && rope.count==count+1,"Modified Space counted a knot")
        }
        // Repeat must remain suppressed even when the interval guard permits a
        // new knot. A held key is not a new press.
        rope=PrayerScreen(selection:"jesus-prayer",minimumInterval:1)
        _=rope.advance(at:Date().addingTimeInterval(-3)); try render()
        try require(ch_test_space(301,1)==1 && rope.count==1,"Held Space bypassed the repeat guard after the interval expired")
        try require(ch_test_space(321,0)==0 && ch_test_space(425,0)==0,"Space on a chooser or footer button counted a knot")
        try press(421)
        try require(rope.count==0 && text(426).contains("0 of 33 knots"),"Start again did not reset the displayed count")
        for (index,target) in PrayerScreen.targets.enumerated() {
            try press(Int32(422+index))
            try require(rope.count==0 && rope.target==target && text(426).contains("of \(target) knots"),"Rope target UI")
        }
        try press(422)
        // Complete an actual active Jesus Prayer rule through the native button.
        let template=RuleLibrary.shared.templates.first { $0.title=="The Jesus Prayer" }!
        let rule=template.makeRule(source:"synthetic rope review")
        try store.save(rule); try store.save(Activation(ruleID:rule.id,from:selectedDate))
        rope=PrayerScreen(selection:"jesus-prayer",count:32,target:33,minimumInterval:1)
        try render(); try press(420)
        try require(rope.isComplete && text(426).contains("the knot is complete"),"Rope completion caption")
        try require(try store.occurrences(ruleID:rule.id,from:selectedDate,through:selectedDate).first?.status == .completed,"Completing the Jesus Prayer rope did not keep its rule")
        try require(ch_test_space(0,0)==1 && rope.count==33,"Complete rope exceeded its target")
        try captureReview("rope-complete")
        try store.save(Occurrence(ruleID:rule.id,date:selectedDate,status:.skipped))
        rope=PrayerScreen(selection:"jesus-prayer",count:32,target:33,minimumInterval:1)
        try render(); try press(420)
        try require(try store.occurrences(ruleID:rule.id,from:selectedDate,through:selectedDate).first?.status == .skipped,"Rope completion overwrote a stood-down rule")
        rope=PrayerScreen(selection:"jesus-prayer",count:21,target:33,minimumInterval:1)
        try render(); try captureReview("rope")
        // Hiding the rope retains the count, and disables the Space shortcut.
        try press(425)
        try require(!rope.showsRope() && rope.count==21 && ch_test_space(301,0)==0,"Hidden rope lost state or consumed Space")
        try press(425)
        try require(rope.showsRope() && rope.count==21,"Showing the rope lost its count")
        let linkedPrayer=PrayerBook.shared.scoped(to:settings.jurisdiction.tradition).forRope().first {
            singlePrayerDocument($0).runs.contains { if case .term = $0.link { return true }; return false }
        }!
        try choosePrayer(linkedPrayer.id)
        ch_test_scroll_end(301,0); ch_pump()
        let position=ch_first_visible_line(301)
        try require(ch_test_link(301,0)==1,"Counted prayer glossary link"); ch_pump()
        try require(glossaryDetouring && ch_test_space(0,0)==0 && rope.count==21,"Glossary counted through the underlying rope")
        try press(6063)
        try require(rope.count==21 && ch_first_visible_line(301)==position,"Glossary return lost the counted prayer state")
        try choosePrayer("morning")
        try require(!rope.showsRope() && rope.ropeOverride==nil && ch_test_space(301,0)==0,"Read-through rule inherited the rope override")
        ch_reader_scroll_line(301,0)
        let prayerFirstLine=ch_test_reader_first_line(301)
        try require(ch_test_reader_wheel(301,2)>prayerFirstLine,"Prayer mouse wheel did not move the reader")
        ch_reader_scroll_line(301,0)
        try require(ch_test_reader_wheel_delta(301,-10,4)>0,"Small precision-wheel deltas did not accumulate")
        ch_reader_scroll_line(301,0)
        try captureReview("rope-read")
        try press(425)
        try require(rope.showsRope(),"Cannot show the rope beside a read-through rule")
        // A read-through rule does not become kept merely by counting a rope.
        let morning=RuleLibrary.shared.templates.first { $0.title=="Morning prayers" }!.makeRule(source:"synthetic rope review")
        try store.save(morning); try store.save(Activation(ruleID:morning.id,from:selectedDate))
        rope=PrayerScreen(selection:"morning",count:32,target:33,minimumInterval:1); rope.showRope(true)
        try render(); try press(420)
        try require(try store.occurrences(ruleID:morning.id,from:selectedDate,through:selectedDate).isEmpty,"Counting completed an unread morning sequence")
        try choosePrayer(nil)
        try require(rope.selection==nil && rope.showsRope() && text(301).isEmpty,"The rope alone retained a prayer reader")
        rope.startAgain(); try render(); try captureReview("rope-alone")
        try choosePrayer("jesus-prayer"); try press(424)
        ch_test_resize(620,540)
        try require(ch_width()==620 && ch_height()==540 && text(426).contains("of 100 knots"),"Compact 100-knot layout")
        try captureReview("rope-narrow")
        ch_test_resize(1100,860)
        try press(779)
        try require(ch_test_space(301,0)==0,"Psalter accepted the rope shortcut")
        try press(779)
        try press(105)
        try require(ch_test_space(0,0)==0,"Settings accepted the rope shortcut")
        for var item in [rule,morning] { item.archivedAt=Date(); try store.save(item) }
        rope=PrayerScreen(minimumInterval:1)
        let tableTemplate=RuleLibrary.shared.templates.first { $0.prayerIDs==["our-father","table-blessing"] }!
        var table=tableTemplate.makeRule(source:"the library")
        try store.save(table); try store.save(Activation(ruleID:table.id,from:selectedDate))
        page = .home; try render()
        let tableIndex=try practice.entries(on:selectedDate).firstIndex { $0.rule.id==table.id }!
        try press(Int32(1000+tableIndex))
        try require(rulePrayerID==table.id && table.prayers.allSatisfy { text(301).contains($0.title) && text(301).contains($0.paragraphs.last ?? "") },"A multi-prayer rule shows every attached prayer")
        try require(text(301).contains("Where to read more") && PrayerSources.further.allSatisfy { text(301).contains($0.organisation) },"Received prayer sources and further references")
        try require(ch_test_space(301,0)==0,"Rule prayer view accepted rope counting")
        ch_test_scroll_end(301,1); ch_pump()
        try require(try store.occurrences(ruleID:table.id,from:selectedDate,through:selectedDate).isEmpty,"Consulting received prayers marked a rule kept")
        try captureReview("rule-prayers")
        let prayerLink=readerLinks.first { if case .term = $0.value { return true }; return false }?.key
        if let prayerLink { try followReaderLink(prayerLink); try press(6063); try require(rulePrayerID==table.id,"Prayer glossary return lost the rule destination") }
        try press(23991); try require(rulePrayerID==nil && text(321).contains("Jesus"),"Received prayers return to the rope")
        table.archivedAt=Date(); try store.save(table)
        print("Prayer rope UI passed: grouped choices, rope alone, count/dots/targets, completion, Space/repeat/interval guards, hidden/menu/glossary/Psalter/Settings isolation, read-through and stood-down preservation, compact 100-knot layout, complete multi-prayer rule destinations, source references, glossary return and consultation without implicit completion.")
    }
}
