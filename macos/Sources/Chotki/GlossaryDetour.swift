import SwiftUI

/// An overlay keeps the underlying reader and its scroll position alive.
struct GlossaryDetour: ViewModifier {
    @ObservedObject var model: AppModel
    var backTitle = "Back"
    var enabled = true
    func body(content: Content) -> some View {
        content.overlay {
            if enabled, case .glossary(let slug) = model.screen {
                VStack(spacing: 0) {
                    Header(title: backTitle) { model.screen = model.glossaryReturn }
                    GlossaryView(model: model, initialSlug: slug).id(slug ?? "all")
                }.background(ChotkiBackdrop()).transition(.opacity)
            }
        }
    }
}

extension View {
    func glossaryDetour(model: AppModel, backTitle: String = "Back", enabled: Bool = true) -> some View {
        modifier(GlossaryDetour(model: model, backTitle: backTitle, enabled: enabled))
    }
}
