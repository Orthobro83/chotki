import SwiftUI
import ChotkiCore

/// The month, shaded by what the church calendar marks.
///
/// Shading is information, never instruction and never judgement. There is no
/// colour here for a day something was missed — see the Tone section in
/// design.md — and fast and feast shading appear only when the corresponding
/// observance is set to something other than hidden.
struct MonthGridView: View {
    @ObservedObject var model: AppModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            header
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(["s", "m", "t", "w", "t", "f", "s"].indices, id: \.self) { index in
                    Text(["s", "m", "t", "w", "t", "f", "s"][index])
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                }
                ForEach(cells, id: \.self) { cell in
                    if let date = cell.date {
                        dayCell(date, inMonth: cell.inMonth)
                    } else {
                        Color.clear.frame(height: 20)
                    }
                }
            }
            legend
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
    }

    private var header: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 10))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.muted)

            Spacer()
            VStack(spacing: 1) {
                Text(monthName)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.parchment)
                if model.settings.showOldStyleDates, let old = oldStyle {
                    Text(old)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.faint)
                }
            }
            Spacer()

            Button { step(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 10))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.muted)
        }
    }

    private func dayCell(_ date: CalendarDate, inMonth: Bool) -> some View {
        let isToday = date == model.today
        let isSelected = date == model.selectedDate
        let day = model.liturgical.cachedDay(for: date)

        return Button {
            model.selectedDate = date
        } label: {
            Text("\(date.day)")
                .font(.system(size: 11))
                .frame(maxWidth: .infinity)
                .frame(height: 20)
                .foregroundStyle(colour(date, day: day, inMonth: inMonth, isToday: isToday))
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 4).fill(Theme.gold)
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 4).stroke(Theme.goldDim, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func colour(
        _ date: CalendarDate, day: LiturgicalDay?, inMonth: Bool, isToday: Bool
    ) -> Color {
        if isToday { return Theme.ground }
        guard inMonth else { return Theme.faint.opacity(0.6) }

        // A great feast outranks everything else on the day.
        if let day, model.settings.observances.feasts.isVisible, day.isGreatFeast {
            return Theme.gold
        }
        // Sunday is a fact about the civil date, not something fetched. It must
        // still be marked when the liturgical cache is empty or offline.
        if date.weekday == .sunday { return Theme.ochre }
        if let day, model.settings.observances.fasting.isVisible, day.isFast {
            return Theme.violet
        }
        return Theme.parchmentDim
    }

    private var legend: some View {
        HStack(spacing: 11) {
            if model.settings.observances.feasts.isVisible {
                LegendDot(colour: Theme.gold, label: "feast")
            }
            if model.settings.observances.fasting.isVisible {
                LegendDot(colour: Theme.violet, label: "fast")
            }
            LegendDot(colour: Theme.ochre, label: "liturgy")
            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.faint)
    }

    // MARK: layout

    private struct Cell: Hashable {
        let date: CalendarDate?
        let inMonth: Bool
    }

    private var cells: [Cell] {
        let first = CalendarDate(year: visible.year, month: visible.month, day: 1)!
        let leading = first.weekday.rawValue - 1
        var result: [Cell] = []

        // Trailing days of the previous month, shown faintly for context.
        for offset in stride(from: leading, to: 0, by: -1) {
            result.append(Cell(date: first.adding(days: -offset), inMonth: false))
        }
        for day in 1...first.lastDayOfMonth {
            result.append(Cell(
                date: CalendarDate(year: visible.year, month: visible.month, day: day), inMonth: true
            ))
        }
        while result.count % 7 != 0 {
            let last = result.compactMap(\.date).last!
            result.append(Cell(date: last.adding(days: 1), inMonth: false))
        }
        return result
    }

    private var visible: CalendarDate { model.visibleMonth }

    private var monthName: String {
        let names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        return "\(names[visible.month - 1]) \(visible.year)"
    }

    private var oldStyle: String? {
        guard let day = model.liturgical.cachedDay(for: model.selectedDate),
              day.observedDate != day.civilDate
        else { return nil }
        return "\(day.observedDate.day) \(shortMonth(day.observedDate.month)) o.s."
    }

    private func shortMonth(_ month: Int) -> String {
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][month - 1]
    }

    private func step(_ months: Int) {
        var year = visible.year
        var month = visible.month + months
        while month > 12 { month -= 12; year += 1 }
        while month < 1 { month += 12; year -= 1 }
        if let moved = CalendarDate(year: year, month: month, day: 1) {
            model.visibleMonth = moved
        }
    }
}

struct LegendDot: View {
    let colour: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(colour).frame(width: 5, height: 5)
            Text(label)
        }
    }
}
