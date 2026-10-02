import CoreGraphics
import Foundation

/// Hand-reviewed landmarks in Android's 42-image rotation. Coordinates are
/// fractions of the original image, so a portrait can end on a face while a
/// church interior ends on its iconostasis or dome. Keep every rotation image
/// represented here when the library changes.
enum SayingPanFocus {
    private struct ApprovedSource: Decodable {
        let number: Int
        let focusX: Double
        let focusY: Double
    }

    static let approvedPoints: [Int: CGPoint] = {
        guard let url = Bundle.module.url(forResource: "approved-sources", withExtension: "json", subdirectory: "Resources/sayings"),
              let data = try? Data(contentsOf: url),
              let sources = try? JSONDecoder().decode([ApprovedSource].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: sources.map {
            ($0.number, CGPoint(x: $0.focusX, y: $0.focusY))
        })
    }()

    static let points: [Int: CGPoint] = [
        1: CGPoint(x: 0.60, y: 0.41),  // Annunciation faces
        2: CGPoint(x: 0.67, y: 0.40),  // crucifixion in manuscript
        3: CGPoint(x: 0.50, y: 0.30),  // Christ's face
        4: CGPoint(x: 0.50, y: 0.46),  // church mosaic
        5: CGPoint(x: 0.52, y: 0.48),  // icon scene
        6: CGPoint(x: 0.46, y: 0.39),  // angel's face
        7: CGPoint(x: 0.51, y: 0.53),  // Theotokos and Child
        8: CGPoint(x: 0.50, y: 0.33),  // saint's face
        9: CGPoint(x: 0.51, y: 0.39),  // prophets
        10: CGPoint(x: 0.50, y: 0.47), // crucifixion scene
        11: CGPoint(x: 0.50, y: 0.34), // figures' faces
        12: CGPoint(x: 0.65, y: 0.18), // archangel's face
        13: CGPoint(x: 0.32, y: 0.16), // bishop's face
        14: CGPoint(x: 0.50, y: 0.43), // cross and figures
        15: CGPoint(x: 0.52, y: 0.44), // figures' faces
        16: CGPoint(x: 0.50, y: 0.43), // Transfiguration
        17: CGPoint(x: 0.50, y: 0.37), // manuscript figure
        18: CGPoint(x: 0.50, y: 0.47), // church dome
        19: CGPoint(x: 0.50, y: 0.48), // iconostasis
        20: CGPoint(x: 0.50, y: 0.27), // Christ's face
        21: CGPoint(x: 0.50, y: 0.48), // dome mosaic
        22: CGPoint(x: 0.50, y: 0.25), // Saint Nicholas's face
        23: CGPoint(x: 0.50, y: 0.35), // saint's face
        24: CGPoint(x: 0.50, y: 0.49), // cross
        25: CGPoint(x: 0.50, y: 0.45), // icon scene
        26: CGPoint(x: 0.50, y: 0.23), // standing saint's face
        27: CGPoint(x: 0.52, y: 0.19), // Saint George's face
        28: CGPoint(x: 0.50, y: 0.31), // saint's face
        29: CGPoint(x: 0.50, y: 0.30), // saint's face
        30: CGPoint(x: 0.50, y: 0.49), // dome's central image
        31: CGPoint(x: 0.50, y: 0.31), // bishop's face
        32: CGPoint(x: 0.50, y: 0.41), // Theotokos and Child
        33: CGPoint(x: 0.50, y: 0.43), // Theotokos and Child
        34: CGPoint(x: 0.50, y: 0.47), // mosaic scene
        35: CGPoint(x: 0.50, y: 0.48), // icons and candles
        36: CGPoint(x: 0.50, y: 0.40), // icon group
        37: CGPoint(x: 0.50, y: 0.50), // existing carved panel
        38: CGPoint(x: 0.50, y: 0.50), // existing carved panel
        39: CGPoint(x: 0.50, y: 0.45), // church iconostasis
        40: CGPoint(x: 0.50, y: 0.49), // candlelit church
        41: CGPoint(x: 0.50, y: 0.27), // saint's face
        42: CGPoint(x: 0.50, y: 0.29)  // figures' faces
    ]

    static func point(for name: String) -> CGPoint {
        let number = Int(URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent) ?? 0
        return points[number] ?? approvedPoints[number] ?? CGPoint(x: 0.5, y: 0.45)
    }

    /// The final image origin, constrained so no unpainted edge enters view.
    static func restingOrigin(image: CGSize, viewport: CGSize, focus: CGPoint) -> CGPoint {
        let x = min(0, max(viewport.width - image.width,
                           viewport.width * 0.5 - focus.x * image.width))
        let y = min(0, max(viewport.height - image.height,
                           viewport.height * 0.4 - focus.y * image.height))
        return CGPoint(x: x, y: y)
    }

    /// Start close enough to the resting crop that a tall portrait cannot
    /// sweep across its whole height. The 8% overscan always leaves room for
    /// movement, even when the subject already sits in the center of a photo.
    static func startingOrigin(image: CGSize, viewport: CGSize, resting: CGPoint,
                               imageNumber: Int) -> CGPoint {
        func nearby(_ end: CGFloat, lower: CGFloat, upper: CGFloat,
                    travel: CGFloat, sign: CGFloat) -> CGFloat {
            let preferredRoom = sign > 0 ? upper - end : end - lower
            let oppositeRoom = sign > 0 ? end - lower : upper - end
            let direction = preferredRoom >= min(travel, oppositeRoom) ? sign : -sign
            return min(upper, max(lower, end + direction * travel))
        }
        return CGPoint(
            x: nearby(resting.x, lower: viewport.width - image.width, upper: 0,
                      travel: 14, sign: imageNumber.isMultiple(of: 2) ? 1 : -1),
            y: nearby(resting.y, lower: viewport.height - image.height, upper: 0,
                      travel: 18, sign: imageNumber.isMultiple(of: 3) ? 1 : -1)
        )
    }
}
