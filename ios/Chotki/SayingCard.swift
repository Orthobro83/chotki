import SwiftUI
import ChotkiCore

/// The saying for this civil day, on that day's picture.
///
/// The picture is drawn a little larger than the card and eases onto its
/// subject. Today's drift is remembered, so leaving Home and coming back does
/// not play it again. With reduced motion, the picture is shown at rest.
struct SayingCard: View {
    var date: CalendarDate
    var persistMotion: Bool

    /// The picture is never more than a third of the screen's height, so a short phone keeps most of
    /// its day; on every current iPhone 220 points is the smaller of the two.
    static var height: CGFloat { min(220, UIScreen.main.bounds.height / 3) }

    private var saying: PatristicReading? { PatristicReadings.shared.reading(for: date) }

    var body: some View {
        if let saying, let name = SayingImages.name(for: date), let image = SayingImages.image(named: name) {
            DriftingArtwork(image: image, name: name, date: date, persist: persistMotion)
                // Decoration, not a control. The picture is drawn larger than the card and
                // slid into place, and its touch area is that larger size: for some days'
                // pictures it reached up over the calendar and swallowed taps meant for the
                // chevron under the month. Nothing here is tapped, so nothing here takes touches.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .frame(height: SayingCard.height)
                .overlay(alignment: .bottomLeading) {
                    // On the picture, as low as it can sit: the bar is the next thing down.
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sayings of the church fathers")
                            .font(.system(size: 11))
                        Text(saying.text)
                            .font(Chotki.reading(15))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(saying.author) · \(saying.source)")
                            .font(.system(size: 12))
                            .foregroundStyle(Chotki.parchmentDim)
                    }
                    .foregroundStyle(Chotki.parchment)
                    .shadow(color: .black, radius: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // Decoration: touches go through it to the day beneath.
                .allowsHitTesting(false)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }
}

@MainActor enum SayingImages {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 3
        return cache
    }()

    static let names: [String] = {
        guard let url = Bundle.main.url(forResource: "order", withExtension: "txt", subdirectory: "sayings"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }()

    static let focus: [Int: CGPoint] = {
        guard let url = Bundle.main.url(forResource: "approved-sources", withExtension: "json", subdirectory: "sayings"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([ApprovedFocus].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.number, CGPoint(x: $0.focusX, y: $0.focusY)) })
    }()

    static func name(for date: CalendarDate) -> String? {
        guard !names.isEmpty, let first = CalendarDate(year: date.year, month: 1, day: 1) else { return nil }
        let index = (first.days(until: date) + 1) % names.count
        return names[index < 0 ? index + names.count : index]
    }

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        let file = name.hasPrefix("sayings/") ? String(name.dropFirst("sayings/".count)) : name
        let base = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext, subdirectory: "sayings"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    private struct ApprovedFocus: Decodable {
        let number: Int
        let focusX: Double
        let focusY: Double
    }
}

private struct DriftingArtwork: View {
    var image: UIImage
    var name: String
    var date: CalendarDate
    var persist: Bool
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The same pace Android and the Mac use: 2 × 36s, 15% faster, then halved.
    private var duration: TimeInterval { 2 * 36 / 1.15 / 2 }

    var body: some View {
        GeometryReader { proxy in
            let pixel = image.size
            let scale = max(proxy.size.width / max(pixel.width, 1), proxy.size.height / max(pixel.height, 1)) * 1.08
            let rendered = CGSize(width: pixel.width * scale, height: pixel.height * scale)
            let number = Int(URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent) ?? 0
            let focus = SayingImages.focus[number] ?? CGPoint(x: 0.5, y: 0.45)
            let end = resting(image: rendered, viewport: proxy.size, focus: focus)
            let start = starting(image: rendered, viewport: proxy.size, resting: end, imageNumber: number)
            let origin = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rendered.width, height: rendered.height)
                    .offset(x: origin.x, y: origin.y)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: Color(red: 0.082, green: 0.086, blue: 0.110).opacity(0.90), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .clipped()
        .onAppear { begin() }
    }

    private func begin() {
        let started = SayingPanTimeline.start(date: date, name: name, persist: persist)
        let elapsed = Date().timeIntervalSince(started)
        let fraction = min(1, max(0, elapsed / duration))
        if reduceMotion || fraction >= 1 {
            progress = 1
            return
        }
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) { progress = fraction }
        withAnimation(.easeInOut(duration: duration * (1 - fraction))) { progress = 1 }
    }

    private func resting(image: CGSize, viewport: CGSize, focus: CGPoint) -> CGPoint {
        CGPoint(
            x: min(0, max(viewport.width - image.width, viewport.width * 0.5 - focus.x * image.width)),
            y: min(0, max(viewport.height - image.height, viewport.height * 0.4 - focus.y * image.height))
        )
    }

    private func starting(image: CGSize, viewport: CGSize, resting: CGPoint, imageNumber: Int) -> CGPoint {
        func nearby(_ end: CGFloat, lower: CGFloat, upper: CGFloat, travel: CGFloat, sign: CGFloat) -> CGFloat {
            let preferred = sign > 0 ? upper - end : end - lower
            let opposite = sign > 0 ? end - lower : upper - end
            let direction = preferred >= min(travel, opposite) ? sign : -sign
            return min(upper, max(lower, end + direction * travel))
        }
        return CGPoint(
            x: nearby(resting.x, lower: viewport.width - image.width, upper: 0, travel: 14,
                      sign: imageNumber.isMultiple(of: 2) ? 1 : -1),
            y: nearby(resting.y, lower: viewport.height - image.height, upper: 0, travel: 18,
                      sign: imageNumber.isMultiple(of: 3) ? 1 : -1)
        )
    }
}

@MainActor private enum SayingPanTimeline {
    static var sessionStarts: [String: Date] = [:]
    private static let imageKey = "chotki.sayingPan.image"
    private static let startKey = "chotki.sayingPan.startedAt"

    static func start(date: CalendarDate, name: String, persist: Bool) -> Date {
        let identity = "pan3-\(date.iso)-\(name)"
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
