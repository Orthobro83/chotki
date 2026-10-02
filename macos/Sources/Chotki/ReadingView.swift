import SwiftUI
import ChotkiCore

struct ReadingViewContent: View {
    @ObservedObject var model: AppModel
    /// Empty unless a reading rule asked for its section. The tab itself
    /// opens with every section closed.
    @State private var expanded: Set<Int> = []

    var body: some View {
        if let day = model.liturgical.cachedDay(for: model.selectedDate) {
            content(day)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // The hymn does not wait on the fetched day. The rest of the
                // reading does, and says so underneath.
                if let week = model.liturgical.akathistWeek(model.selectedDate) {
                    akathistSection(week)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }
                waiting
            }
        }
    }

    private func content(_ day: LiturgicalDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = day.title {
                // Never re-case text that came from the calendar. "Wednesday of
                // the 12th week after Pentecost" is how the Church writes it,
                // and lowercasing it made the app look careless.
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            TermText(model: model, text: day.summaryTitle, size: 22, serif: true, colour: Theme.gold)
                .padding(.top, 6).padding(.bottom, 10)

            if model.settings.observances.fasting.isVisible && day.isFast {
                // Reported, never prescribed: what the calendar marks, plus what
                // is customarily set aside — not an instruction to the reader.
                VStack(alignment: .leading, spacing: 3) {
                    TermText(
                        model: model,
                        text: "The calendar marks this as \(day.fastDescription).",
                        size: 13, colour: Theme.violet
                    )
                    if !day.abstentions.isEmpty {
                        Text("Customarily set aside: \(day.abstentions.joined(separator: ", ")).")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.faint)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            }

            Rectangle().fill(Theme.line).frame(height: 1)

            let held = Set(model.entries(on: model.selectedDate).compactMap { ReadingOrder.band(ofTitle: $0.rule.title) })
            ForEach(ReadingOrder.orderedBands(held: held), id: \.self) { band in
                let readings = day.readings.filter { ReadingOrder.band(source: $0.source) == band }
                if !readings.isEmpty {
                    section(ReadingOrder.sectionTitle(band: band, sources: readings.map(\.source)), band: band) {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(reading.source) · \(reading.display)").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                    Text(reading.text).font(Theme.reading(18)).foregroundStyle(Theme.parchmentDim)
                                        .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            ReadingEnd(identity: "\(model.selectedDate.iso)-\(band)") { model.finishReading(band: band) }.frame(height: 1)
                        }
                    }
                }
            }

            section(ReadingOrder.sectionTitle(band: ReadingOrder.saintLifeBand), band: ReadingOrder.saintLifeBand) {
                lifeBody(day)
            }

            if model.settings.jurisdiction.tradition.isSlavic || held.contains(ReadingOrder.departedBand) {
                section(ReadingOrder.sectionTitle(band: ReadingOrder.departedBand), band: ReadingOrder.departedBand) {
                    appointed(
                        heading: DepartedCommemoration.rubric,
                        paragraphs: DepartedCommemoration.paragraphs,
                        source: DepartedCommemoration.source,
                        sourceURL: DepartedCommemoration.sourceURL,
                        band: ReadingOrder.departedBand
                    )
                }
            }

            if let week = model.liturgical.akathistWeek(model.selectedDate) {
                akathistSection(week)
            }

            if let patristic = PatristicReadings.shared.reading(for: model.selectedDate) {
                Rectangle().fill(Theme.line).frame(height: 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text("From the Fathers")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                    Text(patristic.text)
                        .font(Theme.reading(18))
                        .foregroundStyle(Theme.parchmentDim)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(patristic.author) · \(patristic.source)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 10)
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            HStack {
                Text("\(day.paschaDistance) days since Pascha")
                if let tone = day.tone { Text("· tone \(tone)") }
                Spacer()
                Text(model.liturgical.isOffline ? "cached" : model.settings.jurisdiction.reckoning == .julian ? "old calendar" : "new calendar")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.faint)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .onAppear { applyFocus() }
        .onChange(of: model.readingRequest) { _ in applyFocus() }
        .onChange(of: model.selectedDate) { _ in applyFocus() }
    }

    private func applyFocus() {
        expanded = if let band = model.readingFocus { [band] } else { [] }
    }

    private func toggle(_ band: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expanded.contains(band) { expanded.remove(band) } else { expanded.insert(band) }
        }
    }

    private func akathistSection(_ week: Int) -> some View {
        section(ReadingOrder.sectionTitle(band: ReadingOrder.akathistBand), band: ReadingOrder.akathistBand) {
            appointed(
                heading: Akathist.heading(week: week),
                paragraphs: Akathist.paragraphs(week: week),
                source: Akathist.source,
                sourceURL: Akathist.sourceURL,
                band: ReadingOrder.akathistBand,
                note: Akathist.fallbackNote(for: model.settings.jurisdiction.tradition),
                linked: true
            )
        }
    }

    /// A reading rule's section. Closed until it is the one that was asked for.
    private func section<Content: View>(_ title: String, band: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Theme.line).frame(height: 1)
            Button { toggle(band) } label: {
                HStack(spacing: 10) {
                    Text(title).font(Theme.reading(22))
                    Spacer()
                    Image(systemName: expanded.contains(band) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }.foregroundStyle(Theme.parchment)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded.contains(band) ? "Collapse \(title)" : "Expand \(title)")
            .overlay { NativeClickRegion { toggle(band) } }
            if expanded.contains(band) { content() }
        }
        .padding(.vertical, 8)
        .id(band)
    }

    /// A text the app holds, opened and closed like the day's readings.
    private func appointed(
        heading: String, paragraphs: [String], source: String, sourceURL: String, band: Int,
        note: String? = nil, linked: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            if let note {
                TermText(model: model, text: note, size: 13, colour: Theme.muted)
            }
            if linked {
                PrayerProse(model: model, paragraphs: paragraphs, size: 18, spacing: 5)
            } else {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(Theme.reading(18))
                        .foregroundStyle(Theme.parchmentDim)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let url = URL(string: sourceURL) {
                Link(source, destination: url)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
            }
            ReadingEnd(identity: "\(model.selectedDate.iso)-\(band)") {
                model.finishReading(band: band)
            }.frame(height: 1)
        }
    }

    @ViewBuilder
    private func lifeBody(_ day: LiturgicalDay) -> some View {
        if let life = SaintLives.reading(on: day.observedDate) {
            // The page's own date line, old calendar and new calendar.
            Text(life.dates)
                .font(Theme.reading(19))
                .foregroundStyle(Theme.gold)
            if let preface = life.preface {
                Text(preface)
                    .font(Theme.reading(18))
                    .foregroundStyle(Theme.parchment)
            }
            ForEach(Array(life.sections.enumerated()), id: \.offset) { _, section in
                Text(section.heading)
                    .font(Theme.reading(18))
                    .foregroundStyle(Theme.parchment)
                ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                    blockText(block)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if let url = URL(string: life.sourceURL) {
                    Link(life.source, destination: url)
                }
                Text(life.licenseNote)
                if let url = URL(string: life.licenseURL) {
                    Link(life.license, destination: url)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
            ReadingEnd(identity: "\(model.selectedDate.iso)-saint-life") {
                model.finishReading(band: ReadingOrder.saintLifeBand)
            }.frame(height: 1)
        } else {
            if !day.saints.isEmpty {
                Text(day.saints.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            Text("No life is stored for this day.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.faint)
        }
    }

    @ViewBuilder
    private func blockText(_ block: SaintLife.Block) -> some View {
        switch block.kind {
        case "heading":
            Text(block.text ?? "")
                .font(Theme.reading(17))
                .foregroundStyle(Theme.parchmentDim)
                .fixedSize(horizontal: false, vertical: true)
        case "lines":
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array((block.rows ?? []).enumerated()), id: \.offset) { _, row in
                    prose(row)
                }
            }
        default:
            prose(block.spans ?? [])
        }
    }

    private func prose(_ spans: [SaintLife.Span]) -> some View {
        spans.reduce(Text("")) { line, span in
            var piece = Text(span.text).font(Theme.reading(18))
            if span.italic { piece = piece.italic() }
            if span.bold { piece = piece.bold() }
            return line + piece
        }
        .foregroundStyle(Theme.parchmentDim)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var waiting: some View {
        VStack(spacing: 6) {
            Text("No reading stored for this day yet.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Text("Connect to the internet to fetch the church calendar. Previously fetched readings remain available offline.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24).padding(.vertical, 40)
    }
}

/// Scroll chrome only; content is `ReadingViewContent` so the window can lay it
/// out differently and the renderer can draw it.
struct ReadingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ReadingViewContent(model: model).frame(maxWidth: 800, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading).chotkiScrollContent()
            }
            .frame(maxHeight: .infinity).scrollContentBackgroundHidden()
            .softVerticalScrollEdges()
            .onAppear { if let band = model.readingFocus { proxy.scrollTo(band, anchor: .top) } }
            .onChange(of: model.readingRequest) { _ in
                if let band = model.readingFocus { withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(band, anchor: .top) } }
            }
        }
    }
}
