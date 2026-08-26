import SwiftUI
import ChotkiCore

@main
struct ChotkiApp: App {
    var body: some Scene {
        WindowGroup { Root() }
    }
}

/// Opens the record, or says plainly why it could not.
///
/// A store that fails to open is not a condition to recover from — there is no
/// app without it — but it is one to report rather than crash on, so that a
/// person sees a sentence instead of an icon that disappears.
private struct Root: View {
    @State private var opening = StoreOpening.attempt()

    var body: some View {
        switch opening {
        case .opened(let store):
            Day(model: Model(store: store))
        case .failed(let why):
            VStack(spacing: 10) {
                Text("Chotki could not open its record")
                    .foregroundStyle(Chotki.parchment)
                Text(why).font(.footnote).foregroundStyle(Chotki.muted)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Chotki.ground)
        }
    }
}

/// Phase 3 shows the day and a way to put something on it. The library is a
/// sheet here rather than a screen, which is where phase 4 will take it.
private struct Day: View {
    @State var model: Model
    @State private var libraryShowing = false

    var body: some View {
        VStack(spacing: 0) {
            DayView(model: model)

            Button {
                libraryShowing = true
            } label: {
                Label("Library", systemImage: "books.vertical")
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .tint(Chotki.gold)
        }
        .background(Chotki.ground)
        .sheet(isPresented: $libraryShowing) {
            Library(model: model)
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

/// Enough of the library to put a rule on the day. The whole of it is phase 5.
private struct Library: View {
    @State var model: Model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Take on what you are ready for. Two or three is a good beginning.")
                        .font(.footnote)
                        .foregroundStyle(Chotki.faint)
                        .listRowBackground(Chotki.ground)
                }
                ForEach(RuleLibrary.bundled, id: \.id) { template in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title).foregroundStyle(Chotki.parchment)
                            Text(template.summary)
                                .font(.caption).foregroundStyle(Chotki.faint)
                        }
                        Spacer(minLength: 8)
                        if model.isTaken(template) {
                            Text("On your rule")
                                .font(.caption).foregroundStyle(Chotki.goldDim)
                        } else {
                            Button("Take on") {
                                withAnimation(.snappy) { model.take(template) }
                            }
                            .buttonStyle(.bordered)
                            .tint(Chotki.gold)
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
