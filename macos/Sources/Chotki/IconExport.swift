import AppKit

/// Writes the app icon out as PNGs for `iconutil` to turn into an `.icns`.
///
/// Setting `NSApp.applicationIconImage` at launch only changes the Dock icon of
/// the running app. Launchpad, Finder and the Get Info panel all read the icon
/// from the bundle, so without a real icon file they show the generic
/// placeholder — which is exactly what they did.
///
/// Generated at build time from the same `CrossGeometry` everything else uses,
/// rather than checked in, so the icon cannot fall out of step with the app.
@MainActor
enum IconExport {

    /// The sizes an iconset needs, and the names Apple expects for them.
    private static let variants: [(name: String, pixels: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024)
    ]

    static func run(to directory: String) {
        let url = URL(fileURLWithPath: directory)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            for variant in variants {
                guard let data = png(pixels: variant.pixels) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: url.appendingPathComponent("\(variant.name).png"))
            }
            FileHandle.standardOutput.write(Data("wrote \(variants.count) icon sizes\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("icon export failed: \(error)\n".utf8))
        }
        NSApp.terminate(nil)
    }

    /// Drawn straight into a bitmap of the exact pixel size, so small sizes are
    /// rendered rather than scaled down from a large one.
    private static func png(pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        CrossIcon.appIcon(size: CGFloat(pixels))
            .draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))

        return rep.representation(using: .png, properties: [:])
    }
}
