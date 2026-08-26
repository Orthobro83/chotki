import SwiftUI
import ChotkiCore

/// The iOS app.
///
/// Phase 1 proves one thing and claims nothing else: that the package graph
/// resolves, that `core` compiles for iOS unchanged, and that the result
/// launches in the Simulator. Everything it shows is scaffolding.
@main
struct ChotkiApp: App {
    var body: some Scene {
        WindowGroup {
            FirstLight()
        }
    }
}

/// Scaffolding, and deliberately the smallest thing that proves core is here.
///
/// It reads from `ChotkiCore` rather than printing a greeting, because a blank
/// screen would prove the app launched and nothing about whether the shared
/// code came with it.
private struct FirstLight: View {
    private let today = CalendarDate(Date(), in: .current)

    var body: some View {
        VStack(spacing: 12) {
            Text("Chotki")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(red: 0.788, green: 0.635, blue: 0.153))

            Text(Format.longDate(today))
                .foregroundStyle(.secondary)

            Text("\(RuleLibrary.bundled.count) rules, \(PrayerBook.bundled.count) prayers, \(Psalter.all.count) psalms")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.082, green: 0.086, blue: 0.110))
    }
}
