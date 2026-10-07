import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func renderOnboarding() {
        let width=min(560,ch_width()-44), left=(ch_width()-width)/2
        var document=ReaderDocument()
        for paragraph in Welcome.paragraphs {
            for span in paragraph.spans { document.runs.append(ReaderRun(text:span.text,flags:paragraph.isAside ? 4 : 0,size:17,link:span.url.map { .source($0) })) }
            document.line("",size:17)
        }
        let paragraphsHeight=Welcome.paragraphs.reduce(Int32(12)) { total,paragraph in
            total+paragraph.spans.map(\.text).joined().withCString { ch_measure_reading($0,width,17) }+12
        }
        var formY=80+paragraphsHeight
        ch_home_begin(0,0,ch_width(),ch_height()-35,formY+316)
        control(23000,25,Welcome.title,left,28,width,40); ch_font_size(23000,26,1,0)
        reader(document,x:left,y:80,width:width,height:paragraphsHeight)
        formY=80+ch_rich_fit(301)
        ch_home_content(formY+316)
        control(23004,25,"What should we call you?",left,formY+20,width,38); ch_font_size(23004,26,1,0)
        control(23001,3,welcomeName,left,formY+68,width,36); ch_font_size(23001,17,1,0)
        control(23005,25,Welcome.churchPrompt,left,formY+128,width,32); ch_font_size(23005,22,1,0)
        choice(23002,[Welcome.noChurchAffiliation]+Jurisdiction.known.map(\.name),selected:welcomeChurch,x:left,y:formY+176,width:width)
        control(23003,22,Welcome.beginLabel,left,formY+236,width,40)
        ch_home_end()
    }
    func handleOnboarding(_ id:Int32,event:Int32) -> Bool {
        if id==23001 && event==768 { welcomeName=text(id); return true }
        if id==23002 && event==1 { welcomeChurch=max(0,Int(ch_selected(id))); return true }
        guard id==23003 && event==0 else { return false }
        do {
            let name=text(23001).trimmingCharacters(in:.whitespacesAndNewlines)
            let index=Int(ch_selected(23002))
            let church=index>0 && index<=Jurisdiction.known.count ? Jurisdiction.known[index-1].name : nil
            try saveSettings { $0.displayName=name; $0.chooseChurch(named:church); $0.hasCompletedFirstRun=true }
            onboarding=false; notice=""; page = .home; ch_reset_home_scroll(); try render()
        } catch { actionError=error.localizedDescription; notice=error.localizedDescription; notice.withCString { ch_update(202,$0) } }
        return true
    }
    func renderFatherPrompt() {
        let width=min(490,ch_width()-56),left=(ch_width()-width)/2
        let message="Chotki is best used in cooperation with a priest or spiritual father. Have you found one yet?"
        let height=message.withCString { ch_measure_reading($0,width,22) }
        let y=max(28,(ch_height()-height-170)/2)
        var document=ReaderDocument(); document.line(message,size:22)
        reader(document,x:left,y:y,width:width,height:height+20); ch_rich_center(301); _=ch_rich_fit(301)
        if fatherPromptNaming {
            control(24001,3,fatherPromptName,left,y+height+38,width,36); ch_font_size(24001,18,1,0)
            control(24004,22,"Save",left,y+height+92,width,38)
            ch_enable(24004,fatherPromptName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? 0 : 1)
        } else {
            control(24002,22,"Yes I Have",left,y+height+44,(width-12)/2,38)
            control(24003,22,"Not Yet",left+(width+12)/2,y+height+44,(width-12)/2,38)
        }
    }
    func handleFatherPrompt(_ id:Int32,event:Int32) throws -> Bool {
        guard (24001...24004).contains(id) else { return false }
        if id==24001 && event==768 {
            fatherPromptName=text(24001)
            ch_enable(24004,fatherPromptName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? 0 : 1)
        } else if event==0 {
            if id==24002 { fatherPromptNaming=true; ch_clear(); renderFatherPrompt(); ch_focus(24001) }
            if id==24003 { try saveSettings { $0.spiritualFatherDeferredOn=lastKnownToday }; fatherPromptNaming=false; try render() }
            if id==24004 {
                let name=text(24001).trimmingCharacters(in:.whitespacesAndNewlines)
                guard !name.isEmpty else { return true }
                try saveSettings { $0.spiritualFatherName=name }; fatherPromptNaming=false; fatherPromptName=""; try render()
            }
        }
        return true
    }
    func verifyOnboardingAndSound() throws {
        let saved=settings
        try require(ch_test_opening_frame(1800)==1,"Opening curtain uses the shared mark geometry")
        try captureReview("opening-mark")
        try require(ch_test_opening_frame(-1)==1,"Opening curtain cleanup")
        let before=try store.rules(includeArchived:true).count
        onboarding=true; welcomeName=""; welcomeChurch=0; ch_reset_home_scroll(); try render()
        try require(text(23000)==Welcome.title && Welcome.paragraphs.allSatisfy { text(301).contains($0.spans.map(\.text).joined()) },"Canonical welcome text")
        enter(23001,"  Вера  "); try choose(23002,1)
        ch_test_resize(760,640); try render()
        try require(text(23001)=="  Вера  " && ch_selected(23002)==1,"Welcome choices survived resizing")
        ch_test_panel_scroll(1); try captureReview("welcome"); ch_test_panel_scroll(0)
        try press(23003)
        try require(!onboarding && settings.hasCompletedFirstRun && settings.firstRunOn==lastKnownToday && settings.displayName=="Вера" && settings.namedChurch==Jurisdiction.known[0].name,"Welcome persistence")
        try require(try store.rules(includeArchived:true).count==before,"Welcome must not activate suggested rules")
        try saveSettings { $0=saved }; ch_test_resize(1100,860); try render()
        var promptSettings=settings
        promptSettings.hasCompletedFirstRun=true; promptSettings.firstRunOn=lastKnownToday.adding(days:-30)
        promptSettings.spiritualFatherName=""; promptSettings.spiritualFatherDeferredOn=nil
        try saveSettings { $0=promptSettings }
        ch_clear(); renderFatherPrompt(); try captureReview("father-prompt")
        try press(24003)
        try require(!settings.shouldAskForSpiritualFather(on:lastKnownToday) && settings.shouldAskForSpiritualFather(on:lastKnownToday.adding(days:30)),"Father prompt defers for thirty days")
        try saveSettings { $0.spiritualFatherDeferredOn=nil }
        ch_clear(); renderFatherPrompt(); try press(24002); enter(24001,"  Fr. Windows  "); try press(24004)
        try require(settings.spiritualFatherName=="Fr. Windows" && !settings.shouldAskForSpiritualFather(on:lastKnownToday),"Father prompt saves a trimmed name")
        try saveSettings { $0=saved }; try render()
        try require(audioStatus==0,"Windows audio device preparation returned \(audioStatus)")
        try press(102); try choosePrayer("jesus-prayer")
        try saveSettings { $0.tickEachKnot=true; $0.chimeOnCompletion=true }
        let tick=ch_test_sound(0), bell=ch_test_sound(1)
        rope.aim(at:33); rope.startAgain(); try render()
        try press(420)
        try require(ch_test_sound(0)==tick+1 && ch_test_sound(1)==bell,"Accepted knot plays one tick")
        try press(420); try require(ch_test_sound(0)==tick+1,"Rejected rapid press must not tick")
        // The tenth knot, where a bead sits on the rope, tocks instead of ticking.
        let tock=ch_test_sound(2), ticksBefore=ch_test_sound(0)
        rope.advanceToSoundFixture(8)
        try press(420); try require(ch_test_sound(0)==ticksBefore+1 && ch_test_sound(2)==tock,"The ninth knot ticks")
        Thread.sleep(forTimeInterval:1.1)
        try press(420); try require(ch_test_sound(2)==tock+1 && ch_test_sound(0)==ticksBefore+1,"The tenth knot tocks, not ticks")
        try saveSettings { $0.tickEachKnot=false }
        rope.advanceToSoundFixture(32)
        try press(420)
        try require(ch_test_sound(1)==bell+1 && ch_test_sound(0)==tick+2,"Completing a knot plays its bell without an extra tick")
        try saveSettings { $0.chimeOnCompletion=false }
        rope.startAgain(); rope.advanceToSoundFixture(32); try press(420)
        try require(ch_test_sound(1)==bell+1,"Disabled completion chime")
        try saveSettings { $0=saved }; rope.startAgain(); page = .home; try render()
        print("Welcome/sound UI passed: canonical first-run text, Unicode name, church choice, resize preservation, no implicit rules, thirty-day father prompt/defer/name persistence, prepared Windows PCM voices and tick/chime policy with rapid-press rejection.")
    }
}

// Synthetic counts use old timestamps to exercise audio policy without waiting.
extension PrayerScreen {
    mutating func advanceToSoundFixture(_ count:Int) {
        startAgain()
        for index in 0..<count { _=advance(at:Date(timeIntervalSince1970:1_780_000_000+Double(index)*2)) }
    }
}
