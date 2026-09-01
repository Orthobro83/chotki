import SwiftUI
import AppKit

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

    // MARK: the reading face

    /// The faces tried, in order, for anything meant to be read.
    ///
    /// **Iowan Old Style is not bundled and cannot be.** It is John Downer's,
    /// released through Bitstream and licensed to Apple; it ships with macOS
    /// and iOS but redistributing it in an app would be a licence violation.
    /// It also lives in *Supplemental*, which someone can disable in Font Book,
    /// so its presence is likely rather than certain — hence a chain.
    ///
    /// **Charter is the fallback on the merits, not merely by availability.**
    /// Matthew Carter, 1987, also originally Bitstream, drawn to the same brief
    /// as Iowan: large x-height, low stroke contrast, sturdy blunt serifs,
    /// engineered to hold up at text sizes. It is the nearest thing in the
    /// system to what Iowan does — and, unlike Iowan, it is freely
    /// redistributable, which is why it is the face the Android port will
    /// bundle.
    ///
    /// Family names rather than PostScript names, so `.bold()` and `.italic()`
    /// resolve to the real cuts instead of being synthesised.
    static let serifChain = ["Iowan Old Style", "Charter"]

    /// The first face in the chain this machine actually has, or nil.
    ///
    /// Resolved once, by asking AppKit. `Font.custom` falls back **silently**
    /// when a face is missing, which would make a broken chain invisible rather
    /// than obviously wrong — so the chain is walked rather than hoped at.
    static let readingFace: String? = serifChain.first { NSFont(name: $0, size: 12) != nil }

    /// The face for anything meant to be read: prayers, psalms, readings,
    /// glossary entries, reflections, the progress prose.
    ///
    /// Chrome keeps the system sans — the sidebar, the month grid's numerals,
    /// times, buttons and settings. Figures in a dense grid want to be tight
    /// and unambiguous, and AppKit controls do not take a custom face cleanly.
    ///
    /// `relativeTo:` is what keeps Dynamic Type working; `Font.custom(_:size:)`
    /// without it pins the size and quietly opts the app out.
    static func reading(
        _ size: CGFloat, relativeTo style: Font.TextStyle = .body
    ) -> Font {
        guard let readingFace else { return .system(size: size, design: .serif) }
        return .custom(readingFace, size: size, relativeTo: style)
    }

    static let popoverWidth: CGFloat = 400
    /// Fixed. The popover must not resize itself around whatever tab happens to
    /// be showing — a short tab would shrink it and leave every other tab
    /// scrolling inside a window that never grew back.
    static let popoverHeight: CGFloat = 560
}

extension View {
    /// A row that reads as tappable without shouting.
    func rowBackground(_ active: Bool = false) -> some View {
        background(active ? Theme.panel : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
