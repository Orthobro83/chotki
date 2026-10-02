import SwiftUI
import AppKit
import ChotkiCore

/// Existing Android artwork, selected with the same one-based day-of-year rotation.
@MainActor enum SayingImages {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 3
        return cache
    }()
    static let names: [String] = {
        guard let url = Bundle.module.url(forResource: "order", withExtension: "txt", subdirectory: "Resources/sayings"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }()
    static func name(for date: CalendarDate) -> String? {
        guard !names.isEmpty else { return nil }
        let first = CalendarDate(year: date.year, month: 1, day: 1)!
        return names[(first.days(until: date) + 1) % names.count]
    }
    static func image(named name: String) -> NSImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources") else { return nil }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }
}

struct SayingCard: View {
    @ObservedObject var model: AppModel
    var compact = false
    var body: some View {
        if let saying = PatristicReadings.shared.reading(for: model.selectedDate),
           let name = SayingImages.name(for: model.selectedDate), let image = SayingImages.image(named: name) {
            ZStack(alignment: .bottomLeading) {
                DriftingArtwork(image: image, name: name, date: model.selectedDate,
                                persistDailyPosition: model.selectedDate == model.today && !model.isReviewSample)
                    .id("\(model.selectedDate.iso)-\(name)")
                LinearGradient(stops: [.init(color: .clear, location: 0.2), .init(color: .black.opacity(0.85), location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Sayings of the Church Fathers").font(.system(size: 11))
                    Text(saying.text).font(Theme.reading(compact ? 15 : 18)).fixedSize(horizontal: false, vertical: true)
                    Text("\(saying.author) · \(saying.source)").font(.system(size: 12))
                }.foregroundStyle(Theme.parchment).shadow(color: .black, radius: 4).padding(18)
            }.frame(height: compact ? 235 : 270).clipShape(RoundedRectangle(cornerRadius: 20))
                .accessibilityElement(children: .combine)
        }
    }
}

/// Remembers when a day's pan began, so changing screens or reopening the app
/// cannot restart the same image after it has reached its resting position.
@MainActor private enum SayingPanTimeline {
    static var sessionStarts: [String: Date] = [:]
    private static let imageKey = "chotki.sayingPan.image"
    private static let startKey = "chotki.sayingPan.startedAt"

    static func start(date: CalendarDate, name: String, persist: Bool) -> Date {
        // A motion revision starts a fresh once-per-day pan instead of
        // inheriting a settled position from the previous animation style.
        let identity = "pan2-\(date.iso)-\(name)"
        if let existing = sessionStarts[identity] { return existing }
        let defaults = UserDefaults.standard
        if persist, defaults.string(forKey: imageKey) == identity,
           let existing = defaults.object(forKey: startKey) as? Date {
            sessionStarts[identity] = existing
            return existing
        }
        let now = Date()
        sessionStarts[identity] = now
        if persist {
            defaults.set(identity, forKey: imageKey)
            defaults.set(now, forKey: startKey)
        }
        return now
    }
}

/// A gentle reveal travels to the image's hand-reviewed subject, then holds.
struct DriftingArtwork: View {
    let image: NSImage
    let name: String
    let date: CalendarDate
    let persistDailyPosition: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Twice the earlier pace: 2 × 36s, 15% faster, then halved. `SayingPan.kt` uses the same figure.
    private let duration: TimeInterval = 2 * 36 / 1.15 / 2
    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.width / image.size.width, proxy.size.height / image.size.height) * 1.08
            let width = image.size.width * scale
            let height = image.size.height * scale
            let renderedSize = CGSize(width: width, height: height)
            let end = SayingPanFocus.restingOrigin(
                image: renderedSize, viewport: proxy.size,
                focus: SayingPanFocus.point(for: name)
            )
            let imageNumber = Int(URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent) ?? 0
            let start = SayingPanFocus.startingOrigin(
                image: renderedSize, viewport: proxy.size, resting: end, imageNumber: imageNumber
            )
            Image(nsImage: image).resizable()
                .frame(width: width, height: height)
                .position(x: start.x + (end.x - start.x) * progress + width / 2,
                          y: start.y + (end.y - start.y) * progress + height / 2)
                .onAppear {
                    let canPersist = persistDailyPosition &&
                        ProcessInfo.processInfo.environment["CHOTKI_RENDER_WINDOW"] == nil &&
                        ProcessInfo.processInfo.environment["CHOTKI_RENDER"] == nil
                    let started = SayingPanTimeline.start(date: date, name: name, persist: canPersist)
                    let elapsed = Date().timeIntervalSince(started)
                    let renderSettled = ProcessInfo.processInfo.environment["CHOTKI_RENDER_SETTLED_IMAGE"] == "1"
                    progress = (reduceMotion || renderSettled) ? 1 : min(1, max(0, elapsed / duration))
                    guard progress < 1 else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: duration * (1 - progress))) { progress = 1 }
                    }
                }
        }.clipped().accessibilityHidden(true)
    }
}
