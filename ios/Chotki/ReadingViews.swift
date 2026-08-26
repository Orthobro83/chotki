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
            if let day {
                VStack(alignment: .leading, spacing: 14) {
                    if !day.summaryTitle.isEmpty {
                        Text(day.summaryTitle).font(.footnote).foregroundStyle(Chotki.muted)
                    }
                    // Never re-cased: orthocal's words are shown as it writes them.
                    if let title = day.title {
                        Text(title).font(.system(size: 20)).foregroundStyle(Chotki.gold)
                    }
                    if day.isFast {
                        Text("The calendar marks this as \(day.fastLevelDescription).")
                            .font(.footnote).foregroundStyle(Chotki.goldDim)
                        if !day.abstentions.isEmpty {
                            Text("Customarily set aside: \(day.abstentions.joined(separator: ", ")).")
                                .font(.footnote).foregroundStyle(Chotki.faint)
                        }
                    }

                    ForEach(Array(day.readings.enumerated()), id: \.offset) { _, reading in
                        Divider().overlay(Chotki.line)
                        Text(reading.display)
                            .font(.footnote).foregroundStyle(Chotki.gold)
                        Text(reading.text)
                            .font(.system(size: 16)).foregroundStyle(Chotki.parchment)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let patristic = PatristicReadings.shared.reading(for: model.selectedDate) {
                        Divider().overlay(Chotki.line)
                        Text("From the fathers").font(.footnote).foregroundStyle(Chotki.gold)
                        Text(patristic.text)
                            .font(.system(size: 16)).foregroundStyle(Chotki.parchment)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
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
                .padding(18)
            } else {
                VStack(spacing: 6) {
                    Text("No reading stored for this day yet.")
                        .foregroundStyle(Chotki.muted)
                    Text("The church calendar is the only thing Chotki asks the network for, and it will fill in when it can reach it.")
                        .font(.footnote).foregroundStyle(Chotki.faint)
                        .multilineTextAlignment(.center)
                }
                .padding(24).padding(.top, 40)
            }
        }
        .background(Chotki.ground)
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
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
