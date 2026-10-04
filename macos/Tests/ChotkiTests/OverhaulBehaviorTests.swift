import Foundation
import AppKit
import SwiftUI
import Testing
@testable import Chotki
@testable import ChotkiCore

@Suite("macOS overhaul behavior")
@MainActor
struct OverhaulBehaviorTests {
    private actor RecordingNotifier: Notifier {
        nonisolated let supportsActions = false
        nonisolated var actionEvents: AsyncStream<NotificationActionEvent> { AsyncStream { $0.finish() } }
        private(set) var shown: [NotificationRequest] = []
        func requestAuthorization() async throws -> Bool { true }
        func show(_ request: NotificationRequest) async throws { shown.append(request) }
        func cancel(ids: [String]) async {}
    }
    private struct QuietNotifier: Notifier {
        let supportsActions = false
        func requestAuthorization() async throws -> Bool { false }
        func show(_ request: NotificationRequest) async throws {}
        func cancel(ids: [String]) async {}
        var actionEvents: AsyncStream<NotificationActionEvent> { AsyncStream { $0.finish() } }
    }
    private struct QuietLogin: LaunchAtLogin {
        let isEnabled = false
        func setEnabled(_ enabled: Bool) throws {}
    }
    private func model(store: InMemoryStore) -> AppModel {
        AppModel(store: store, notifier: QuietNotifier(), launchAtLogin: QuietLogin(),
                 storage: .none(), startsReminders: false, writesBackups: false, loadsCalendar: false)
    }

    @Test("card activation opens its prayer or reading destination on the first click")
    func cardDestinations() throws {
        let app = model(store: InMemoryStore())
        let date = CalendarDate(year: 2026, month: 10, day: 1)!
        func open(_ templateID: String) throws {
            let template = try #require(RuleLibrary.shared.templates.first { $0.id == templateID })
            let entry = DayEntry(rule: template.makeRule(source: "the library"), date: date,
                                 occurrence: nil, dispensation: nil)
            EntryRow(model: app, entry: entry).open()
        }
        try open("morning-prayers")
        #expect(app.prayers.selection == "morning")
        #expect(app.screen == .prayerRope)
        #expect(WindowRoute.route(for: app.screen) == .section(.prayers))

        try open("jesus-prayer")
        #expect(app.prayers.selection == "jesus-prayer")
        #expect(app.prayers.showsRope())
        #expect(WindowRoute.route(for: app.screen) == .section(.prayers))

        try open("lives-of-saints")
        #expect(app.tab == .reading)
        #expect(app.screen == .main)
        #expect(app.readingFocus == ReadingOrder.saintLifeBand)
        let october = try #require(SaintLives.reading(on: date))
        #expect(october.dates == "October 1 / October 14")
        #expect(october.license == "CC BY-SA 4.0")
        let september = try #require(SaintLives.reading(on: date.adding(days: -13)))
        #expect(september.month == 9 && september.day == 18)
        #expect(september.dates == "September 18 / October 1")
    }

    @Test("a long saint-life title uses a smaller card face")
    func longCardTitle() throws {
        let app = model(store: InMemoryStore())
        let template = try #require(RuleLibrary.shared.templates.first { $0.id == "lives-of-saints" })
        let date = CalendarDate(year: 2026, month: 10, day: 1)!
        let entry = DayEntry(rule: template.makeRule(source: "the library"), date: date,
                             occurrence: nil, dispensation: nil)
        #expect(EntryRow(model: app, entry: entry).compactTitleSize < 18)
    }

    @Test("the native card surface gives clicks and right-clicks distinct actions")
    func nativeCardSurface() throws {
        let app = model(store: InMemoryStore())
        let template = try #require(RuleLibrary.shared.templates.first { $0.id == "morning-prayers" })
        let date = CalendarDate(year: 2026, month: 10, day: 1)!
        let entry = DayEntry(rule: template.makeRule(source: "the library"), date: date,
                             occurrence: nil, dispensation: nil)
        let card = EntryRow(model: app, entry: entry)
        let titles = card.menuActions.map(\.title)
        #expect(titles.contains("Read the Prayers"))
        #expect(titles.contains("Mark as Kept"))
        #expect(titles.contains("Mark as Kept, Late"))
        #expect(titles.contains("Stand Down for This Day"))
        #expect(titles.contains("Edit Rule…"))
        #expect(titles.contains("Pause This Rule") || titles.contains("Resume This Rule"))

        let surface = RuleCardInteraction.Surface(frame: CGRect(x: 0, y: 0, width: 132, height: 232))
        surface.showsCompletion = true
        surface.showsExpansion = true
        surface.menuActions = card.menuActions
        #expect(surface.hit(at: CGPoint(x: 30, y: 120)) == .open)
        #expect(surface.hit(at: CGPoint(x: 110, y: 211)) == .completion)
        #expect(surface.hit(at: CGPoint(x: 110, y: 18)) == .expansion)
        #expect(surface.makeMenu().items.map(\.title).contains("Edit Rule…"))
        surface.open = { card.open() }
        let window = NSWindow(contentRect: surface.frame, styleMask: [], backing: .buffered, defer: false)
        window.contentView = surface
        let click = try #require(NSEvent.mouseEvent(with: .leftMouseUp,
            location: CGPoint(x: 30, y: 120), modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 1,
            clickCount: 1, pressure: 1))
        surface.mouseUp(with: click)
        #expect(app.prayers.selection == "morning")
        #expect(app.screen == .prayerRope)

        let host = NSHostingView(rootView: EntryRow(model: app, entry: entry))
        host.frame = CGRect(x: 0, y: 0, width: 132, height: 232)
        let hostedWindow = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        hostedWindow.contentView = host
        host.layoutSubtreeIfNeeded()
        let hostedSurface = try #require(host.hitTest(CGPoint(x: 30, y: 120)) as? RuleCardInteraction.Surface)
        var presentedMenuTitles: [String] = []
        hostedSurface.menuPresenter = { menu, _ in presentedMenuTitles = menu.items.map(\.title) }
        hostedWindow.setFrameOrigin(CGPoint(x: -5000, y: -5000))
        hostedWindow.orderFront(nil)
        app.screen = .main
        let hostedDown = try #require(NSEvent.mouseEvent(with: .leftMouseDown,
            location: CGPoint(x: 30, y: 120), modifierFlags: [], timestamp: 0,
            windowNumber: hostedWindow.windowNumber, context: nil, eventNumber: 2,
            clickCount: 1, pressure: 1))
        let hostedClick = try #require(NSEvent.mouseEvent(with: .leftMouseUp,
            location: CGPoint(x: 30, y: 120), modifierFlags: [], timestamp: 0,
            windowNumber: hostedWindow.windowNumber, context: nil, eventNumber: 3,
            clickCount: 1, pressure: 1))
        hostedWindow.sendEvent(hostedDown)
        hostedWindow.sendEvent(hostedClick)
        #expect(app.screen == .prayerRope)
        let hostedRightClick = try #require(NSEvent.mouseEvent(with: .rightMouseDown,
            location: CGPoint(x: 30, y: 120), modifierFlags: [], timestamp: 0,
            windowNumber: hostedWindow.windowNumber, context: nil, eventNumber: 4,
            clickCount: 1, pressure: 1))
        hostedWindow.sendEvent(hostedRightClick)
        #expect(presentedMenuTitles.contains("Mark as Kept"))
        #expect(presentedMenuTitles.contains("Edit Rule…"))
    }


    @Test("the approved 365-image rotation is packaged with a focal point for each image")
    func packagedRotation() {
        #expect(SayingImages.names.count == 365)
        #expect(Set(SayingImages.names).count == 365)
        #expect(Set(SayingPanFocus.points.keys) == Set(1...42))
        #expect(Set(SayingPanFocus.approvedPoints.keys) == Set(43...365))
        #expect(SayingPanFocus.points.values.allSatisfy {
            (0...1).contains($0.x) && (0...1).contains($0.y)
        })
        #expect(SayingPanFocus.approvedPoints.values.allSatisfy {
            (0...1).contains($0.x) && (0...1).contains($0.y)
        })
        let first = CalendarDate(year: 2026, month: 1, day: 1)!
        let chosen = (0..<365).compactMap { SayingImages.name(for: first.adding(days: $0)) }
        #expect(Set(chosen).count == 365)
        for name in SayingImages.names { #expect(SayingImages.image(named: name) != nil, "Missing \(name)") }
    }

    @Test("a tall portrait rests on its face rather than at the image's top edge")
    func portraitPanFocus() throws {
        let image = try #require(SayingImages.image(named: "sayings/22.jpg"))
        let viewport = CGSize(width: 850, height: 270)
        let scale = max(viewport.width / image.size.width,
                        viewport.height / image.size.height) * 1.08
        let scaled = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let focus = SayingPanFocus.point(for: "sayings/22.jpg")
        let resting = SayingPanFocus.restingOrigin(image: scaled, viewport: viewport, focus: focus)
        #expect(resting.y < -20)
        #expect(abs(resting.y + focus.y * scaled.height - viewport.height * 0.4) < 1)
    }

    @Test("every rotation image drifts gently at desktop and companion sizes")
    func everyImagePans() throws {
        for viewport in [CGSize(width: 850, height: 270), CGSize(width: 370, height: 235)] {
            for number in 1...42 {
                let name = try #require(SayingImages.names.first {
                    Int(URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent) == number
                })
                let image = try #require(SayingImages.image(named: name))
                let scale = max(viewport.width / image.size.width,
                                viewport.height / image.size.height) * 1.08
                let rendered = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                let end = SayingPanFocus.restingOrigin(image: rendered, viewport: viewport,
                                                        focus: SayingPanFocus.point(for: name))
                let start = SayingPanFocus.startingOrigin(image: rendered, viewport: viewport,
                                                          resting: end, imageNumber: number)
                let distance = hypot(Double(start.x - end.x), Double(start.y - end.y))
                #expect(distance >= 10 && distance <= 23, "Motion outside subtle range for \(name)")
                #expect(start.x <= 0 && start.x >= viewport.width - rendered.width)
                #expect(start.y <= 0 && start.y >= viewport.height - rendered.height)
            }
        }
    }

    @Test("clearing a spiritual father freezes old rule attribution, including archived rules")
    func clearFatherKeepsHistory() throws {
        let store = InMemoryStore()
        var settings = AppSettings.default
        settings.spiritualFatherName = "Father Seraphim"
        try store.saveSettings(settings)
        let missingSource = Rule(title: "Prayer", recurrence: .daily, givenByPriest: true)
        var older = Rule(title: "Reading", source: "the library", recurrence: .daily,
                         givenByPriest: true)
        older.archivedAt = Date()
        let alreadyRecorded = Rule(title: "Almsgiving", source: "Father Ambrose",
                                   recurrence: .daily, givenByPriest: true)
        for rule in [missingSource, older, alreadyRecorded] { try store.save(rule) }
        let app = model(store: store)

        app.clearSpiritualFatherName()

        #expect(app.settings.spiritualFatherName.isEmpty)
        #expect(try store.rule(id: missingSource.id)?.source == "Father Seraphim")
        #expect(try store.rule(id: older.id)?.source == "Father Seraphim")
        #expect(try store.rule(id: alreadyRecorded.id)?.source == "Father Ambrose")
        app.update { $0.spiritualFatherName = "Father Nicholas" }
        let historical = try #require(try store.rule(id: missingSource.id))
        #expect(historical.suggestedByLabel(currentFather: app.settings.spiritualFatherName) ==
                "Suggested by Father Seraphim")
    }

    @Test("typing over the Settings name records the original, not a partial edit")
    func editingFatherKeepsOriginal() throws {
        let store = InMemoryStore()
        var settings = AppSettings.default
        settings.spiritualFatherName = "Father Seraphim"
        try store.saveSettings(settings)
        let rule = Rule(title: "Prayer", recurrence: .daily, givenByPriest: true)
        try store.save(rule)
        let app = model(store: store)

        app.update { $0.spiritualFatherName = "Father Seraphi" }
        app.update { $0.spiritualFatherName = "" }

        #expect(try store.rule(id: rule.id)?.source == "Father Seraphim")
        #expect(app.settings.spiritualFatherName.isEmpty)
    }

    @Test("two tasks can pulse separate sections for exactly five seconds")
    func simultaneousAttention() throws {
        let store = InMemoryStore()
        let date = CalendarDate(Date(), in: .current)
        let prayer = Rule(title: "Morning prayers", recurrence: .daily,
                          timeOfDay: TimeOfDay(hour: 6, minute: 30),
                          prayerIDs: PrayerSequence.all.first(where: { $0.id == "morning" })?.prayerIDs)
        let reading = Rule(title: "Read the day's Gospel", recurrence: .daily,
                           timeOfDay: TimeOfDay(hour: 6, minute: 30), category: RuleCategory.reading.rawValue)
        for rule in [prayer, reading] { try store.save(rule); try store.save(Activation(ruleID: rule.id, from: date)) }
        let app = model(store: store)
        let plan = Scheduler(timeZone: .current, includesDueAlert: true)
            .plan(rules: app.rules, activations: app.activations, occurrences: [], on: date)
        let now = Date()
        for notification in plan where notification.id.hasSuffix("lead0") { app.attend(to: notification, now: now) }
        #expect(app.attentionUntil[.prayers] == now.addingTimeInterval(5))
        #expect(app.attentionUntil[.reading] == now.addingTimeInterval(5))
        #expect(app.attentionUntil[.home] == nil)
    }

    @Test("only the isolated review app can request a sample due alert")
    func reviewAlert() async throws {
        let store = InMemoryStore()
        let date = CalendarDate(Date(), in: .current)
        let morning = try #require(RuleLibrary.shared.templates.first { $0.id == "morning-prayers" })
            .makeRule(source: "the library")
        try store.save(morning)
        try store.save(Activation(ruleID: morning.id, from: date))
        let notifier = RecordingNotifier()
        let app = AppModel(
            store: store, notifier: notifier, launchAtLogin: QuietLogin(),
            storage: .none(), startsReminders: false, writesBackups: false,
            loadsCalendar: false, isReviewSample: true
        )
        app.previewDueAlert()
        let remaining = try #require(app.attentionUntil[.prayers]).timeIntervalSinceNow
        #expect(remaining > 0 && remaining <= 5)
        for _ in 0..<50 {
            if await notifier.shown.count == 1 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let sent = await notifier.shown
        #expect(sent.count == 1)
        #expect(sent.first?.actions.isEmpty == true)

        let ordinary = model(store: store)
        ordinary.previewDueAlert()
        #expect(ordinary.attentionUntil.isEmpty)
    }
}
