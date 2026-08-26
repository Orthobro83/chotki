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
                    .presentationDetents([.medium, .large])
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

struct LibrarySheet: View {
    @State var model: Model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
                            Button("Take on") {
                                withAnimation(.snappy) { model.take(template) }
                            }
                            .buttonStyle(.bordered).tint(Chotki.gold)
                            .accessibilityLabel("Take on \(template.title)")
                        }
                    }
                    .listRowBackground(Chotki.ground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Chotki.ground)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Chotki.gold)
                }
            }
        }
    }
}
