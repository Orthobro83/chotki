import SwiftUI
import ChotkiCore

/// The day's reading: what the calendar marks, the appointed scripture, and a
/// passage from the fathers.
///
/// Reports what the church calendar says and names who to ask. It never tells
/// anyone what they must do, and never gives dietary instruction.
struct ReadingView: View {
    @Bindable var model: Model

    private var day: LiturgicalDay? { model.liturgicalDay(model.selectedDate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let day {
                    stored(day)
                } else {
                    missing
                }
            }
            // Without an explicit full width the column takes the width of its
            // widest line, which on a day whose commemoration is short left the
            // text in a narrow band with the ground either side of it.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Chotki.ground)
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // The reading is where unfamiliar words are thickest, so the
                // glossary is one tap away from it rather than only from a
                // word that happens to be linked.
                NavigationLink(value: Route.term(slug: nil)) {
                    Label("Glossary", systemImage: "character.book.closed")
                }
                .accessibilityLabel("Glossary")
            }
        }
        // Asks again when the day being looked at moves outside what was
        // fetched, and on first appearance. Cheap: the service only writes days
        // it did not already hold.
        .task(id: model.selectedDate) {
            if model.liturgicalDay(model.selectedDate) == nil {
                await model.refreshCalendar(around: model.selectedDate)
            }
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

        ForEach(Array(day.readings.enumerated()), id: \.offset) { _, reading in
            Divider().overlay(Chotki.line)
            Text(reading.display)
                .font(.footnote).foregroundStyle(Chotki.gold)
            // Scripture is left unlinked on purpose: linking every term inside
            // a whole chapter turns a passage into a field of references.
            Text(reading.text)
                .font(.system(size: 16)).foregroundStyle(Chotki.parchment)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let patristic = PatristicReadings.shared.reading(for: model.selectedDate) {
            Divider().overlay(Chotki.line)
            Text("From the fathers").font(.footnote).foregroundStyle(Chotki.gold)
            Text(patristic.text)
                .font(.system(size: 16)).foregroundStyle(Chotki.parchment)
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
        .font(.system(size: 11)).foregroundStyle(Chotki.faint)
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
                                        Text(title).font(.footnote).italic()
                                            .foregroundStyle(Chotki.muted)
                                    }
                                    ForEach(psalm.verses, id: \.number) { verse in
                                        Text("\(verse.number)  \(verse.text)")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Chotki.parchment)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(Chotki.ground)
                            }
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
