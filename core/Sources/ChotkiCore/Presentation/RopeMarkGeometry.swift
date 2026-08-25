import Foundation

/// The proportions of the app's mark: a chotki, which is what the name means.
///
/// A loop of knots with the eight-pointed cross hanging from it, as a prayer
/// rope is actually made. Kept here beside `CrossGeometry` and for the same
/// reason — the mark is drawn by the macOS icon, the Android launcher icon and
/// the corner signature, and all three should be the same rope at a different
/// size.
///
/// Every number is a fraction of the mark's square box, so a port inherits the
/// shape without inheriting a drawing framework.
public enum RopeMarkGeometry {

    /// One knot is left out at the bottom; the cross hangs in its place.
    public static let knots: Int = 12

    /// Radius of the loop the knots sit on.
    public static let loopRadius: Double = 0.30

    /// Centre of the loop. Horizontally in the middle; high enough that the
    /// cross below it still falls inside the box.
    public static let centreX: Double = 0.5
    public static let centreY: Double = 0.36

    public static let knotRadius: Double = 0.042

    /// Height of the cross hanging below the loop.
    public static let crossHeight: Double = 0.34

    /// Where each knot sits, in fractions of the box.
    ///
    /// Index 0 is the bottom of the loop and is deliberately absent — that is
    /// where the rope is joined and where the cross hangs.
    public static var knotCentres: [(x: Double, y: Double)] {
        (1..<knots).map { index in
            let angle = Double.pi / 2 + Double(index) / Double(knots) * 2 * .pi
            return (centreX + loopRadius * cos(angle), centreY + loopRadius * sin(angle))
        }
    }

    /// The box the cross occupies, as (x, y, width, height) fractions.
    public static var crossBox: (x: Double, y: Double, width: Double, height: Double) {
        let width = crossHeight * CrossGeometry.aspect
        return (centreX - width / 2, centreY + loopRadius - knotRadius, width, crossHeight)
    }
}
