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
/// **What this can and cannot do, stated plainly, because it has been patched
/// four times.** It reads source text. It can tell you a control was never
/// written — which is the failure that has actually happened, repeatedly, and
/// which no amount of running the app reveals because there is nothing to tap.
/// It cannot tell you a control *works*: gutting a function's body while
/// leaving its name passes this test, and was tried.
///
/// So the division is deliberate. This guards the feature *surface* across
/// three platforms. Whether each one behaves belongs to that platform's own
/// tests — `ChotkiTests` on iOS, the instrumentation suite on Android, and the
/// macOS suite — where the record can actually be read back.
///
/// Every patch it has needed came from the same mistake in a different coat:
/// searching for a word rather than for the thing. `reminders` was found in a
/// line of copy above no controls; `jurisdiction` in a read-only line;
/// `exportJSON` in the one platform of three that spells it that way. It now
/// searches whole trees for the core call behind the door, rather than a named
/// file for a name.
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

    /// Three now, not two. The port that added the third is the one that made
    /// this test matter: iOS inherits core unchanged, so nothing can be lost in
    /// translation — but a screen can still simply not be written.
    private var editors: [(String, String)] {
        [
            ("macOS", "macos/Sources/Chotki/RuleEditorView.swift"),
            ("Android", "android/app/src/main/kotlin/org/chotki/app/ui/RuleEditor.kt"),
            ("iOS", "ios/Chotki/RuleEditor.swift"),
        ]
    }

    private var settingsScreens: [(String, String)] {
        [
            ("macOS", "macos/Sources/Chotki/SettingsView.swift"),
            ("Android", "android/app/src/main/kotlin/org/chotki/app/ui/SettingsScreen.kt"),
            ("iOS", "ios/Chotki/SettingsView.swift"),
        ]
    }

    @Test("a rule can be edited the same way on every platform")
    func ruleEditorsMatch() throws {
        for (platform, path) in editors {
            let file = try source(path)
            for field in editableRuleFields {
                #expect(
                    file.contains(field.token),
                    "\(platform) cannot edit \(field.what) — it is in the model and on the others"
                )
            }
        }
    }

    /// Whole trees, not named files.
    ///
    /// This is the third time a check here has looked in one file and missed
    /// the thing because the platform had put it in another. Naming files is
    /// how `reminders` was searched for in the Android editor and found in a
    /// line of copy; naming a file is also how the export check first reported
    /// every platform as missing it when two had it elsewhere. Ask the tree.
    private func tree(_ path: String) throws -> String {
        let root = Self.root.appendingPathComponent(path)
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { ["swift", "kt"].contains($0.pathExtension) }
            ?? []
        return try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    @Test("the record can be kept on every platform")
    func recordCanLeaveEveryPlatform() throws {
        // Nothing is destroyed and nothing is sent anywhere, so a copy someone
        // makes themselves is the only way a record survives a new phone — and
        // on Android, the only way it survives an uninstall at all.
        //
        // Each platform names its own door differently; what they share is the
        // core call behind it.
        for (platform, path) in [
            ("macOS", "macos/Sources"),
            ("Android", "android/app/src/main"),
            ("iOS", "ios/Chotki"),
        ] {
            let code = try tree(path)
            #expect(
                code.contains("exportBackup") || code.contains("exportJSON")
                    || code.contains("exportJson"),
                "\(platform) offers no way to keep a copy of the record"
            )
            #expect(
                code.contains("importBackup") || code.contains("importJSON")
                    || code.contains("importJson") || code.contains("restoreFrom"),
                "\(platform) offers no way to put a copy back"
            )
        }
    }

    @Test("the old two-platform editor check", .disabled("folded into ruleEditorsMatch"))
    func oldEditorCheck() throws {
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

    @Test("the same settings can be changed on every platform")
    func settingsMatch() throws {
        for (platform, path) in settingsScreens {
            let file = try source(path)
            for setting in editableSettings {
                #expect(
                    file.contains(setting.token),
                    "\(platform) cannot change \(setting.what) — it is in the model and on the others"
                )
            }
        }

        let android = try source("android/app/src/main/kotlin/org/chotki/app/ui/SettingsScreen.kt")

        // Mentioning a setting is not offering it. The church and the calendar
        // were both named on this screen and both read-only — printed, not
        // chosen — and the check above passed the whole time. A control writes,
        // so count the writes.
        let offered = android.components(separatedBy: "Dropdown(").count - 1
        #expect(
            offered >= editableSettings.count,
            "Android names \(editableSettings.count) settings but offers \(offered) controls"
        )
        #expect(
            android.contains("updateSettings") || android.contains("setClockStyle"),
            "Android's settings screen never writes anything back"
        )
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

    /// The first thing anyone sees, on both platforms.
    ///
    /// Android had no first-run screen at all — the flag was in the shared
    /// settings and nothing on that side read it — so every install opened onto
    /// an empty day with no word about what the app was for.
    @Test("both platforms show the welcome, and both read it from core")
    func welcomeIsOnBothPlatforms() throws {
        let mac = try source("macos/Sources/Chotki/OnboardingView.swift")
        let android = try source("android/app/src/main/kotlin/org/chotki/app/ui/WelcomeScreen.kt")
        let ios = try source("ios/Chotki/WelcomeView.swift")

        for (platform, file) in [("macOS", mac), ("Android", android), ("iOS", ios)] {
            #expect(file.contains("Welcome.title"), "\(platform) does not show the welcome title")
            #expect(file.contains("Welcome.paragraphs"), "\(platform) does not show the welcome text")
            #expect(file.contains("Welcome.beginLabel"), "\(platform) writes its own button label")
            #expect(
                !file.contains("Welcome to Chotki"),
                "\(platform) has the welcome text typed into it rather than read from core"
            )
        }

        // Both have to honour the flag, or the screen shows every launch.
        for (platform, path) in [
            ("macOS", "macos/Sources/Chotki/RootView.swift"),
            ("Android", "android/app/src/main/kotlin/org/chotki/app/ui/Shell.kt"),
            ("iOS", "ios/Chotki/ChotkiApp.swift"),
        ] {
            #expect(
                try source(path).contains("hasCompletedFirstRun"),
                "\(platform) shows the welcome every launch, or never"
            )
        }
    }
}
