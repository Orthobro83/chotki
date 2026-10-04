import SwiftUI
import ChotkiCore

/// The day's rules as a row of cards that glides.
///
/// The circle is the only thing that marks one kept. Tapping the card opens
/// the prayers, the reading, or the rope. A fast has nothing to open: the
/// card turns over. A long press edits.
struct Commitments: View {
    @Bindable var model: Model
    var openLibrary: () -> Void
    @Environment(\.goToPlace) private var goToPlace
    @Environment(\.pushRoute) private var pushRoute
    @Environment(\.openTerm) private var openTerm

    private var entries: [DayEntry] { model.entries(on: model.selectedDate) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(entries, id: \.id) { entry in
                    CommitmentCard(
                        model: model,
                        entry: entry,
                        openLibrary: openLibrary,
                        go: goToPlace,
                        push: pushRoute,
                        openTerm: openTerm
                    )
                }
                AddCard(open: openLibrary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .accessibilityIdentifier("commitments")
    }
}

private struct CommitmentCard: View {
    @Bindable var model: Model
    let entry: DayEntry
    var openLibrary: () -> Void
    var go: GoToPlace
    var push: PushRoute
    var openTerm: OpenTerm
    @State private var flipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fasting: Bool { entry.rule.isFastingRule }
    private var glossary: Glossary {
        Glossary.shared(for: model.settings.jurisdiction.tradition)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                face(back: false)
                    .opacity(flipped ? 0 : 1)
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (0, 1, 0))
                face(back: true)
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (0, 1, 0))
            }
            .onTapGesture { open() }
            .contextMenu { menu }

            if !flipped {
                Mark(title: entry.rule.title, on: entry.showsAsSatisfied, enabled: !entry.isDispensed) {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                        model.toggleKept(entry)
                    }
                }
                .padding(.top, 6)
                .padding(.trailing, 6)
            }
        }
        .frame(width: 116, height: 226)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.42), value: flipped)
    }

    private func face(back: Bool) -> some View {
        let rule = entry.rule
        let blurb = back ? (glossary.entry(slug: rule.glossarySlug ?? "")?.short ?? cardBlurb(rule)) : cardBlurb(rule)
        return VStack(alignment: .leading, spacing: 8) {
            CommitmentGlyph(category: rule.category)
            Text(cardLabel(rule))
                .font(.system(size: 11))
                .foregroundStyle(Chotki.inkFaint)
            Text(rule.title)
                .font(Chotki.reading(17))
                .fontWeight(.medium)
                .foregroundStyle(Chotki.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            if !back, entry.rule.givenByPriest == true {
                Text(model.settings.givenByPriestPhrase ?? "GIVEN BY A PRIEST")
                    .font(.system(size: 9))
                    .foregroundStyle(Chotki.goldDim)
            }
            Text(blurb)
                .font(Chotki.reading(12.5))
                .foregroundStyle(Chotki.inkBlurb)
                .lineLimit(back ? 6 : 4)
            Spacer(minLength: 0)
            if back, rule.glossarySlug != nil {
                Button {
                    if let slug = rule.glossarySlug { openTerm(slug) }
                } label: {
                    Text("Tap to learn more")
                        .font(.system(size: 12.5))
                        .underline()
                        .foregroundStyle(Chotki.goldDim)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tap to learn more")
            }
            if let dispensation = entry.dispensation, !back {
                Text("Not observed during \(dispensation)")
                    .font(.system(size: 11))
                    .foregroundStyle(Chotki.goldDim)
            } else if entry.isStoodDown, !back {
                Text("Stood down")
                    .font(.system(size: 11))
                    .foregroundStyle(Chotki.inkFaint)
            }
            if !back {
                Text(rule.timeOfDay.map { Format.time($0, model.settings.clockStyle) } ?? "All day")
                    .font(.system(size: 12))
                    .foregroundStyle(Chotki.inkFaint)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: 116, height: 226, alignment: .topLeading)
        .background(Chotki.parchment, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rule.title)
    }

    private func open() {
        if fasting {
            flipped.toggle()
            return
        }
        let rule = entry.rule
        if let id = rule.ropePrayerID ?? rule.sequenceID {
            model.prayers.choose(id)
            go(.prayers)
            return
        }
        switch rule.reference {
        case .reading:
            model.openReading(band: ReadingOrder.band(ofTitle: rule.title))
            go(.reading)
        case .psalter:
            push(.psalter)
        case .prayers:
            push(.prayers(ruleID: rule.id))
        case .rope, .none:
            break
        }
    }

    @ViewBuilder private var menu: some View {
        if entry.isDispensed {
            Text("Lifted by the Church today")
        } else {
            switch entry.rule.reference {
            case .rope:
                Button("Go to the rope") {
                    model.prayers.choose(entry.rule.ropePrayerID)
                    go(.prayers)
                }
                Divider()
            case .prayers:
                Button("Read the prayers") {
                    if let sequence = entry.rule.sequenceID {
                        model.prayers.choose(sequence)
                        go(.prayers)
                    } else {
                        push(.prayers(ruleID: entry.rule.id))
                    }
                }
                Divider()
            case .reading:
                Button("Read the day’s readings") {
                    model.openReading(band: ReadingOrder.band(ofTitle: entry.rule.title))
                    go(.reading)
                }
                Divider()
            case .psalter:
                Button("Read today’s kathisma") { push(.psalter) }
                Divider()
            case .none:
                EmptyView()
            }
            Button(entry.isKept ? "Clear this day" : "Mark as kept") {
                model.toggleKept(entry)
            }
            if !entry.isKept {
                Button("Mark as kept, late") { model.markKeptLate(entry) }
            }
            Button("Stand down for this day") { model.standDownForTheDay(entry) }
        }
        Divider()
        Button("Edit rule…") { push(.editor(ruleID: entry.rule.id, startingFrom: nil)) }
        if model.isPaused(entry.rule) {
            Button("Resume this rule") { model.resume(entry.rule) }
        } else {
            Button("Pause this rule") { model.pause(entry.rule) }
        }
        if let slug = entry.rule.glossarySlug {
            Button("About this rule") { openTerm(slug) }
        }
    }
}

private struct Mark: View {
    var title: String
    var on: Bool
    var enabled: Bool
    var toggle: () -> Void

    var body: some View {
        Button(action: { if enabled { toggle() } }) {
            ZStack {
                Circle()
                    .fill(on ? Chotki.gold : Color.clear)
                    .overlay(Circle().stroke(on ? Chotki.gold : Chotki.goldDim, lineWidth: 1.5))
                    .frame(width: 22, height: 22)
                if on {
                    Check().stroke(Chotki.ground, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .frame(width: 12, height: 12)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(enabled ? "Mark \(title) kept" : (on ? "\(title) kept" : "\(title) not yet kept"))
    }
}

private struct Check: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.76))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.24))
        return path
    }
}

private struct AddCard: View {
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            Text("+ Add")
                .font(.system(size: 13))
                .foregroundStyle(Chotki.gold)
                .frame(width: 116, height: 226)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(red: 0.227, green: 0.204, blue: 0.141), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a commitment")
    }
}

private struct CommitmentGlyph: View {
    var category: String?

    var body: some View {
        let kind = category.flatMap(RuleCategory.init(rawValue:))
        let tint = kind == .fasting ? Color(red: 0.361, green: 0.325, blue: 0.502) : Chotki.goldDim
        Canvas { context, size in
            let width = size.width * (1.3 / 18)
            switch kind {
            case .prayer:
                Marks.rope(context, size, tint, size.width * 0.085)
            case .reading:
                Marks.openBook(context, size, tint, width)
            case .services:
                serviceCross(context, size, tint)
            case .fasting, .life, .none:
                Marks.closedBook(context, size, tint, width)
            }
        }
        .frame(width: 18, height: 18)
    }

    private func serviceCross(_ context: GraphicsContext, _ size: CGSize, _ tint: Color) {
        let s = size.width / 18
        context.fill(Path(CGRect(x: 8.2 * s, y: 2 * s, width: 1.6 * s, height: 13 * s)), with: .color(tint))
        context.fill(Path(CGRect(x: 5 * s, y: 4.2 * s, width: 8 * s, height: 1.5 * s)), with: .color(tint))
        context.fill(Path(CGRect(x: 6.2 * s, y: 7 * s, width: 5.6 * s, height: 1.3 * s)), with: .color(tint))
    }
}

private func cardLabel(_ rule: Rule) -> String {
    switch rule.category.flatMap(RuleCategory.init(rawValue:)) {
    case .prayer: return "prayer"
    case .fasting: return "fasting"
    case .services: return "services"
    case .reading: return "reading"
    case .life: return "life"
    case .none: return "custom"
    }
}

private func cardBlurb(_ rule: Rule) -> String {
    if let curated = RuleLibrary.shared.templates.first(where: {
        $0.title.compare(rule.title, options: .caseInsensitive) == .orderedSame
    })?.summary, !curated.isEmpty {
        return curated
    }
    return rule.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}
