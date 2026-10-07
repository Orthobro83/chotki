import SwiftUI
import ChotkiCore

/// The week above the day's rules, or the month when the chevron asks for it.
///
/// Folded, the week follows the finger. A drag does not choose a day; a tap
/// does. Left somewhere else, the strip comes back to the selected day after
/// half a minute. The arrows move a week while it is folded and a month while
/// it is open. Reading the rules does not fold it.
struct HomeCalendar: View {
    @Bindable var model: Model
    var maxHeight: CGFloat
    @Binding var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var placed = false
    @State private var recenter = 0
    @State private var returnTask: Task<Void, Never>?

    private var month: CalendarDate { model.visibleMonth }
    private var firstOfMonth: CalendarDate {
        CalendarDate(year: month.year, month: month.month, day: 1) ?? month
    }
    private var leading: Int { firstOfMonth.weekday.rawValue - 1 }
    private var days: Int { month.lastDayOfMonth }
    private var weeks: Int { Int(ceil(Double(leading + days) / 7.0)) }
    private var weekStart: CalendarDate {
        model.selectedDate.adding(days: -(model.selectedDate.weekday.rawValue - 1))
    }

    private let chrome: CGFloat = 88
    private let legible: CGFloat = 24

    private var monthCell: CGFloat {
        let forCells = max(maxHeight - chrome, 0)
        let widest = max((UIScreen.main.bounds.width - 32) / 7, 1)
        return min(forCells / CGFloat(max(weeks, 1)), widest)
    }

    private var folded: Bool { !expanded || monthCell < legible }

    var body: some View {
        VStack(spacing: 0) {
            navigation
            if folded {
                WeekStrip(model: model, placed: $placed, recenter: recenter, onDrift: scheduleReturn)
            } else {
                monthGrid
            }
            if monthCell >= legible {
                grip
            }
        }
        .padding(.horizontal, 8)
        // The cap is for the open month, so a short phone can still read the day.
        // Applied while folded, the same cap is taken as the height and the week
        // sits at the top of an empty half-screen.
        .frame(maxHeight: folded ? nil : maxHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: folded)
        .task(id: folded ? "week-\(model.selectedDate.iso)" : "month-\(month.year)-\(month.month)") {
            let centre = folded ? model.selectedDate : firstOfMonth
            await model.refreshCalendar(around: centre, days: folded ? 16 : 42)
        }
    }

    private var todayLink: TodayLink? {
        TodayLink.needed(selected: model.selectedDate, today: model.today,
                         visibleMonth: model.visibleMonth, monthOpen: !folded)
    }

    private var navigation: some View {
        ZStack {
            Text(folded ? weekLabel(weekStart) : Format.monthAndYear(month))
                .font(Chotki.reading(16))
                .foregroundStyle(Chotki.parchment)
            HStack(spacing: 0) {
                arrow("‹", folded ? "The week before" : "The month before", -1)
                if todayLink == .onTheLeft { backToToday(.onTheLeft) }
                Spacer(minLength: 0)
                if todayLink == .onTheRight { backToToday(.onTheRight) }
                arrow("›", folded ? "The week after" : "The month after", 1)
            }
        }
        .padding(.vertical, 6)
    }

    /// Sans-serif, between the arrow and the title, on the side today lies.
    private func backToToday(_ link: TodayLink) -> some View {
        Button {
            model.selectedDate = model.today
            model.visibleMonth = model.today
            recenter += 1
        } label: {
            Text(link.text)
                .font(.system(size: 13))
                .foregroundStyle(Chotki.gold)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to today")
    }

    private func arrow(_ glyph: String, _ label: String, _ by: Int) -> some View {
        Button { step(by) } label: {
            Text(glyph)
                .font(.system(size: 20))
                .foregroundStyle(Chotki.muted)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ by: Int) {
        if folded {
            model.selectedDate = model.selectedDate.adding(days: 7 * by)
            model.visibleMonth = model.selectedDate
        } else {
            let date = by < 0
                ? firstOfMonth.adding(days: -1)
                : firstOfMonth.adding(days: days)
            model.visibleMonth = CalendarDate(year: date.year, month: date.month, day: 1) ?? date
        }
    }

    private var monthGrid: some View {
        let cell = min(monthCell, 46)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(["s", "m", "t", "w", "t", "f", "s"].enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.system(size: 11))
                        .foregroundStyle(Chotki.faint)
                        .frame(maxWidth: .infinity)
                }
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<leading, id: \.self) { _ in
                    Color.clear.frame(height: cell)
                }
                ForEach(1...days, id: \.self) { day in
                    if let date = CalendarDate(year: month.year, month: month.month, day: day) {
                        DayCell(model: model, date: date, cell: cell)
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > 48 else { return }
                step(value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private var grip: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                if !expanded { model.visibleMonth = model.selectedDate }
                expanded.toggle()
            }
        } label: {
            Chevron()
                .rotationEffect(.degrees(expanded ? 180 : 0))
                .frame(width: 52, height: 12)
                .frame(maxWidth: .infinity)
                // The target is the whole width, and reaches below the chevron rather than up
                // towards the dates. (While the month is open the day view adds a strip under it.)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(expanded ? "Show one week" : "Show the whole month")
    }

    private func scheduleReturn() {
        returnTask?.cancel()
        returnTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            recenter += 1
        }
    }

    private func weekLabel(_ start: CalendarDate) -> String {
        let end = start.adding(days: 6)
        if start.month == end.month {
            return Format.monthAndYear(start)
        }
        if start.year == end.year {
            return "\(Format.shortMonth(start.month)) – \(Format.shortMonth(end.month)) \(end.year)"
        }
        return "\(Format.shortMonth(start.month)) \(start.year) – \(Format.shortMonth(end.month)) \(end.year)"
    }
}

private struct Chevron: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 48
            let sy = size.height / 10
            var path = Path()
            path.move(to: CGPoint(x: 2 * sx, y: 2.5 * sy))
            path.addLine(to: CGPoint(x: 24 * sx, y: 8 * sy))
            path.addLine(to: CGPoint(x: 46 * sx, y: 2.5 * sy))
            context.stroke(
                path, with: .color(Chotki.goldDim),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

private struct WeekStrip: View {
    @Bindable var model: Model
    @Binding var placed: Bool
    var recenter: Int
    var onDrift: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var span: [CalendarDate] {
        let today = model.today
        let selected = model.selectedDate
        let start = min(today.adding(days: -420), selected.adding(days: -30))
        let end = max(today.adding(days: 420), selected.adding(days: 30))
        var days: [CalendarDate] = []
        var day = start
        while day <= end {
            days.append(day)
            day = day.adding(days: 1)
        }
        return days
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(span, id: \.self) { date in
                        WeekChip(model: model, date: date).id(date)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 56)
            .accessibilityIdentifier("the week")
            .onAppear {
                proxy.scrollTo(model.selectedDate, anchor: .center)
                placed = true
            }
            .onChange(of: model.selectedDate) { _, date in
                guard placed else { return }
                if reduceMotion {
                    proxy.scrollTo(date, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(date, anchor: .center)
                    }
                }
            }
            .onChange(of: recenter) { _, _ in
                if reduceMotion {
                    proxy.scrollTo(model.selectedDate, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(model.selectedDate, anchor: .center)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onEnded { _ in onDrift() }
            )
        }
    }
}

private let chipShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
private let selectedFill = Color(red: 0.090, green: 0.086, blue: 0.059)
private let fastFill = Color(red: 0.227, green: 0.204, blue: 0.329)
private let quietFill = Color(red: 0.071, green: 0.075, blue: 0.102)

private struct WeekChip: View {
    @Bindable var model: Model
    let date: CalendarDate

    private var marks: (feast: Bool, fast: Bool, color: Color?) {
        dayMarks(model, date)
    }

    var body: some View {
        let selected = date == model.selectedDate
        let showFast = marks.fast && !marks.feast
        let letter = ["s", "m", "t", "w", "t", "f", "s"][date.weekday.rawValue - 1]
        Button {
            model.selectedDate = date
            model.visibleMonth = date
        } label: {
            VStack(spacing: 0) {
                Text(letter)
                    .font(Chotki.reading(10))
                    .foregroundStyle(Chotki.faint)
                Text("\(date.day)")
                    .font(Chotki.reading(16))
                    .foregroundStyle(marks.color ?? Chotki.parchmentDim)
            }
            .frame(width: 44, height: 56)
            .background(selected ? selectedFill : showFast ? fastFill : quietFill, in: chipShape)
            .overlay {
                if selected { chipShape.stroke(Chotki.gold, lineWidth: 1.5) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayDescription(date, feast: marks.feast, fast: marks.fast))
    }
}

private struct DayCell: View {
    @Bindable var model: Model
    let date: CalendarDate
    var cell: CGFloat

    private var marks: (feast: Bool, fast: Bool, color: Color?) { dayMarks(model, date) }

    var body: some View {
        let selected = date == model.selectedDate
        let showFast = marks.fast && !marks.feast
        let hasAnything = !model.entries(on: date).isEmpty
        Button {
            model.selectedDate = date
            model.visibleMonth = date
        } label: {
            VStack(spacing: 1) {
                Text("\(date.day)")
                    .font(Chotki.reading(14))
                    .foregroundStyle(marks.color ?? (hasAnything ? Chotki.parchment : Chotki.faint))
                HStack(spacing: 2) {
                    if let color = marks.color, !selected {
                        Circle().fill(color).frame(width: 4, height: 4)
                    }
                    if model.isSettled(on: date), !selected {
                        Circle().fill(Chotki.goldDim).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cell)
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(
                    selected ? selectedFill : showFast ? fastFill : Color.clear
                )
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 8).stroke(Chotki.gold, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayDescription(date, feast: marks.feast, fast: marks.fast))
    }
}

@MainActor
private func dayMarks(_ model: Model, _ date: CalendarDate) -> (feast: Bool, fast: Bool, color: Color?) {
    let observances = model.settings.observances
    let day = model.liturgicalDay(date)
    let feast = day?.isGreatFeast == true && observances.feasts != .hidden
    let fast = day?.isFast == true && day?.isFastFree == false && observances.fasting != .hidden
    let showFast = fast && !feast
    let color: Color? = feast ? Chotki.gold : date.weekday == .sunday ? Chotki.ochre : showFast ? Chotki.violet : nil
    return (feast, fast, color)
}

private func dayDescription(_ date: CalendarDate, feast: Bool, fast: Bool) -> String {
    var text = "Day \(date.iso)"
    if feast { text += ", a great feast" }
    if fast { text += ", a fast day" }
    return text
}
