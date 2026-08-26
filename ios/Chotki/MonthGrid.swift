import SwiftUI
import ChotkiCore

/// The month, so a day can be reached and marked after the fact.
///
/// Going back is not an edge case. Someone who kept their evening prayers and
/// forgot to say so should be able to put that right — the record is supposed
/// to describe what happened, and a record that can only be written on the day
/// it happened describes the app's convenience instead.
///
/// Capped at a share of the height it is given. On Android this grid took
/// whatever it wanted and pushed the rules it sits above off the bottom of the
/// screen, where nothing could reach them. The cap is not decoration.
struct MonthGrid: View {
    @Bindable var model: Model
    var maxHeight: CGFloat

    private var month: CalendarDate { model.visibleMonth }
    private var firstOfMonth: CalendarDate {
        CalendarDate(year: month.year, month: month.month, day: 1)!
    }
    private var leading: Int { firstOfMonth.weekday.rawValue - 1 }
    private var days: Int { month.lastDayOfMonth }
    private var weeks: Int { Int(ceil(Double(leading + days) / 7.0)) }

    /// Room for the month row and the weekday initials, taken off before the
    /// cells are sized — or the cap is not a cap.
    private let chrome: CGFloat = 64

    private var cell: CGFloat {
        let forCells = max(maxHeight - chrome, 0)
        return min(forCells / CGFloat(weeks), 46)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("The month before")
                Spacer()
                Text("\(monthName(month.month)) \(String(month.year))")
                    .foregroundStyle(Chotki.parchment)
                    // The month name slides with the direction it moved.
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.28), value: month.month)
                Spacer()
                Button { step(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("The month after")
            }
            .font(.system(size: 15))
            .tint(Chotki.muted)
            .padding(.horizontal, 6)

            HStack(spacing: 0) {
                ForEach(Array(["s", "m", "t", "w", "t", "f", "s"].enumerated()), id: \.offset) {
                    _, initial in
                    Text(initial)
                        .font(.system(size: 11))
                        .foregroundStyle(Chotki.faint)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let number = week * 7 + column - leading + 1
                        if number >= 1 && number <= days,
                           let date = CalendarDate(year: month.year, month: month.month, day: number) {
                            DayCell(model: model, date: date).frame(height: cell)
                        } else {
                            Color.clear.frame(height: cell)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func step(_ by: Int) {
        withAnimation(.snappy(duration: 0.28)) {
            model.visibleMonth = by < 0
                ? firstOfMonth.adding(days: -1)
                : firstOfMonth.adding(days: days)
        }
    }
}

private struct DayCell: View {
    @Bindable var model: Model
    let date: CalendarDate

    private var selected: Bool { date == model.selectedDate }
    private var settled: Bool { model.isSettled(on: date) }
    private var hasAnything: Bool { !model.entries(on: date).isEmpty }

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { model.selectedDate = date }
        } label: {
            VStack(spacing: 2) {
                Text("\(date.day)")
                    .font(.system(size: 15))
                    .foregroundStyle(
                        selected ? Chotki.ground : (hasAnything ? Chotki.parchment : Chotki.faint)
                    )
                // A quiet mark, never a score. It says a day was seen through,
                // and says nothing at all about the days that were not.
                Circle()
                    .fill(settled && !selected ? Chotki.goldDim : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Chotki.gold : .clear)
                    .padding(3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day \(date.day)")
    }
}

func monthName(_ month: Int) -> String {
    [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ][month - 1]
}
