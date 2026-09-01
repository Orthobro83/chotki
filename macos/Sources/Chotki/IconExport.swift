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

    /// The single 1024 square iOS wants; the system makes every other size.
    static func runPhone(to path: String) {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { NSApp.terminate(nil); return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        CrossIcon.phoneIcon(size: 1024).draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
        NSGraphicsContext.restoreGraphicsState()

        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            FileHandle.standardOutput.write(Data("wrote \(path)\n".utf8))
        }
        NSApp.terminate(nil)
    }

    /// The menu bar image at the sizes it is actually drawn at, on a mid grey so
    /// a template image can be seen at all.
    ///
    /// It is 18 points tall in a 22 point bar and its knots are under a point
    /// across. That is not something to reason about — it is something to look
    /// at, at 1x and at 2x, before deciding it works.
    static func runMenuBar(to directory: String) {
        let url = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for height in [16, 18, 20, 22] as [CGFloat] {
            for scale in [1, 2, 3] as [CGFloat] {
                let mark = CrossIcon.menuBarImage(height: height)
                let pixels = NSSize(
                    width: (mark.size.width * scale).rounded(),
                    height: (mark.size.height * scale).rounded())
                guard let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
                ) else { continue }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                NSColor(white: 0.45, alpha: 1).setFill()
                NSRect(origin: .zero, size: pixels).fill()
                mark.draw(in: NSRect(origin: .zero, size: pixels))
                NSGraphicsContext.restoreGraphicsState()
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: url.appendingPathComponent(
                        "menubar-\(Int(height))pt@\(Int(scale))x.png"))
                }
            }
        }
        FileHandle.standardOutput.write(Data("wrote menu bar images\n".utf8))
        // Without this the app carries on launching and `swift run` never
        // returns. The window renderer terminates for the same reason.
        NSApp.terminate(nil)
    }

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
