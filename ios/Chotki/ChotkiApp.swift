import SwiftUI
import ChotkiCore

@main
struct ChotkiApp: App {
    var body: some Scene {
        WindowGroup {
            FirstLight()
        }
    }
}

/// Scaffolding for phase 2, and it proves exactly one thing: that the record
/// survives.
///
/// Not a screen anyone will keep. It opens the store where the app will really
/// keep it, runs the schema ladder on the way in, writes a rule when asked, and
/// counts what is there — so that quitting and relaunching answers the only
/// question this phase asks.
struct FirstLight: View {
    @State private var opening = StoreOpening.attempt()
    @State private var rules: [Rule] = []
    @State private var note = ""

    private let gold = Color(red: 0.788, green: 0.635, blue: 0.153)
    private let ground = Color(red: 0.082, green: 0.086, blue: 0.110)
    private let parchment = Color(red: 0.910, green: 0.875, blue: 0.804)

    var body: some View {
        VStack(spacing: 14) {
            Text("Chotki").font(.system(size: 28, weight: .semibold)).foregroundStyle(gold)

            switch opening {
            case .failed(let why):
                Text(why).foregroundStyle(.red).multilineTextAlignment(.center)

            case .opened(let store):
                Text(Format.longDate(CalendarDate(Date(), in: .current)))
                    .foregroundStyle(parchment)

                Text("\(rules.count) rule\(rules.count == 1 ? "" : "s") on the record")
                    .font(.footnote).foregroundStyle(.secondary)

                ForEach(rules, id: \.id) { rule in
                    Text("· \(rule.title)").font(.footnote).foregroundStyle(parchment)
                }

                Button("Take on a rule") { take(into: store) }
                    .buttonStyle(.bordered).tint(gold).padding(.top, 6)

                if !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }

                Text("Quit and reopen — the count should hold.")
                    .font(.caption2).foregroundStyle(.tertiary).padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ground)
        .task { reload() }
    }

    private func reload() {
        guard case .opened(let store) = opening else { return }
        rules = (try? store.rules(includeArchived: false)) ?? []
    }

    private func take(into store: SQLiteStore) {
        // Straight from the library, the way the app really does it, so this
        // exercises the recurrence and reminder types rather than a bare row.
        guard let template = RuleLibrary.bundled.first(where: { $0.id == "morning-prayers" })
        else { note = "the library has no morning prayers"; return }

        do {
            let rule = template.makeRule(source: "the library")
            try store.save(rule)
            try store.save(Activation(ruleID: rule.id, from: CalendarDate(Date(), in: .current)))
            note = "saved"
            reload()
        } catch {
            note = "could not save: \(error)"
        }
    }
}
