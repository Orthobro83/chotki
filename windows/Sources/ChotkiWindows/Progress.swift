import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    static let progressQuote = "Those who have really determined to serve Christ, with the help of spiritual fathers and their own self-knowledge, will strive before all else to choose a place, a way of life, a habitation, and exercises suitable for them."
    static let progressAttribution = "— Saint John Climacus · The Ladder of Divine Ascent"
    static let progressCaption = "Icon of St. Anthony the Great, St. Paul of Thebes, St. Sabbas the Sanctified, and St. John Climacus."

    func progressDocument(_ report:ProgressReport,detached:Bool=false) -> ReaderDocument {
        var document=ReaderDocument()
        if detached {
            document.line("Your progress up to \(Format.longDate(Practice.progressThrough(today:lastKnownToday))) — the ninety days to then",flags:4|16,size:12)
            document.line("")
        }
        for line in report.summary { document.line(line,size:17) }
        if detached {
            if settings.showConsistencyNumber,let value=report.overall {
                document.line("\(Int((value*100).rounded()))%  Kept",flags:8|16,size:34)
                document.line("")
            }
            if report.hasAnythingDue {
                document.line("By Rule",flags:4|16,size:13)
                for score in report.perRule.filter(\.hasAnythingDue) {
                    document.line(score.title,flags:16,size:14)
                    document.line("\(score.streak>1 ? "\(score.streak) in a row · " : "")\(score.kept+score.keptLate) of \(score.scoreable)",flags:4|16,size:13)
                    document.line("",size:5)
                }
            }
        }
        return document
    }
    func renderProgress() throws {
        let report=try practice.report(today:lastKnownToday)
        title("Progress",subtitle:"Your progress up to \(Format.longDate(Practice.progressThrough(today:lastKnownToday)))")
        let width=min(800,contentWidth)-44
        let document=progressDocument(report)
        var summaryHeight=report.summary.reduce(Int32(12)) { h,line in
            h + line.withCString { ch_measure_reading($0,width,17) }+12
        }
        let scores=report.perRule.filter(\.hasAnythingDue)
        let rowsHeight=scores.reduce(Int32(0)) { total,score in
            total + max(32,score.title.withCString { ch_measure_text($0,max(120,width-190),0) }+8)
        }
        let numberHeight:Int32=settings.showConsistencyNumber && report.overall != nil ? 62 : 0
        let detailHeight:Int32=report.hasAnythingDue ? rowsHeight+92 : 0
        var artY=summaryHeight+numberHeight+detailHeight+18
        ch_home_begin(contentLeft,130,contentWidth,max(120,ch_height()-170),artY+332)
        reader(document,x:14,y:0,width:width,height:summaryHeight)
        summaryHeight=ch_rich_fit(301)
        artY=summaryHeight+numberHeight+detailHeight+18
        ch_home_content(artY+332)
        var y=summaryHeight+8
        if settings.showConsistencyNumber,let value=report.overall {
            control(20002,5,"\(Int((value*100).rounded()))%",14,y,110,40); ch_style(20002,128)
            control(20003,0,"Kept, over the 30 days to then",128,y+16,width-120,24); ch_style(20003,64)
            y += 62
        }
        if report.hasAnythingDue {
            control(20004,0,"By Rule",14,y,width,20); ch_style(20004,64); y += 30
            for (index,score) in scores.enumerated() {
                let height=max(32,score.title.withCString { ch_measure_text($0,max(120,width-190),0) }+8)
                control(Int32(20100+index*3),0,score.title,14,y,width-190,height)
                if score.streak>1 { control(Int32(20101+index*3),0,"\(score.streak) in a row",width-166,y,110,24); ch_style(Int32(20101+index*3),128|512) }
                control(Int32(20102+index*3),0,"\(score.kept+score.keptLate) of \(score.scoreable)",width-52,y,70,24); ch_style(Int32(20102+index*3),64|512)
                y += height
            }
            control(20005,18,"Open in a window",14,y+6,190,30)
        }
        let image=WindowsAssets.root.appendingPathComponent("progress.jpg")
        let source="\(Self.progressAttribution)\n\(Self.progressCaption)"
        image.path.withCString { path in Self.progressQuote.withCString { quote in source.withCString { source in
            ch_image(20006,path,quote,source,0.5,0,0,artY,contentWidth,300)
        } } }
        ch_style(20006,1)
        ch_home_end()
    }
    func renderDetachedProgress(show:Bool) throws {
        let width=ch_report_begin()
        guard width>0 else { throw RuleInputError(message:"The Progress window could not be opened.") }
        defer { ch_report_end(show ? 1 : 0) }
        let line=ch_first_visible_line(7014)
        let report=try practice.report(days:90,today:lastKnownToday)
        reader(progressDocument(report,detached:true),id:7014,x:28,y:28,width:width-56,height:ch_report_height()-56)
        ch_reader_scroll_line(7014,line)
    }
    func verifyLibraryAndProgress() throws {
        try press(101)
        try captureReview("library-grouped")
        let before=try store.rules(includeArchived:true).count
        try press(414)
        if libraryCaution {
            try require(text(301).contains(Self.customCautionText),"Custom-rule caution text")
            try press(16602)
            try require(editor==nil && !libraryCaution,"Cancelling custom-rule caution")
            try press(414); ch_check(16600,1); try press(16601)
            let savedCaution=try store.loadSettings()?.customCautionDismissed
            try require(settings.customCautionDismissed && savedCaution==true,"Remember custom-rule caution choice")
            try press(551)
        } else { try press(551) }
        try require(try store.rules(includeArchived:true).count==before,"Caution or cancelled editor wrote a rule")
        if let index=templates.firstIndex(where: { !$0.glossarySlugs.isEmpty }) {
            try press(Int32(19000+index*3))
            try require(glossaryDetouring && text(6063).contains("Library"),"Library glossary detour")
            try press(6063); try require(page == .library && !glossaryDetouring,"Library glossary return")
        }
        try press(104)
        let report=try practice.report(today:lastKnownToday)
        try require(report.summary.allSatisfy { text(301).contains($0) },"Progress prose")
        try require(text(201).contains(Format.longDate(lastKnownToday.adding(days:-1))),"Progress ends yesterday")
        try captureReview("progress")
        ch_test_panel_scroll(1); try captureReview("progress-art"); ch_test_panel_scroll(0)
        if report.hasAnythingDue {
            try press(20005)
            let identity=ch_test_reader_identity(7014)
            let detailed=try practice.report(days:90,today:lastKnownToday)
            try require(ch_report_visible()==1 && detailed.summary.allSatisfy { text(7014).contains($0) },"Detached ninety-day report")
            if let base=ProcessInfo.processInfo.environment["CHOTKI_REVIEW_CAPTURE"] {
                let path=URL(fileURLWithPath:base).deletingPathExtension().path+"-progress-window.bmp"
                try require(path.withCString { ch_capture_report($0) }==1,"Detached Progress capture")
            }
            try require(ch_test_report(0)==1 && ch_report_visible()==0,"Report close must preserve reusable window")
            try press(20005)
            try require(ch_test_reader_identity(7014)==identity,"Report reopens its existing reader")
            _=ch_test_report(0)
        }
        let show=settings.showConsistencyNumber
        try saveSettings { $0.showConsistencyNumber=false }; try render()
        try require(text(20002).isEmpty,"Consistency number must be optional")
        try saveSettings { $0.showConsistencyNumber=show }
        ch_test_resize(760,640); try render(); try captureReview("progress-narrow")
        ch_test_resize(1100,860); try render()
        print("Library and Progress UI passed: grouped templates, glossary round trip, custom caution, yesterday cutoff, optional figure, per-rule details and reusable ninety-day report.")
    }
}
