import SwiftUI
import ChotkiCore

/// The day, inside its stack.
///
/// The motion here is the platform's, not invented: the push and its
/// interactive back-swipe, a zoom from the row that was tapped into the screen
/// it opens, and a sheet that can be dragged between half and full. Continuity,
/// so the eye follows what moved — never reward.
struct RuleTab: View {
    @State var model: Model
    /// From the shell, so the zoom survives the push into the stack.
    var transition: Namespace.ID
    @Binding var libraryShowing: Bool

    var body: some View {
        DayView(model: model, transition: transition) { libraryShowing = true }
            .sheet(isPresented: $libraryShowing) {
                LibrarySheet(model: model)
                    .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottom) {
                if let trouble = model.trouble {
                    Text(trouble)
                        .font(.footnote)
                        .foregroundStyle(Chotki.parchment)
                        .padding()
                        .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 8))
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }
}

/// The library: what the app offers, what he has written, and the way to write
/// more.
///
/// iOS shipped with the top third of this and nothing else — the bundled
/// templates, taken on with a single tap that saved the template's defaults
/// straight to the day. No Custom section, so a rule of his own that had been
/// set aside could not be found again. No "Write your own rule" at all. And
/// "Take on" never asked how often, at what time, or whether to remind, because
/// it never opened the editor.
struct LibrarySheet: View {
    @State var model: Model
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    @State private var openSection: String?
    @State private var asking = false
    @State private var hideCaution = false

    private let sections: [(RuleCategory, String)] = [
        (.services, "Services"),
        (.prayer, "Prayer"),
        (.reading, "Reading"),
        (.fasting, "Fasting"),
        (.life, "Life"),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Select a prayer, reading, or discipline to add to your routine.")
                        .font(.system(size: 13))
                        .foregroundStyle(Chotki.faint)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    ForEach(sections, id: \.0) { category, name in
                        let templates = RuleLibrary.bundled.filter {
                            $0.category == category
                        }
                        if !templates.isEmpty {
                            panel(name, key: category.rawValue, count: templates.count) {
                                ForEach(templates, id: \.id) { template in
                                    templateRow(template)
                                }
                            }
                        }
                    }

                    panel("Custom", key: "custom", count: model.customEntries.count) {
                        if model.customEntries.isEmpty {
                            Text("Nothing of your own yet.")
                                .font(.system(size: 13))
                                .foregroundStyle(Chotki.faint)
                                .padding(.leading, 18)
                                .padding(.bottom, 12)
                        } else {
                            ForEach(model.customEntries, id: \.id) { rule in
                                customRow(rule)
                            }
                        }
                    }

                    Button(action: writeYourOwn) {
                        VStack(spacing: 10) {
                            Text("+")
                                .font(Chotki.reading(30))
                                .foregroundStyle(Chotki.gold)
                                .frame(width: 54, height: 54)
                                .overlay(Circle().stroke(Chotki.goldDim, lineWidth: 1.5))
                            Text("Write your own rule")
                                .font(Chotki.reading(16))
                                .foregroundStyle(Chotki.parchment)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.bottom, 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Write your own rule")
                }
            }
            .background(Chotki.ground)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                if case .editor(let ruleID, let startingFrom) = route {
                    RuleEditor(
                        model: model,
                        existing: ruleID.flatMap { id in model.rules.first { $0.id == id } },
                        startingFrom: startingFrom
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Chotki.gold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .overlay {
            if asking { caution }
        }
    }

    private func writeYourOwn() {
        if model.settings.customCautionDismissed {
            path.append(Route.editor(ruleID: nil, startingFrom: nil))
        } else {
            asking = true
        }
    }

    private var caution: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { asking = false }
            VStack(alignment: .leading, spacing: 16) {
                Text(customCaution)
                    .font(.system(size: 14))
                    .foregroundStyle(Chotki.parchmentDim)
                Button {
                    hideCaution.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: hideCaution ? "checkmark.square.fill" : "square")
                            .foregroundStyle(hideCaution ? Chotki.gold : Chotki.faint)
                        Text("Don't show again")
                            .foregroundStyle(Chotki.parchment)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Don't show again")
                Button("I understand") {
                    if hideCaution {
                        model.update { $0.customCautionDismissed = true }
                    }
                    asking = false
                    path.append(Route.editor(ruleID: nil, startingFrom: nil))
                }
                .buttonStyle(.borderedProminent)
                .tint(Chotki.gold)
                .accessibilityLabel("I understand")
            }
            .padding(20)
            .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(24)
        }
    }

    private func panel<Content: View>(
        _ name: String, key: String, count: Int, @ViewBuilder content: () -> Content
    ) -> some View {
        let isOpen = openSection == key
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    openSection = isOpen ? nil : key
                }
            } label: {
                HStack(spacing: 10) {
                    Text("›")
                        .font(.system(size: 15))
                        .foregroundStyle(Chotki.muted)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(name)
                        .font(.system(size: 15))
                        .foregroundStyle(Chotki.gold)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 12))
                        .foregroundStyle(Chotki.faint)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "Close \(name)" : "Open \(name), \(count) rules")
            if isOpen {
                content()
                    .padding(.bottom, 8)
            }
            Rectangle().fill(Chotki.lineSoft).frame(height: 1)
        }
    }

    private func templateRow(_ template: RuleTemplate) -> some View {
        let taken = model.isTaken(template)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                    .font(.system(size: 15))
                    .foregroundStyle(taken ? Chotki.muted : Chotki.parchment)
                Text(template.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(Chotki.faint)
                if let when = plainly(template.recurrence) {
                    Text(when).font(.system(size: 12)).foregroundStyle(Chotki.faint)
                }
                if let note = template.note, !taken {
                    Text(note).font(.system(size: 12)).foregroundStyle(Chotki.goldDim)
                }
            }
            Spacer(minLength: 8)
            if taken {
                Text("On your rule").font(.system(size: 12)).foregroundStyle(Chotki.goldDim)
            } else if let resting = model.restingCopy(of: template) {
                takeOn("Take on \(template.title)") { model.resume(resting) }
            } else {
                takeOn("Take on \(template.title)") {
                    path.append(Route.editor(ruleID: nil, startingFrom: model.ruleFrom(template)))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private func customRow(_ rule: Rule) -> some View {
        let onTheRule = model.isOnTheRule(rule)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.title)
                    .font(.system(size: 15))
                    .foregroundStyle(onTheRule ? Chotki.muted : Chotki.parchment)
                Text(rule.timeOfDay.map { Format.time($0, model.settings.clockStyle) } ?? "All day")
                    .font(.system(size: 13))
                    .foregroundStyle(Chotki.faint)
                if let note = rule.note, !note.isEmpty {
                    Text(note).font(.system(size: 12)).foregroundStyle(Chotki.faint)
                }
            }
            Spacer(minLength: 8)
            if onTheRule {
                Text("On your rule").font(.system(size: 12)).foregroundStyle(Chotki.goldDim)
            } else {
                takeOn("Take up \(rule.title)") { model.takeUp(rule) }
            }
            Button { model.setAside(rule) } label: {
                Text("✕").font(.system(size: 14)).foregroundStyle(Chotki.faint)
                    .padding(.leading, 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set aside \(rule.title)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    private func takeOn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Take on")
                .font(.system(size: 13))
                .foregroundStyle(Chotki.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Chotki.goldDim, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func plainly(_ recurrence: Recurrence) -> String? {
        switch recurrence {
        case .weekly(let days) where !days.isEmpty:
            return days.sorted { $0.rawValue < $1.rawValue }
                .map { Format.weekdayName($0) + "s" }
                .joined(separator: ", ")
        case .monthly:
            return "Monthly"
        case .once:
            return "Once"
        case .liturgical(.akathist):
            return "Fridays of the Akathist in Great Lent"
        default:
            return nil
        }
    }
}

private let customCaution =
    "This section is for personalized routines aimed at improving your overall physical, mental, and spiritual health. It is not intended to enable you to manufacture your own Orthodoxy. We strongly recommend that where appropriate, custom rules be discussed with your priest or spiritual father. If that is not possible, keep these custom rules simple and attainable (e.g., jogging, swimming, sobriety)."
