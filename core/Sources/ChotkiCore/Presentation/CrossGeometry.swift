import Foundation

/// The proportions of the eight-pointed cross, in one place.
///
/// Taken from a reference drawing rather than invented, and expressed as
/// fractions of a bounding box, so every drawing of it — the menu bar icon, the
/// Dock icon, the watermark, the rope mark — is the same cross at a different
/// size.
///
/// Deliberately plain numbers rather than `CGRect`: geometry is data, and a
/// port to another platform should inherit the shape without inheriting a
/// drawing framework.
///
/// Note the footrest: the viewer's **left** end is the raised one. That is the
/// traditional orientation — it points to Paradise, for the thief crucified at
/// Christ's right hand. An earlier version had it mirrored.
public enum CrossGeometry {

    /// Width divided by height.
    public static let aspect: Double = 748.0 / 1440.0

    /// Upright, titulus and crossbar, as fractions of the bounding box.
    public struct Bar: Sendable, Hashable {
        public let x: Double, y: Double, width: Double, height: Double
    }

    public static let bars: [Bar] = [
        Bar(x: 0.402, y: 0.000, width: 0.201, height: 1.000),   // upright
        Bar(x: 0.205, y: 0.101, width: 0.594, height: 0.097),   // titulus
        Bar(x: 0.000, y: 0.299, width: 1.000, height: 0.097)    // crossbar
    ]

    /// The slanted footrest, as a parallelogram with vertical ends.
    public struct Footrest: Sendable, Hashable {
        public let leadingX: Double, trailingX: Double
        public let leadingY: Double, trailingY: Double
        public let thickness: Double
    }

    public static let footrest = Footrest(
        leadingX: 0.209, trailingX: 0.786,
        leadingY: 0.639, trailingY: 0.792,
        thickness: 0.097
    )

    /// The box the cross occupies inside the given one, keeping its proportions.
    /// Returned as (x, y, width, height) so no drawing type is needed.
    public static func fitted(
        inX x: Double, y: Double, width: Double, height: Double
    ) -> (x: Double, y: Double, width: Double, height: Double) {
        var w = width
        var h = height
        if w / h > aspect { w = h * aspect } else { h = w / aspect }
        return (x + width / 2 - w / 2, y + height / 2 - h / 2, w, h)
    }
}
