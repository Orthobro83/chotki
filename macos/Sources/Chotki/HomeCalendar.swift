import SwiftUI
import ChotkiCore

struct HomeCalendar: View {
    @ObservedObject var model: AppModel
    var compact = false
    @State private var anchor: CalendarDate?
    @State private var rangeCenter: CalendarDate?
    @State private var monthDirection = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.35) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.calendarExpanded {
                HStack {
                    arrow(-1)
                    Text(Format.monthAndYear(model.visibleMonth)).font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                    arrow(1)
                }.foregroundStyle(Theme.parchment)
                ZStack {
                    month(model.visibleMonth)
                        .id("\(model.visibleMonth.year)-\(model.visibleMonth.month)")
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: CGFloat(monthDirection * 36))),
                            removal: .opacity.combined(with: .offset(x: CGFloat(-monthDirection * 36)))
                        ))
                }.frame(maxWidth: .infinity).frame(height: 214).clipped()
                expansionButton.frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 5) {
                    arrow(-1)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: 6) {
                                ForEach(-730...730, id: \.self) { offset in
                                    let date = (rangeCenter ?? model.selectedDate).adding(days: offset)
                                    VStack(spacing: 0) {
                                        CalendarChip(model: model, date: date, week: true, compact: compact)
                                        if date == model.selectedDate { expansionButton }
                                        else { Color.clear.frame(height: 18) }
                                    }.id(date)
                                }
                            }.padding(.vertical, 3).chotkiScrollContent().horizontalWheelScroll()
                        }.scrollIndicators(.hidden).frame(width: compact ? 318 : 330, height: 80)
                            .onAppear {
                                rangeCenter = model.selectedDate
                                proxy.scrollTo(model.selectedDate, anchor: .center)
                            }
                            .onChange(of: model.selectedDate) { date in
                                if abs((rangeCenter ?? date).days(until: date)) > 500 { rangeCenter = date }
                                DispatchQueue.main.async {
                                    withAnimation(motion) { proxy.scrollTo(date, anchor: .center) }
                                }
                            }
                            .onChange(of: anchor) { date in
                                if let date {
                                    if abs((rangeCenter ?? date).days(until: date)) > 500 { rangeCenter = date }
                                    DispatchQueue.main.async {
                                        withAnimation(motion) { proxy.scrollTo(date, anchor: .center) }
                                    }
                                }
                            }
                    }
                    arrow(1)
                }.frame(maxWidth: .infinity, alignment: .center)
            }
        }.padding(.horizontal, compact ? 16 : 24).padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: model.calendarExpanded ? "month:\(model.visibleMonth.iso)" : "week:\(model.selectedDate.iso)") {
                if model.calendarExpanded { await model.loadCalendarMonth() }
                else { await model.loadCalendarWeek() }
            }
            .onChange(of: model.selectedDate) { _ in model.clearThanksgiving() }
    }
    private var expansionButton: some View {
        Button {
            if !model.calendarExpanded { model.visibleMonth = model.selectedDate }
            withAnimation(motion) { model.calendarExpanded.toggle() }
        } label: {
            Image(systemName: "chevron.down").font(.system(size: 16, weight: .ultraLight))
                .scaleEffect(x: 2.2, y: 0.7).rotationEffect(.degrees(model.calendarExpanded ? 180 : 0))
                .frame(width: 48, height: 18)
        }.buttonStyle(.plain).foregroundStyle(Theme.goldDim)
            .accessibilityLabel(model.calendarExpanded ? "Show Week" : "Show Month")
    }
    private func arrow(_ direction: Int) -> some View {
        Button {
            if model.calendarExpanded {
                let first = CalendarDate(year: model.visibleMonth.year, month: model.visibleMonth.month, day: 1)!
                let date = direction < 0 ? first.adding(days: -1) : first.adding(days: first.lastDayOfMonth)
                monthDirection = direction
                withAnimation(motion) {
                    model.visibleMonth = CalendarDate(year: date.year, month: date.month, day: 1)!
                }
            } else {
                anchor = (anchor ?? model.selectedDate).adding(days: direction * 7)
            }
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right").font(.system(size: 11))
                .frame(width: 18, height: 28).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(Theme.goldDim)
            .accessibilityLabel("\(direction < 0 ? "Previous" : "Next") \(model.calendarExpanded ? "Month" : "Week")")
    }
    private func month(_ date: CalendarDate) -> some View {
        let first = CalendarDate(year: date.year, month: date.month, day: 1)!
        let start = first.adding(days: 1 - first.weekday.rawValue)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
            ForEach(0..<7) { i in
                Text(["S", "M", "T", "W", "T", "F", "S"][i]).font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            ForEach(0..<42) { i in
                let day = start.adding(days: i)
                if day.year == date.year && day.month == date.month {
                    CalendarChip(model: model, date: day, week: false)
                } else {
                    Color.clear.frame(height: 26)
                }
            }
        }.frame(maxWidth: compact ? 354 : 600)
    }
}

struct CalendarChip: View {
    @ObservedObject var model: AppModel
    let date: CalendarDate
    var week: Bool
    var compact = false
    var body: some View {
        let day = model.liturgical.cachedDay(for: date)
        let feast = model.settings.observances.feasts.isVisible && day?.isGreatFeast == true
        let fast = model.settings.observances.fasting.isVisible && day?.isFast == true && date.weekday != .sunday && !feast
        let selected = date == model.selectedDate
        let colour: Color = feast ? Theme.gold : date.weekday == .sunday ? Theme.ochre : Theme.parchment
        Button {
            model.selectedDate = date
            if model.calendarExpanded && (date.year != model.visibleMonth.year || date.month != model.visibleMonth.month) {
                model.visibleMonth = date
            }
        } label: {
            VStack(spacing: 2) {
                if week {
                    Text(["S", "M", "T", "W", "T", "F", "S"][date.weekday.rawValue - 1])
                        .font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
                Text("\(date.day)").font(.system(size: week ? 16 : 12, weight: .medium)).foregroundStyle(colour)
                if model.dayIsSettled(date) { Circle().fill(Theme.gold).frame(width: 3, height: 3) }
            }.frame(width: week ? (compact ? 39 : 42) : 45, height: week ? 54 : 26)
                .background(selected ? Theme.ground : fast ? Color(red: 0.23, green: 0.205, blue: 0.33) : Theme.ground.opacity(0.65), in: RoundedRectangle(cornerRadius: week ? 14 : 8))
                .overlay(RoundedRectangle(cornerRadius: week ? 14 : 8).stroke(selected ? Theme.gold : .clear, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityLabel(Format.longDate(date) + (feast ? ", Feast" : fast ? ", Fast" : ""))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
