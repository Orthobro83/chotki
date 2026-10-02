import SwiftUI
import ChotkiCore

struct ReadingViewContent: View {
    @ObservedObject var model: AppModel
    @State private var saintLifeExpanded = true

    var body: some View {
        if let day = model.liturgical.cachedDay(for: model.selectedDate) {
            content(day)
        } else {
            waiting
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
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(reading.source) · \(reading.display)").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                Text(reading.text).font(Theme.reading(18)).foregroundStyle(Theme.parchmentDim)
                                    .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        ReadingEnd(identity: "\(model.selectedDate.iso)-\(band)") { model.finishReading(band: band) }.frame(height: 1)
                    }.padding(.vertical, 20).id(band)
                }
            }

            Rectangle().fill(Theme.line).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { saintLifeExpanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Text("Life of the Day’s Saint").font(Theme.reading(22))
                        Spacer()
                        Image(systemName: saintLifeExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }.foregroundStyle(Theme.parchment)
                }.buttonStyle(.plain)
                    .accessibilityLabel(saintLifeExpanded ? "Collapse the saint’s life" : "Expand the saint’s life")
                    .overlay {
                        NativeClickRegion {
                            withAnimation(.easeInOut(duration: 0.25)) { saintLifeExpanded.toggle() }
                        }
                    }
                if saintLifeExpanded {
                if let life = SaintLives.reading(on: day.observedDate) {
                    Text(life.title)
                        .font(Theme.reading(19))
                        .foregroundStyle(Theme.gold)
                    ForEach(Array(life.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(Theme.reading(18))
                            .foregroundStyle(Theme.parchmentDim)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let url = URL(string: life.sourceURL) {
                        Link(life.source, destination: url)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    ReadingEnd(identity: "\(model.selectedDate.iso)-saint-life") {
                        model.finishReading(band: ReadingOrder.saintLifeBand)
                    }.frame(height: 1)
                } else {
                    if !day.saints.isEmpty {
                        Text(day.saints.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                    }
                    Text("A public-domain English life is not yet available for this day.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.faint)
                }
                }
            }
            .padding(.vertical, 20)
            .id(ReadingOrder.saintLifeBand)

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
        .onChange(of: model.readingRequest) { _ in
            if model.readingFocus == ReadingOrder.saintLifeBand { saintLifeExpanded = true }
        }
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
