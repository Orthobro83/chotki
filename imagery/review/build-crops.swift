import AppKit
import Foundation

// Makes review-only card crops using the same overscan and subject position as
// SayingPanFocus. The source images in previews/ are downsized; approved images
// must later be fetched from their original source pages.
struct Candidate: Decodable {
    let id: String
    let focusX: CGFloat
    let focusY: CGFloat
    let preview: String
    let crop: String
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let manifest = try JSONDecoder().decode([Candidate].self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
let viewport = CGSize(width: 850, height: 270)

for item in manifest {
    guard let image = NSImage(contentsOf: root.appendingPathComponent(item.preview)) else {
        throw NSError(domain: "CandidateReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing preview: \(item.id)"])
    }
    let scale = max(viewport.width / image.size.width, viewport.height / image.size.height) * 1.08
    let rendered = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let origin = CGPoint(
        x: min(0, max(viewport.width - rendered.width, viewport.width * 0.5 - item.focusX * rendered.width)),
        y: min(0, max(viewport.height - rendered.height, viewport.height * 0.4 - item.focusY * rendered.height))
    )
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(viewport.width), pixelsHigh: Int(viewport.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSBezierPath(rect: CGRect(origin: .zero, size: viewport)).addClip()
    image.draw(in: CGRect(x: origin.x, y: viewport.height - (origin.y + rendered.height), width: rendered.width, height: rendered.height), from: CGRect(origin: .zero, size: image.size), operation: .copy, fraction: 1)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.86]) else {
        throw NSError(domain: "CandidateReview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not render crop: \(item.id)"])
    }
    try jpeg.write(to: root.appendingPathComponent(item.crop))
}
print("Rendered \(manifest.count) review-only crops")
