import SwiftUI
import ChotkiCore

/// The kathismata appointed for the day, and the psalms in them.
///
/// The Typikon appoints the Psalter across the services of the day rather than
/// as one daily portion, so that is what this shows: what is read, and where in
/// the day it is read. Someone keeping a kathisma a day takes the first of
/// them; the rest is there because it is what the day actually has.
struct PsalterView: View {
    @ObservedObject var model: AppModel
    @State private var open: Int?

    private var season: Kathisma.Season {
        guard let day = model.liturgical.cachedDay(for: model.selectedDate) else {
            return .ordinary
        }
        return Kathisma.season(paschaDistance: day.paschaDistance)
    }

    private var appointed: [Kathisma.Appointed] {
        Kathisma.appointed(weekday: model.selectedDate.weekday, season: season)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if appointed.isEmpty {
                    Text("No kathisma is appointed today.")
                        .foregroundStyle(Theme.muted)
                    Text(season == .brightWeek
                         ? "The Psalter is not read through Bright Week."
                         : "Nothing is appointed for this day.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                } else {
                    ForEach(appointed, id: \.service) { entry in
                        Text(entry.service.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 4)
                        ForEach(entry.kathismata, id: \.self) { number in
                            KathismaRow(number: number, open: $open)
                        }
                    }
                }

                Divider().padding(.vertical, 8)
                Text(Psalter.source)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct KathismaRow: View {
    let number: Int
    @Binding var open: Int?

    private var isOpen: Bool { open == number }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                open = isOpen ? nil : number
            } label: {
                HStack {
                    Text("Kathisma \(number)")
                        .foregroundStyle(Theme.parchment)
                    if let range = Kathisma.psalms(in: number) {
                        Text(range.lowerBound == range.upperBound
                             ? "Psalm \(range.lowerBound)"
                             : "Psalms \(range.lowerBound)–\(range.upperBound)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(isOpen ? "⌃" : "⌄").foregroundStyle(Theme.goldDim)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                ForEach(Psalter.kathisma(number)) { psalm in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Psalm \(psalm.number)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.goldDim)
                        if let title = psalm.superscription {
                            Text(title)
                                .font(.system(size: 12).italic())
                                .foregroundStyle(Theme.muted)
                        }
                        ForEach(psalm.verses, id: \.number) { verse in
                            Text("\(verse.number)  \(verse.text)")
                                .foregroundStyle(Theme.parchment)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
