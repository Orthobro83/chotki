import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    static func prepareTrayMark() {
        let rawKnots=RopeMarkGeometry.knotCentres.flatMap { [$0.x,$0.y,RopeMarkGeometry.knotRadius] }
        let rawBox=RopeMarkGeometry.crossBox
        let rawBars=CrossGeometry.bars.flatMap { [rawBox.x+$0.x*rawBox.width,rawBox.y+$0.y*rawBox.height,$0.width*rawBox.width,$0.height*rawBox.height] }
        let rawFoot=CrossGeometry.footrest
        let polygon=[(rawFoot.leadingX,rawFoot.leadingY),(rawFoot.trailingX,rawFoot.trailingY),(rawFoot.trailingX,rawFoot.trailingY+rawFoot.thickness),(rawFoot.leadingX,rawFoot.leadingY+rawFoot.thickness)]
            .flatMap { [rawBox.x+$0.0*rawBox.width,rawBox.y+$0.1*rawBox.height] }
        rawKnots.withUnsafeBufferPointer { k in rawBars.withUnsafeBufferPointer { b in polygon.withUnsafeBufferPointer { f in
            ch_opening_geometry(k.baseAddress,Int32(rawKnots.count/3),b.baseAddress,Int32(rawBars.count/4),f.baseAddress)
        } } }
        let box = RopeMarkGeometry.crossBox
        let top = RopeMarkGeometry.centreY - RopeMarkGeometry.loopRadius - RopeMarkGeometry.knotRadius
        let left = RopeMarkGeometry.centreX - RopeMarkGeometry.loopRadius - RopeMarkGeometry.knotRadius
        let height = box.y + box.height - top
        let width = 2 * (RopeMarkGeometry.loopRadius + RopeMarkGeometry.knotRadius)
        let offset = (1 - width / height) / 2
        func x(_ value: Double) -> Double { offset + (value - left) / height }
        func y(_ value: Double) -> Double { (value - top) / height }
        let knots = RopeMarkGeometry.knotCentres.flatMap { [x($0.x), y($0.y), RopeMarkGeometry.knotRadius / height] }
        let bars = CrossGeometry.bars.flatMap {
            [x(box.x + $0.x * box.width), y(box.y + $0.y * box.height), $0.width * box.width / height, $0.height * box.height / height]
        }
        let f = CrossGeometry.footrest
        let foot = [(f.leadingX, f.leadingY), (f.trailingX, f.trailingY),
                    (f.trailingX, f.trailingY + f.thickness), (f.leadingX, f.leadingY + f.thickness)]
            .flatMap { [x(box.x + $0.0 * box.width), y(box.y + $0.1 * box.height)] }
        knots.withUnsafeBufferPointer { k in
            bars.withUnsafeBufferPointer { b in
                foot.withUnsafeBufferPointer { f in
                    ch_tray_geometry(k.baseAddress, Int32(knots.count / 3), b.baseAddress, Int32(bars.count / 4), f.baseAddress)
                }
            }
        }
    }

    func handleTray(_ id: Int32) throws {
        switch id {
        case Int32(CH_TRAY_OPEN), Int32(CH_TRAY_SETTINGS):
            editor = nil; selectedRow = 0; notice = ""; readingTarget = nil; showPsalter = false; rulePrayerID=nil
            page = id == Int32(CH_TRAY_OPEN) ? .home : .settings
            libraryCaution=false; ch_reset_home_scroll()
            try render()
            ch_foreground()
        case Int32(CH_TRAY_TOGGLE):
            // Refresh the setting without losing drafts in the visible form.
            let names = page == .settings && editor == nil ? (text(311), text(313)) : nil
            if editor != nil { captureEditor() }
            try saveSettings { $0.reminders.notificationsEnabled.toggle() }
            notice = settings.reminders.notificationsEnabled ? "Notifications enabled." : "Notifications silenced."
            try render()
            if let names { enter(311, names.0); enter(313, names.1) }
        case Int32(CH_TRAY_QUIT):
            calendarTask?.cancel()
            ch_close(0)
        default: break
        }
    }

    func verifyTrayControls() throws {
        try require(ch_tray_present() == 1 && ch_test_tray(0) == 1, "Four-item native tray menu registration")
        let original = settings.reminders.notificationsEnabled
        try press(105)
        enter(311, "Unsaved tray fixture")
        try require(ch_test_tray(Int32(CH_TRAY_TOGGLE)) == 1, "Tray toggle command")
        try require(settings.reminders.notificationsEnabled != original && (try store.loadSettings())?.reminders.notificationsEnabled == !original,
                    "Tray notification choice was not persisted")
        try require(text(311) == "Unsaved tray fixture", "Tray toggle lost typed settings")
        try require(ch_checked(605) == (original ? 0 : 1) && ch_test_tray(0) == 1, "Notification checkbox and tray label disagree")
        enter(311, settings.displayName)
        try press(605)
        try require(settings.reminders.notificationsEnabled == original && ch_test_tray(0) == 1, "Settings toggle did not update the tray label")
        let closedVisibility=ch_test_window(1), trayAfterClose=ch_tray_present()
        try require(closedVisibility == 0 && trayAfterClose == 1, "Closing must keep the tray available (visible=\(closedVisibility), tray=\(trayAfterClose))")
        try require(ch_test_tray(Int32(CH_TRAY_OPEN)) == 1 && page == .home && ch_test_window(0) == 1,
                    "Open Chotki must reveal Home")
        _ = ch_test_window(2)
        try require(ch_test_tray(Int32(CH_TRAY_SETTINGS)) == 1 && page == .settings && ch_test_window(0) == 1,
                    "Settings must restore the minimized app")
        _ = ch_test_window(3)
        try require(ch_tray_present() == 1 && ch_test_tray(0) == 1, "Tray must recover after Explorer recreates the taskbar")
        try require(ch_test_tray(Int32(CH_TRAY_TOGGLE)) == 1 && ch_test_tray(Int32(CH_TRAY_TOGGLE)) == 1,
                    "Repeated tray toggles")
        try require(settings.reminders.notificationsEnabled == original, "Repeated toggles must restore the preference")
        print("Tray UI passed: four menu items, persisted notification toggle and Settings synchronization, draft preservation, close-to-tray, Home foreground, minimized Settings restore and taskbar recovery.")
    }
}
