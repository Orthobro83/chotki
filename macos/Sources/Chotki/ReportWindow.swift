import SwiftUI
import AppKit
import ChotkiCore

/// The report, given room. Same content as the tab, with the per-rule detail
/// laid out properly rather than squeezed into a 400pt popover.
struct ReportWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let report = model.report(days: 90)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your progress up to \(Format.longDate(model.progressThrough)) — the ninety days to then")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                    ForEach(report.summary, id: \.self) { line in
                        Text(line)
                            .font(Theme.reading(17))
                            .foregroundStyle(Theme.parchment)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if model.settings.showConsistencyNumber, let overall = report.overall {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(Int((overall * 100).rounded()))%")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.gold)
                        Text("Kept")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                }

                if report.hasAnythingDue {
                    Rectangle().fill(Theme.line).frame(height: 1)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(report.perRule.filter(\.hasAnythingDue)) { score in
                            HStack(alignment: .firstTextBaseline) {
                                Text(score.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.parchment)
                                Spacer()
                                if score.streak > 1 {
                                    Text("\(score.streak) in a row")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.goldDim)
                                }
                                Text("\(score.kept + score.keptLate) of \(score.scoreable)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                                    .monospacedDigit()
                                    .frame(width: 74, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            Rectangle().fill(Theme.lineSoft).frame(height: 1)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.ground)
    }
}

/// Keeps one report window rather than opening a new one each time.
@MainActor
final class ReportWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Progress"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: ReportWindowView(model: model))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
