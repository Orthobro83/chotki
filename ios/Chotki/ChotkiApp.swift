import SwiftUI
import ChotkiCore

@main
struct ChotkiApp: App {
    var body: some Scene {
        WindowGroup {
            Root()
                // Chotki is dark by design, not by preference — gold on a near
                // black ground, on every platform. Without this the system's
                // own chrome follows the phone, and Settings drew its Form as
                // white cards inside a dark app. Every other screen paints its
                // own background, so nothing else showed it: on a phone already
                // set to dark it would have looked correct and been wrong.
                .preferredColorScheme(.dark)
                // Asked once, plainly, and not insisted on. Nothing arrives
                // without it and nothing errors, so the alternative to asking
                // is reminders that silently never come.
                .task { _ = await Reminders().requestAuthorization() }
        }
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !model.settings.hasCompletedFirstRun {
                WelcomeView(model: model)
            } else {
                places
            }
        }
        // Coming back to the foreground is the moment a phone finds out what
        // day it is. The app is rarely quit, so without this the view can sit
        // on a stale day for as long as the process happens to live.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.advanceDayIfNeeded() }
        }
        // Fires at midnight, and on a timezone or clock change — the case
        // where the app is left open and nobody backgrounds it.
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.significantTimeChangeNotification
            )
        ) { _ in
            model.advanceDayIfNeeded()
        }
    }

    private var places: some View {
        TabView(selection: $place) {
            ForEach(Place.allCases, id: \.self) { candidate in
                NavigationStack(path: binding(for: candidate)) {
                    content(for: candidate)
                        .navigationDestination(for: Route.self) { route in
                            Destination(model: model, route: route, transition: transition)
                        }
                }
                // A word tapped anywhere in this tab opens the glossary on
                // *this* tab's stack, so the back-swipe returns to the passage
                // it was read in rather than to some other tab's history.
                .environment(\.goToPlace, GoToPlace { destination in
                    place = destination
                })
                .environment(\.pushRoute, PushRoute { route in
                    paths[candidate, default: NavigationPath()].append(route)
                })
                .environment(\.openTerm, OpenTerm { slug in
                    paths[candidate, default: NavigationPath()].append(Route.term(slug: slug))
                })
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
        case .prayers: RopeView(model: model)
        case .reading: ReadingView(model: model)
        case .progress: ProgressView_(model: model)
        case .settings: SettingsView_(model: model)
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
            PrayersView(model: model, ruleID: ruleID)
                .zoomDestination(id: ruleID, in: transition)
        case .editor(let ruleID, let startingFrom):
            RuleEditor(
                model: model,
                existing: ruleID.flatMap { id in model.rules.first { $0.id == id } },
                startingFrom: startingFrom
            )
        case .term(let slug):
            GlossaryView_(model: model, slug: slug)
        case .psalter:
            PsalterView(model: model)
        case .rope:
            RopeView(model: model)
        case .reflections(let weekday):
            ReflectionsView(model: model, openAt: weekday)
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
