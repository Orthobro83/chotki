import SwiftUI
import ChotkiCore

@main
struct ChotkiApp: App {
    var body: some Scene {
        WindowGroup { Root() }
    }
}

/// Opens the record, or says plainly why it could not.
private struct Root: View {
    @State private var opening = StoreOpening.attempt()

    var body: some View {
        switch opening {
        case .opened(let store):
            Shell(model: Model(store: store))
        case .failed(let why):
            VStack(spacing: 10) {
                Text("Chotki could not open its record").foregroundStyle(Chotki.parchment)
                Text(why).font(.footnote).foregroundStyle(Chotki.muted)
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Chotki.ground)
        }
    }
}

/// The places, each with its own stack.
///
/// A stack per tab rather than one shared: going three deep into a rule's
/// prayers and then to the readings should not lose where you were, and coming
/// back should find it. That is the platform's own behaviour and worth having
/// rather than flattening.
struct Shell: View {
    @State var model: Model
    @State private var place: Place = .rule
    @State private var paths: [Place: NavigationPath] = [:]
    @Namespace private var transition

    var body: some View {
        TabView(selection: $place) {
            ForEach(Place.allCases, id: \.self) { candidate in
                NavigationStack(path: binding(for: candidate)) {
                    content(for: candidate)
                        .navigationDestination(for: Route.self) { route in
                            Destination(model: model, route: route, transition: transition)
                        }
                }
                .tabItem { Label(candidate.rawValue, systemImage: candidate.symbol) }
                .tag(candidate)
            }
        }
        .tint(Chotki.gold)
    }

    private func binding(for place: Place) -> Binding<NavigationPath> {
        Binding(
            get: { paths[place] ?? NavigationPath() },
            set: { paths[place] = $0 }
        )
    }

    @ViewBuilder
    private func content(for place: Place) -> some View {
        switch place {
        case .rule: RuleTab(model: model, transition: transition)
        case .prayers: NotYet(place: "Prayers")
        case .reading: NotYet(place: "Reading")
        case .progress: NotYet(place: "Progress")
        case .settings: NotYet(place: "Settings")
        }
    }
}

/// Where a route lands. Phase 5 fills these in; the point of building them now
/// is that the push, the back-swipe and the transition are settled before the
/// screens arrive rather than retro-fitted around them.
private struct Destination: View {
    @State var model: Model
    let route: Route
    var transition: Namespace.ID

    var body: some View {
        switch route {
        case .prayers(let ruleID):
            let title = model.rules.first { $0.id == ruleID }?.title ?? "Prayers"
            NotYet(place: title)
                .navigationTitle(title)
                .zoomDestination(id: ruleID, in: transition)
        case .editor(let ruleID):
            NotYet(place: ruleID == nil ? "A rule of your own" : "Editing")
        case .term(let slug):
            NotYet(place: slug ?? "Glossary")
        case .psalter:
            NotYet(place: "The Psalter")
        case .rope:
            NotYet(place: "The rope")
        }
    }
}

/// Scaffolding that says so. Better than a blank screen, which reads as a bug.
struct NotYet: View {
    let place: String

    var body: some View {
        VStack(spacing: 8) {
            Text(place).foregroundStyle(Chotki.parchment)
            Text("Not built yet.").font(.footnote).foregroundStyle(Chotki.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Chotki.ground)
    }
}
