import Foundation
import ChotkiCore
import WindowsUI

extension WindowsApp {
    func startNotifications() throws {
        let status=ch_notifications_start(notificationSmoke ? 2 : review ? 1 : 0)
        notificationStatus=status
        notificationsStarted=status==0
        if status != 0 {
            print("Windows notification registration failed: \(String(format:"0x%08X",UInt32(bitPattern:status)))")
            notice="Windows could not start notifications. Your rules are still here."
        } else { try refreshReminders() }
    }
    func refreshReminders(now:Date=Date()) throws {
        guard notificationsStarted, !onboarding, !review || reminderVerification else { return }
        let date=CalendarDate(now,in:.current)
        let all=try store.rules(includeArchived:false)
        let rules=reminderRuleIDs.map { ids in all.filter { ids.contains($0.id) } } ?? all
        let scheduler=Scheduler(engine:RecurrenceEngine(liturgical:liturgical,observances:settings.observances),policy:settings.reminders,timeZone:.current,includesDueAlert:true)
        let plan=scheduler.plan(rules:rules,activations:try store.activations(ruleID:nil),occurrences:try store.occurrences(ruleID:nil,from:nil,through:nil),on:date)
        let decision=reminderTicker.tick(planned:plan,now:now)
        for id in decision.withdraw {
            let status=id.withCString { ch_notification_cancel($0) }
            if status != 0 { print("Windows notification withdrawal failed: \(status)") }
            deliveredNotifications.removeValue(forKey:id)
        }
        for notification in decision.show {
            let request=notification.request
            let status=request.id.withCString { id in request.title.withCString { title in request.body.withCString { body in ch_notification_show(id,title,body) } } }
            guard status==0 else { print("Windows notification delivery failed: \(status)"); continue }
            deliveredNotifications[notification.id]=notification
            if let rule=rules.first(where:{$0.id==notification.ruleID}),let destination=DueAttention.destination(for:notification,rule:rule) {
                attentionUntil[destination]=now.addingTimeInterval(DueAttention.duration)
                if !reminderVerification { applyAttention(now:now) }
            }
        }
    }
    func applyAttention(now:Date=Date()) {
        let destinations:[(DueDestination,Int32)]=[(.home,100),(.prayers,102),(.reading,103)]
        for (destination,id) in destinations {
            let remaining=max(0,(attentionUntil[destination] ?? .distantPast).timeIntervalSince(now))
            ch_attention(id,Int32(remaining*1000))
        }
    }
    func handleNotificationTicket(_ ticket:Int32) throws {
        var identifier=[CChar](repeating:0,count:4096),action=[CChar](repeating:0,count:64)
        guard ch_notification_take(ticket,&identifier,Int32(identifier.count),&action,Int32(action.count))==1 else { return }
        let id=String(decoding:identifier.prefix{$0 != 0}.map{UInt8(bitPattern:$0)},as:UTF8.self)
        let verb=String(decoding:action.prefix{$0 != 0}.map{UInt8(bitPattern:$0)},as:UTF8.self)
        guard let notification=deliveredNotifications[id],let rule=try store.rule(id:notification.ruleID),!rule.isArchived else { return }
        switch verb {
        case NotificationAction.markComplete.id:
            try store.save(Occurrence(ruleID:rule.id,date:notification.date,status:.completed,completedAt:Date()))
            try refreshReminders(now:reminderTestNow ?? Date())
            if editor==nil && !glossaryDetouring { try render() }
        case NotificationAction.snooze.id:
            reminderTicker.snooze(ruleID:rule.id,date:notification.date,until:(reminderTestNow ?? Date()).addingTimeInterval(3600))
            _=id.withCString { ch_notification_cancel($0) }
        case "open":
            editor=nil; libraryCaution=false; glossaryDetouring=false; selectedDate=notification.date
            if let entry=try practice.entries(on:notification.date).first(where:{$0.rule.id==rule.id}) { try openHomeEntry(entry) }
            else { page = .home }
            try render(); ch_foreground()
        default: return
        }
    }
    func verifyNotificationControls() throws {
        try require(notificationsStarted && notificationStatus==0,"Windows notification initialization returned \(notificationStatus)")
        let saved=settings
        let now=lastKnownToday.dueInstant(at:TimeOfDay(hour:10,minute:30)!,in:.current)!
        let rule=Rule(title:"Notification fixture · Вера & <prayer>",recurrence:.daily,timeOfDay:TimeOfDay(hour:10,minute:30),reminders:RuleReminders(enabled:true,leads:[.tenMinutes]),prayerIDs:["jesus-prayer"])
        try store.save(rule); try store.save(Activation(ruleID:rule.id,from:lastKnownToday))
        reminderVerification=true; reminderRuleIDs=[rule.id]; reminderTestNow=now
        defer { reminderVerification=false; reminderRuleIDs=nil; reminderTestNow=nil; reminderTicker=ReminderTicker(); attentionUntil.removeAll() }
        try saveSettings { $0.reminders.notificationsEnabled=true }
        reminderTicker=ReminderTicker()
        try refreshReminders(now:now.addingTimeInterval(-600))
        guard let early=deliveredNotifications.values.first(where:{$0.ruleID==rule.id}) else { throw BootstrapError.verification("Native notification delivery failed") }
        try require(early.id.withCString { ch_test_notification($0,nil) }==1,"Native Unicode/XML notification delivery")
        try require(attentionUntil.isEmpty,"Early warning must not pulse a section")
        let initial=ch_notification_history_count()
        try refreshReminders(now:now.addingTimeInterval(-600))
        try require(ch_notification_history_count()==initial,"Repeated timer tick must not repeat a banner")
        try refreshReminders(now:now)
        try require(attentionUntil[.prayers]==now.addingTimeInterval(DueAttention.duration),"Due notification targets prayer attention")
        applyAttention(now:now)
        try require(ch_test_attention(102)==1 && ch_test_attention(103)==0,"Native due pulse destination")
        applyAttention(now:now.addingTimeInterval(6)); try require(ch_test_attention(102)==0,"Pulse ends after its shared duration")
        try require(early.id.withCString { id in "snooze".withCString { ch_test_notification(id,$0) } }==0,"Native COM snooze activation")
        try require(try store.occurrences(ruleID:rule.id,from:lastKnownToday,through:lastKnownToday).isEmpty,"Snooze must not mark an occurrence")
        try require(early.id.withCString { id in "complete".withCString { ch_test_notification(id,$0) } }==0,"Native COM complete activation")
        try require(try store.occurrences(ruleID:rule.id,from:lastKnownToday,through:lastKnownToday).first?.status == .completed,"Notification complete route")
        try require(ch_notification_history_count()==0,"Completion withdraws the occurrence's notifications")
        try store.removeOccurrence(ruleID:rule.id,date:lastKnownToday); reminderTicker=ReminderTicker(); deliveredNotifications.removeAll()
        try refreshReminders(now:now)
        try saveSettings { $0.reminders.notificationsEnabled=false }; try refreshReminders(now:now)
        try require(ch_notification_history_count()==0,"Silencing withdraws native notifications")
        try require(try store.occurrences(ruleID:rule.id,from:lastKnownToday,through:lastKnownToday).isEmpty,"Silencing must not change practice")
        try saveSettings { $0=saved }; try render()
        print("Windows notifications passed: escaped Unicode delivery, no repeated banners, early-warning versus due attention, COM complete/snooze actions, cancellation and master silence without practice changes.")
    }
}


extension WindowsApp {
    func beginNativeNotificationSmoke() throws {
        try require(notificationsStarted,"Native Windows notification registration returned \(String(format:"0x%08X",UInt32(bitPattern:notificationStatus)))")
        let rule=Rule(title:"Chotki notification verification",recurrence:.daily)
        try store.save(rule); try store.save(Activation(ruleID:rule.id,from:lastKnownToday))
        let id=PlannedNotification.occurrenceKey(ruleID:rule.id,date:lastKnownToday)+":native"
        let request=NotificationRequest(id:id,title:rule.title,body:"Synthetic x86_64 delivery test. No personal record is used.",actions:[.markComplete,.snooze])
        let notification=PlannedNotification(id:id,ruleID:rule.id,date:lastKnownToday,fireAt:Date(),request:request)
        nativeSmokeNotification=notification; deliveredNotifications[id]=notification
        let status=id.withCString { id in request.title.withCString { title in request.body.withCString { ch_notification_show(id,title,$0) } } }
        try require(status==0,"Native Windows notification Show returned \(String(format:"0x%08X",UInt32(bitPattern:status)))")
        print("Native notification registered and submitted under a temporary review identity.")
    }
    func checkNativeNotificationSmoke() throws {
        guard notificationSmoke,let notification=nativeSmokeNotification else { return }
        nativeNotificationAttempts += 1
        let count=ch_notification_history_count()
        guard count>0 else {
            try require(nativeNotificationAttempts<15,"Native notification history did not receive the toast; status \(count)")
            return
        }
        try require(notification.id.withCString { id in "snooze".withCString { ch_test_notification(id,$0) } }==0,"Native COM snooze action")
        try require(try store.occurrences(ruleID:notification.ruleID,from:lastKnownToday,through:lastKnownToday).isEmpty,"Native snooze changed practice")
        let status=notification.id.withCString { id in notification.request.title.withCString { title in notification.request.body.withCString { ch_notification_show(id,title,$0) } } }
        try require(status==0,"Native notification resubmission")
        try require(notification.id.withCString { id in "complete".withCString { ch_test_notification(id,$0) } }==0,"Native COM completion action")
        try require(try store.occurrences(ruleID:notification.ruleID,from:lastKnownToday,through:lastKnownToday).first?.status == .completed,"Native completion persisted")
        print("Native Windows notification smoke passed: Windows history receipt, x86_64 WinRT/COM activation, snooze and completed occurrence. Temporary identity is cleaned at shutdown.")
        nativeSmokeNotification=nil; ch_close(0)
    }
}
