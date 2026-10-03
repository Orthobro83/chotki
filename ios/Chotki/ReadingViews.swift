import SwiftUI
import ChotkiCore

/// The day's reading: what the calendar marks, the appointed scripture, and a
/// passage from the fathers.
///
/// Reports what the church calendar says and names who to ask. It never tells
/// anyone what they must do, and never gives dietary instruction.
struct ReadingView: View {
    @Bindable var model: Model
    @Environment(\.pushRoute) private var pushRoute
    @State private var expanded: Set<Int> = []

    private var day: LiturgicalDay? { model.liturgicalDay(model.selectedDate) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let day {
                        stored(day)
                    } else {
                        if let week = model.liturgical.akathistWeek(model.selectedDate) {
                            akathistSection(week)
                        }
                        missing
                    }
                }
                // Without an explicit full width the column takes the width of its
                // widest line, which on a day whose commemoration is short left the
                // text in a narrow band with the ground either side of it.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
            GlossaryOfTerms { pushRoute(.term(slug: nil)) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Chotki.ground)
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        // Asks again when the day being looked at moves outside what was
        // fetched, and on first appearance. Cheap: the service only writes days
        // it did not already hold.
        .task(id: model.selectedDate) {
            if model.liturgicalDay(model.selectedDate) == nil {
                await model.refreshCalendar(around: model.selectedDate)
            }
        }
        .onAppear { applyFocus() }
        .onChange(of: model.readingRequest) { _, _ in applyFocus() }
        .onChange(of: model.selectedDate) { _, _ in applyFocus() }
    }

    private func applyFocus() {
        expanded = if let band = model.readingFocus { [band] } else { [] }
    }

    private func toggle(_ band: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expanded.contains(band) { expanded.remove(band) } else { expanded.insert(band) }
        }
    }

    @ViewBuilder
    private func stored(_ day: LiturgicalDay) -> some View {
        if !day.summaryTitle.isEmpty {
            TermText(model: model, text: day.summaryTitle, size: 13, colour: Chotki.muted)
        }
        // Never re-cased: orthocal's words are shown as it writes them.
        if let title = day.title {
            TermText(model: model, text: title, size: 20, colour: Chotki.gold)
        }
        if day.isFast {
            TermText(
                model: model,
                text: "The calendar marks this as \(day.fastLevelDescription).",
                size: 13, colour: Chotki.goldDim
            )
            if !day.abstentions.isEmpty {
                TermText(
                    model: model,
                    text: "Customarily set aside: \(day.abstentions.joined(separator: ", ")).",
                    size: 13, colour: Chotki.faint
                )
            }
        }

        let held = Set(model.entries(on: model.selectedDate).compactMap { ReadingOrder.band(ofTitle: $0.rule.title) })
        ForEach(ReadingOrder.orderedBands(held: held), id: \.self) { band in
            let readings = day.readings.filter { ReadingOrder.band(source: $0.source) == band }
            if !readings.isEmpty {
                disclosure(ReadingOrder.sectionTitle(band: band, sources: readings.map(\.source)), band: band) {
                    ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
                        Text("\(reading.source) · \(reading.display)")
                            .font(Chotki.reading(13)).foregroundStyle(Chotki.gold)
                        // Scripture is left unlinked on purpose: linking every
                        // term inside a whole chapter turns a passage into a
                        // field of references.
                        Text(reading.text)
                            .font(Chotki.reading(17)).foregroundStyle(Chotki.parchment)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    readingEnd(band: band)
                }
            }
        }

        disclosure(ReadingOrder.sectionTitle(band: ReadingOrder.saintLifeBand), band: ReadingOrder.saintLifeBand) {
            lifeBody(day)
        }

        if model.settings.jurisdiction.tradition.isSlavic || held.contains(ReadingOrder.departedBand) {
            disclosure(ReadingOrder.sectionTitle(band: ReadingOrder.departedBand), band: ReadingOrder.departedBand) {
                appointed(DepartedCommemoration.rubric, DepartedCommemoration.paragraphs, DepartedCommemoration.source)
                readingEnd(band: ReadingOrder.departedBand)
            }
        }

        if let week = model.liturgical.akathistWeek(model.selectedDate) {
            akathistSection(week)
        }

        if let patristic = PatristicReadings.shared.reading(for: model.selectedDate) {
            Divider().overlay(Chotki.line)
            Text("From the fathers").font(Chotki.reading(13)).foregroundStyle(Chotki.gold)
            Text(patristic.text)
                .font(Chotki.reading(17)).foregroundStyle(Chotki.parchment)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(patristic.author) · \(patristic.source)")
                .font(.system(size: 11)).foregroundStyle(Chotki.faint)
        }

        Divider().overlay(Chotki.line)
        HStack(spacing: 6) {
            Text("\(day.paschaDistance) days since Pascha")
            if let tone = day.tone { Text("· tone \(tone)") }
            Spacer()
            Text(model.settings.jurisdiction.reckoning.displayName)
        }
        .font(Chotki.reading(13)).foregroundStyle(Chotki.faint)
    }

    private func appointed(
        _ heading: String, _ paragraphs: [String], _ source: String,
        note: String? = nil, linked: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading).font(.footnote).foregroundStyle(Chotki.muted)
            if let note {
                TermText(model: model, text: note, size: 13, colour: Chotki.muted)
            }
            if linked {
                PrayerProse(model: model, paragraphs: paragraphs, size: 17, spacing: 4)
            } else {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(Chotki.reading(17)).foregroundStyle(Chotki.parchment)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(source).font(.system(size: 11)).foregroundStyle(Chotki.faint)
        }
    }

    private func disclosure<Content: View>(_ title: String, band: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(Chotki.line)
            Button { toggle(band) } label: {
                HStack {
                    Text(title).font(Chotki.reading(19))
                    Spacer()
                    Image(systemName: expanded.contains(band) ? "chevron.up" : "chevron.down")
                }.foregroundStyle(Chotki.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded.contains(band) ? "Collapse \(title)" : "Expand \(title)")
            if expanded.contains(band) { content() }
        }
    }

    @ViewBuilder
    private func lifeBody(_ day: LiturgicalDay) -> some View {
        if let life = SaintLives.reading(on: day.observedDate) {
            Text(life.dates).font(Chotki.reading(18)).foregroundStyle(Chotki.parchment)
            if let preface = life.preface {
                Text(preface).font(Chotki.reading(17)).foregroundStyle(Chotki.parchment)
            }
            ForEach(Array(life.sections.enumerated()), id: \.offset) { _, section in
                Text(section.heading).font(Chotki.reading(17)).foregroundStyle(Chotki.parchment)
                ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                    blockText(block)
                }
            }
            if let url = URL(string: life.sourceURL) {
                Link(life.source, destination: url).font(.system(size: 11)).foregroundStyle(Chotki.faint)
            }
            Text(life.licenseNote).font(.system(size: 11)).foregroundStyle(Chotki.faint)
            if let url = URL(string: life.licenseURL) {
                Link(life.license, destination: url).font(.system(size: 11)).foregroundStyle(Chotki.faint)
            }
            readingEnd(band: ReadingOrder.saintLifeBand)
        } else {
            if !day.saints.isEmpty {
                Text(day.saints.joined(separator: " · ")).font(.footnote).foregroundStyle(Chotki.muted)
            }
            Text("No life is stored for this day.")
                .font(.footnote).foregroundStyle(Chotki.faint)
        }
    }

    @ViewBuilder
    private func blockText(_ block: SaintLife.Block) -> some View {
        switch block.kind {
        case "heading":
            Text(block.text ?? "")
                .font(Chotki.reading(16))
                .foregroundStyle(Chotki.parchment)
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
            var piece = Text(span.text).font(Chotki.reading(17))
            if span.italic { piece = piece.italic() }
            if span.bold { piece = piece.bold() }
            return line + piece
        }
        .foregroundStyle(Chotki.parchment)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func akathistSection(_ week: Int) -> some View {
        disclosure(ReadingOrder.sectionTitle(band: ReadingOrder.akathistBand), band: ReadingOrder.akathistBand) {
            appointed(
                Akathist.heading(week: week),
                Akathist.paragraphs(week: week),
                Akathist.source,
                note: Akathist.fallbackNote(for: model.settings.jurisdiction.tradition),
                linked: true
            )
            readingEnd(band: ReadingOrder.akathistBand)
        }
    }

    private func readingEnd(band: Int) -> some View {
        ReadingEnd(identity: "\(model.selectedDate.iso)-\(band)") {
            model.finishReading(band: band)
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }

    /// Nothing stored for the day, and a way to ask again.
    ///
    /// The screen used to say only that it would fill in when it could, which
    /// is indistinguishable from a slow network — and here it was neither: iOS
    /// never asked at all. Saying what is happening, and offering the fetch, is
    /// what makes the difference visible.
    private var missing: some View {
        VStack(spacing: 10) {
            if model.isFetchingCalendar {
                ProgressView().tint(Chotki.gold)
                Text("Asking the church calendar…")
                    .font(.footnote).foregroundStyle(Chotki.muted)
            } else {
                Text("No reading stored for this day yet.")
                    .font(Chotki.reading(17))
                    .foregroundStyle(Chotki.muted)
                Button {
                    Task { await model.refreshCalendar(around: model.selectedDate) }
                } label: {
                    Text(model.selectedDate == model.today
                         ? "Load today\u{2019}s readings"
                         : "Load this day\u{2019}s readings")
                }
                .buttonStyle(.bordered).tint(Chotki.gold)

                Text("The church calendar is the only thing Chotki asks the network for.")
                    .font(.footnote).foregroundStyle(Chotki.faint)
                    .multilineTextAlignment(.center)
                if model.liturgical.isOffline {
                    Text("It could not be reached just now.")
                        .font(.footnote).foregroundStyle(Chotki.faint)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

/// The kathismata appointed for the day, and the psalms in them.
///
/// The Typikon appoints the Psalter across the services of the day rather than
/// as one daily portion, so that is what this shows.
struct PsalterView: View {
    @Bindable var model: Model
    @State private var open: Int?

    private var season: Kathisma.Season {
        guard let day = model.liturgicalDay(model.selectedDate) else { return .ordinary }
        return Kathisma.season(paschaDistance: day.paschaDistance)
    }

    private var appointed: [Kathisma.Appointed] {
        Kathisma.appointed(weekday: model.selectedDate.weekday, season: season)
    }

    var body: some View {
        List {
            if appointed.isEmpty {
                Text(season == .brightWeek
                     ? "The Psalter is not read through Bright Week."
                     : "No kathisma is appointed today.")
                    .foregroundStyle(Chotki.muted)
                    .listRowBackground(Chotki.ground)
            }
            ForEach(appointed, id: \.service) { entry in
                Section {
                    ForEach(entry.kathismata, id: \.self) { number in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { open == number },
                                set: { open = $0 ? number : nil }
                            )
                        ) {
                            ForEach(Psalter.kathisma(number)) { psalm in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Psalm \(psalm.number)")
                                        .font(.caption).foregroundStyle(Chotki.goldDim)
                                    if let title = psalm.superscription {
                                        Text(title).font(Chotki.reading(13)).italic()
                                            .foregroundStyle(Chotki.muted)
                                    }
                                    ForEach(psalm.verses, id: \.number) { verse in
                                        Text("\(verse.number)  \(verse.text)")
                                            .font(Chotki.reading(15))
                                            .foregroundStyle(Chotki.parchment)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Chotki.ground)
                            }
                            ReadingEnd(identity: "psalter-\(model.selectedDate.iso)-\(number)") {
                                model.finishPsalter()
                            }
                            .frame(height: 1)
                            .accessibilityHidden(true)
                            .listRowBackground(Chotki.ground)
                            .listRowSeparator(.hidden)
                        } label: {
                            HStack {
                                Text("Kathisma \(number)").foregroundStyle(Chotki.parchment)
                                if let range = Kathisma.psalms(in: number) {
                                    Text(range.lowerBound == range.upperBound
                                         ? "Psalm \(range.lowerBound)"
                                         : "Psalms \(range.lowerBound)–\(range.upperBound)")
                                        .font(.footnote).foregroundStyle(Chotki.muted)
                                }
                            }
                        }
                        .listRowBackground(Chotki.ground)
                    }
                } header: {
                    Text(entry.service.displayName).foregroundStyle(Chotki.gold)
                }
            }
            Text(Psalter.source)
                .font(.system(size: 11)).foregroundStyle(Chotki.faint)
                .listRowBackground(Chotki.ground)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Chotki.ground)
        .navigationTitle("The Psalter")
        .navigationBarTitleDisplayMode(.inline)
    }
}
