import Testing
import Foundation
@testable import ChotkiCore

/// Every editable part of a rule, and every setting, reachable on both platforms.
///
/// A port is finished when the feature surfaces match, not when the app runs.
/// Running the Android app could never have revealed that it had no reminder
/// controls and no clock setting: a control that was never written has nothing
/// to click and nothing to fail. Only holding it against macOS finds that, and
/// this is that comparison, made mechanical.
///
/// It reads source text, which is crude. It is also exactly what would have
/// caught both omissions — `reminders` appeared once in the Android editor and
/// that one hit was a line of copy describing controls that were not there.
@Suite("The two interfaces expose the same things")
struct PortParityTests {

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    /// The macOS file, the Android file, and what both must mention.
    ///
    /// Each entry is a thing a person can change. Add to this whenever the
    /// model gains one — the list is the checklist, and it is the checklist
    /// because nobody keeps one in their head across two languages.
    /// Named by the type the control has to reach for, not by the field.
    ///
    /// Searching for the field name is what let this through the first time:
    /// `reminders` appeared once in the Android editor and that one appearance
    /// was a line of copy about reminders, above no controls. A control that
    /// offers a choice of leads has to mention `ReminderLead`; prose cannot.
    private let editableRuleFields = [
        (what: "the title", token: "title"),
        (what: "a note", token: "note"),
        (what: "where it came from", token: "source"),
        (what: "how often", token: "Recurrence"),
        (what: "a time of day", token: "TimeOfDay"),
        (what: "reminders", token: "ReminderLead"),
    ]

    private let editableSettings = [
        (what: "the jurisdiction", token: "jurisdiction"),
        (what: "the clock", token: "ClockStyle"),
        (what: "observances", token: "observances"),
    ]

    @Test("a rule can be edited the same way on both platforms")
    func ruleEditorsMatch() throws {
        let mac = try source("macos/Sources/Chotki/RuleEditorView.swift")
        let android = try source("android/app/src/main/kotlin/org/chotki/app/ui/RuleEditor.kt")

        for field in editableRuleFields {
            #expect(mac.contains(field.token), "macOS cannot edit \(field.what)")
            #expect(
                android.contains(field.token),
                "Android cannot edit \(field.what) — it is in the model and on the Mac"
            )
        }
    }

    @Test("the same settings can be changed on both platforms")
    func settingsMatch() throws {
        let mac = try source("macos/Sources/Chotki/SettingsView.swift")
        let android = try source("android/app/src/main/kotlin/org/chotki/app/ui/SettingsScreen.kt")

        for setting in editableSettings {
            #expect(mac.contains(setting.token), "macOS cannot change \(setting.what)")
            #expect(
                android.contains(setting.token),
                "Android cannot change \(setting.what) — it is in the model and on the Mac"
            )
        }
    }

    /// The signal that gave both omissions away, had anyone looked.
    ///
    /// The Android editor carried the sentence explaining reminders while
    /// having no reminder controls. Copy describing a control that is not there
    /// means a screen was ported halfway.
    @Test("nothing explains a control that is not there")
    func noOrphanedExplanation() throws {
        let android = try source("android/app/src/main/kotlin/org/chotki/app/ui/RuleEditor.kt")

        if android.contains("reminders are spread across the waking hours") {
            #expect(
                android.contains("ReminderLead"),
                "the editor explains reminders but offers no way to set them"
            )
        }
    }
}
