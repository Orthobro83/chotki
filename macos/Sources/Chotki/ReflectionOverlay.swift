import SwiftUI
import ChotkiCore

/// One weekday's answers, read back.
///
/// Opened from a weekday's header, it shows the answer **and the question as it
/// stood when that answer was written** — which is what the snapshot on every
/// entry is for. The arrows walk that weekday only: Sunday back through
/// Sundays, which is the comparison the section exists to make. They stop at
/// each end rather than wrapping, because a journal is not a carousel.
///
/// Stepping and scoping are decided in `ReflectionSeries` and
/// `ReflectionJournal`, not here. The direction is easy to get backwards —
/// entries are newest first, so older is a *higher* index — and it was got
/// backwards once before that type existed.
struct ReflectionOverlay: View {
    @ObservedObject var model: AppModel
    let weekday: Weekday
    let close: () -> Void

    @State private var index = 0
    @State private var year: Int?
    @State private var month: Int?

    private var period: ReflectionPeriod { ReflectionPeriod(year: year, month: month) }
    private var series: ReflectionSeries { model.reflectionSeries(for: weekday, in: period) }
    private var entry: ReflectionEntry? { series.entry(at: index) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            HStack(spacing: 8) {
                chevron("chevron.left", to: series.older(than: index), hint: "Older")
                pane
                chevron("chevron.right", to: series.newer(than: index), hint: "Newer")
            }
            .frame(maxWidth: 700)
            .padding(.horizontal, 24)
        }
        .onExitCommand(perform: close)
    }

    // MARK: the pane

    private var pane: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
            content
            Rectangle().fill(Theme.lineSoft).frame(height: 1)
            foot
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1) }
        .frame(maxHeight: 520)
    }

    private var head: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Format.weekdayName(weekday).uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.gold)
            if let entry {
                Text(Format.dateWithYear(entry.date))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.parchmentDim)
            }
            Spacer(minLength: 8)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 15).padding(.vertical, 11)
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 0) {
                    // The question as it stood on that date, not as it stands
                    // now. Reading an answer against a question it never
                    // answered would be worse than showing no question at all.
                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.question.title)
                            .font(Theme.reading(15))
                            .foregroundStyle(Theme.parchment)
                        line(entry.question.notice, Theme.parchmentDim)
                        line(entry.question.task, Theme.parchment)
                    }
                    .padding(.bottom, 13)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.lineSoft).frame(height: 1)
                    }

                    Text(entry.text)
                        .font(Theme.reading(13.5))
                        .foregroundStyle(Theme.parchment)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 18).padding(.vertical, 15)
            } else {
                Text("Nothing written in this period.")
                    .font(Theme.reading(13).italic())
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 26)
            }
        }
        .scrollContentBackgroundHidden()
    }

    private func line(_ text: String, _ colour: Color) -> some View {
        Text(text)
            .font(Theme.reading(12.5))
            .foregroundStyle(colour)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: where you are, and how to get elsewhere

    private var foot: some View {
        HStack(spacing: 8) {
            Text(position)
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
            Spacer(minLength: 8)
            yearPicker
            monthPicker
            jumpPicker
        }
        .padding(.horizontal, 15).padding(.vertical, 9)
    }

    private var position: String {
        guard let place = series.position(of: index) else { return "nothing in this period" }
        let name = Format.weekdayName(weekday)
        return "\(place.ordinal) of \(place.total) \(place.total == 1 ? name : name + "s")"
    }

    /// Only years and months that hold something are offered, so an empty
    /// choice is never on the menu.
    private var yearPicker: some View {
        Picker("", selection: Binding(
            get: { year },
            set: { year = $0; month = nil; index = 0 }
        )) {
            Text("All years").tag(Int?.none)
            ForEach(ReflectionJournal.years(model.reflectionEntries, on: weekday), id: \.self) {
                Text(String($0)).tag(Int?.some($0))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 92)
    }

    @ViewBuilder private var monthPicker: some View {
        let available = year.map {
            ReflectionJournal.months(model.reflectionEntries, on: weekday, year: $0)
        } ?? []
        Picker("", selection: Binding(get: { month }, set: { month = $0; index = 0 })) {
            Text("All months").tag(Int?.none)
            ForEach(available, id: \.self) { Text(Format.monthName($0)).tag(Int?.some($0)) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 106)
        // A month with no year behind it would scope every year at once, which
        // reads as a filter that has lost its place.
        .disabled(year == nil)
    }

    private var jumpPicker: some View {
        Picker("", selection: Binding(
            get: { entry?.date },
            set: { date in if let date, let found = series.index(of: date) { index = found } }
        )) {
            ForEach(series.entries, id: \.id) { held in
                Text(Format.dateWithYear(held.date)).tag(CalendarDate?.some(held.date))
            }
            if series.isEmpty { Text("—").tag(CalendarDate?.none) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 132)
        .disabled(series.isEmpty)
    }

    // MARK: the arrows

    private func chevron(_ symbol: String, to target: Int?, hint: String) -> some View {
        Button { if let target { index = target } } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(target == nil ? Theme.faint.opacity(0.4) : Theme.muted)
                .frame(width: 30, height: 58)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .help(hint)
    }
}
