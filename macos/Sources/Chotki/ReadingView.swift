import SwiftUI
import ChotkiCore

struct ReadingViewContent: View {
    @ObservedObject var model: AppModel

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
                Text(title.lowercased())
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            TermText(model: model, text: day.summaryTitle, size: 16, serif: true, colour: Theme.gold)
                .padding(.top, 6).padding(.bottom, 10)

            if model.settings.observances.fasting.isVisible && day.isFast {
                // Reported, never prescribed: what the calendar marks, plus what
                // is customarily set aside — not an instruction to the reader.
                VStack(alignment: .leading, spacing: 3) {
                    TermText(
                        model: model,
                        text: "The calendar marks this as \(day.fastDescription.lowercased()).",
                        size: 11, colour: Theme.violet
                    )
                    if !day.abstentions.isEmpty {
                        Text("Customarily set aside: \(day.abstentions.joined(separator: ", ")).")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.faint)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)
            }

            Rectangle().fill(Theme.line).frame(height: 1)

            ForEach(day.readings.indices, id: \.self) { index in
                let reading = day.readings[index]
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(reading.source.lowercased()) · \(reading.display)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                    if !reading.text.isEmpty {
                        Text(reading.text)
                            .font(.custom("Cardo", size: 13))
                            .foregroundStyle(Theme.parchmentDim)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 10)
                if index < day.readings.count - 1 {
                    Rectangle().fill(Theme.lineSoft).frame(height: 1)
                }
            }

            if let patristic = PatristicReadings.shared.reading(for: model.selectedDate) {
                Rectangle().fill(Theme.line).frame(height: 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text("from the fathers")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                    Text(patristic.text)
                        .font(.custom("Cardo", size: 14))
                        .foregroundStyle(Theme.parchmentDim)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(patristic.author) · \(patristic.source)")
                        .font(.system(size: 11))
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
            .font(.system(size: 11))
            .foregroundStyle(Theme.faint)
            .padding(.top, 8)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var waiting: some View {
        VStack(spacing: 6) {
            Text("No reading stored for this day yet.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Text("Readings are fetched a fortnight ahead and kept, so this fills in shortly.")
                .font(.system(size: 11))
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
        ScrollView { ReadingViewContent(model: model) }
            .frame(maxHeight: .infinity)
            .scrollContentBackgroundHidden()
    }
}
