import SwiftUI

/// The palette from the design: deep charcoal ground, byzantine gold for today
/// and for what has been kept, muted violet for fasting, ochre for liturgy days.
///
/// Restraint is the point. Ornament reads as kitsch at 12pt, so the Orthodox
/// character comes from colour and typography rather than decoration.
enum Theme {
    static let ground = Color(red: 0.082, green: 0.086, blue: 0.110)
    static let panel = Color(red: 0.110, green: 0.118, blue: 0.149)
    static let line = Color(red: 0.180, green: 0.165, blue: 0.125)
    static let lineSoft = Color(red: 0.137, green: 0.145, blue: 0.173)

    static let gold = Color(red: 0.788, green: 0.635, blue: 0.153)
    static let goldDim = Color(red: 0.541, green: 0.447, blue: 0.125)
    static let parchment = Color(red: 0.910, green: 0.875, blue: 0.804)
    static let parchmentDim = Color(red: 0.847, green: 0.812, blue: 0.741)
    static let muted = Color(red: 0.541, green: 0.522, blue: 0.471)
    static let faint = Color(red: 0.353, green: 0.337, blue: 0.298)

    /// Fasting seasons. Never used to mark something as missed.
    static let violet = Color(red: 0.604, green: 0.561, blue: 0.769)
    /// Liturgy days. Note there is deliberately no "missed" colour anywhere in
    /// the palette — see the Tone section in design.md.
    static let ochre = Color(red: 0.651, green: 0.227, blue: 0.220)

    static let popoverWidth: CGFloat = 400
}

extension View {
    /// A row that reads as tappable without shouting.
    func rowBackground(_ active: Bool = false) -> some View {
        background(active ? Theme.panel : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
