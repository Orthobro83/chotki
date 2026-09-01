import SwiftUI
import UIKit

/// The same palette the other two platforms use, to the same values.
enum Chotki {
    static let ground = Color(red: 0.082, green: 0.086, blue: 0.110)
    static let panel = Color(red: 0.110, green: 0.118, blue: 0.149)
    static let line = Color(red: 0.180, green: 0.165, blue: 0.125)

    static let gold = Color(red: 0.788, green: 0.635, blue: 0.153)
    static let goldDim = Color(red: 0.541, green: 0.447, blue: 0.125)

    static let parchment = Color(red: 0.910, green: 0.875, blue: 0.804)
    static let parchmentDim = Color(red: 0.847, green: 0.812, blue: 0.741)
    static let muted = Color(red: 0.541, green: 0.522, blue: 0.471)
    static let faint = Color(red: 0.353, green: 0.337, blue: 0.298)

    // MARK: the reading face

    /// The faces tried, in order, for anything meant to be read.
    ///
    /// The same chain macOS uses, and for the same reasons. Iowan Old Style
    /// ships with iOS as well, so the two platforms land on the same face
    /// without either bundling it — which neither may: it is John Downer's,
    /// released through Bitstream and licensed to Apple. Charter is the
    /// fallback on the merits rather than merely by availability, being drawn
    /// to the same brief; it is also the face Android will bundle, since it is
    /// the one of the two that may be redistributed.
    ///
    /// Family names rather than PostScript names, so `.bold()` and `.italic()`
    /// resolve to the real cuts instead of being synthesised.
    static let serifChain = ["Iowan Old Style", "Charter"]

    /// The first face in the chain this device actually has, or nil.
    ///
    /// Resolved once, by asking UIKit. `Font.custom` falls back **silently**
    /// when a face is missing, which on macOS meant six call sites asked for a
    /// font that was never installed and rendered in the system sans for
    /// months without anyone noticing. The chain is walked rather than hoped at.
    static let readingFace: String? = serifChain.first { UIFont(name: $0, size: 12) != nil }

    /// The face for anything meant to be read: prayers, psalms, the day's
    /// readings, the fathers, glossary entries, reflections, the welcome.
    ///
    /// Chrome keeps the system sans — tab bars, the month grid's numerals,
    /// times, buttons and settings, where figures need to be tight and
    /// unambiguous.
    ///
    /// `relativeTo:` is what keeps Dynamic Type working, which matters more
    /// here than on the Mac: a phone is where someone actually turns the text
    /// size up.
    static func reading(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        guard let readingFace else { return .system(size: size, design: .serif) }
        return .custom(readingFace, size: size, relativeTo: style)
    }
}
