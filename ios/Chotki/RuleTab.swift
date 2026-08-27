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
    @State private var libraryShowing = false

    var body: some View {
        DayView(model: model, transition: transition) { libraryShowing = true }
            .navigationTitle("Chotki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { libraryShowing = true } label: {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .accessibilityLabel("Library")
                }
            }
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
    /// Half height to browse, full to fill a form in.
    ///
    /// The editor in a medium sheet shows about two fields, and the recurrence
    /// and reminder controls — the whole reason it opens before the rule lands
    /// on the day — are below the fold. Browsing wants the day still visible
    /// behind it; writing does not.
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Text("Take on what you are ready for. Two or three is a good beginning.")
                        .font(.footnote).foregroundStyle(Chotki.faint)
                        .listRowBackground(Chotki.ground)
                }

                ForEach(RuleLibrary.bundled, id: \.id) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title).foregroundStyle(Chotki.parchment)
                            Text(template.summary).font(.caption).foregroundStyle(Chotki.faint)
                        }
                        Spacer(minLength: 8)
                        if model.isTaken(template) {
                            Text("On your rule").font(.caption).foregroundStyle(Chotki.goldDim)
                        } else {
                            // Into the editor, filled in — not straight onto
                            // the day. How often and when are part of taking
                            // something on, not something to discover
                            // afterwards.
                            NavigationLink(
                                value: Route.editor(
                                    ruleID: nil, startingFrom: model.ruleFrom(template)
                                )
                            ) {
                                Text("Take on").font(.callout).foregroundStyle(Chotki.gold)
                            }
                            .fixedSize()
                            .accessibilityLabel("Take on \(template.title)")
                        }
                    }
                    .listRowBackground(Chotki.ground)
                }

                if !model.customEntries.isEmpty { custom }

                Section {
                    NavigationLink(value: Route.editor(ruleID: nil, startingFrom: nil)) {
                        Label("Write your own rule", systemImage: "plus")
                            .foregroundStyle(Chotki.gold)
                    }
                    .accessibilityLabel("Write your own rule")
                    .listRowBackground(Chotki.ground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
        .presentationDetents([.medium, .large], selection: $detent)
        .onChange(of: path.count) { _, depth in
            withAnimation(.snappy(duration: 0.25)) { detent = depth > 0 ? .large : .medium }
        }
    }

    /// Rules he wrote, whether or not they are in force.
    @ViewBuilder
    private var custom: some View {
        Section {
            Text("Custom routines are usually taken on the advice of your priest or spiritual father.")
                .font(.footnote).foregroundStyle(Chotki.faint)
                .listRowBackground(Chotki.ground)

            ForEach(model.customEntries, id: \.id) { rule in
                let onTheRule = model.isOnTheRule(rule)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.title)
                            .foregroundStyle(onTheRule ? Chotki.muted : Chotki.parchment)
                        Text(rule.timeOfDay.map { Format.time($0, model.settings.clockStyle) }
                             ?? "All day")
                            .font(.caption).foregroundStyle(Chotki.faint)
                        if let note = rule.note, !note.isEmpty {
                            Text(note).font(.caption).italic()
                                .foregroundStyle(Chotki.faint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    if onTheRule {
                        Text("On your rule").font(.caption).foregroundStyle(Chotki.goldDim)
                    } else {
                        Button("Take on") { withAnimation(.snappy) { model.takeUp(rule) } }
                            .buttonStyle(.bordered).tint(Chotki.gold)
                            .accessibilityLabel("Take on \(rule.title)")
                    }
                }
                .listRowBackground(Chotki.ground)
                // The rule and everything it has kept stay as they are; this
                // only takes it out of the library listing.
                .swipeActions(edge: .trailing) {
                    Button("Set aside") { withAnimation(.snappy) { model.setAside(rule) } }
                        .tint(Chotki.faint)
                }
            }
        } header: {
            Text("Custom").foregroundStyle(Chotki.gold)
        }
    }
}
