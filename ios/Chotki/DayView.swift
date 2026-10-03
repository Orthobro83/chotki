import SwiftUI
import ChotkiCore

/// The day, and what is on the rule for it.
///
/// **Only the box marks a rule kept.** Carried straight from the other two
/// platforms, where making the whole row the target fixed an unclickable
/// checkbox and broke everything sitting beside it — the prayers link and the
/// edit control both ticked the rule off. The answer to a small target is
/// padding around it, not a bigger target.
struct DayView: View {
    @Bindable var model: Model
    var transition: Namespace.ID
    var openLibrary: () -> Void
    @State private var monthOpen = false

    private var entries: [DayEntry] { model.entries(on: model.selectedDate) }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HomeCalendar(model: model, maxHeight: proxy.size.height / 2, expanded: $monthOpen)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let title = model.liturgicalDay(model.selectedDate)?.title {
                            Text(title)
                                .font(Chotki.reading(15.5))
                                .foregroundStyle(Chotki.muted)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                        }
                        fastNote
                        dayHeader
                        if model.rules.isEmpty {
                            firstRule
                        } else if entries.isEmpty {
                            EmptyDay(open: openLibrary)
                        } else {
                            HStack(spacing: 0) {
                                Text("Today's commitments")
                                Text(" · ")
                                Button("Add a new rule.", action: openLibrary)
                                    .foregroundStyle(Chotki.gold)
                                    .accessibilityLabel("Add a new rule")
                            }
                            .font(Chotki.reading(13))
                            .foregroundStyle(Chotki.muted)
                            .padding(.leading, 18)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                            Commitments(model: model, openLibrary: openLibrary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                }
                .accessibilityIdentifier("the day")
                // The picture is not part of the day's scroll. It stays at the
                // foot, and the saying is printed on it just above the bar.
                SayingCard(
                    date: model.selectedDate,
                    persistMotion: model.selectedDate == model.today
                )
            }
        }
        .background(Chotki.ground)
    }

    private var dayHeader: some View {
        HStack {
            Text(Format.longDate(model.selectedDate))
                .font(Chotki.reading(17))
                .foregroundStyle(Chotki.parchment)
                .accessibilityLabel("The day")
            Spacer(minLength: 8)
            if model.settings.showOldStyleDates {
                let old = model.selectedDate.adding(days: -13)
                Text("\(old.day) \(Format.shortMonth(old.month)) o.s.")
                    .font(Chotki.reading(13))
                    .foregroundStyle(Chotki.faint)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    @ViewBuilder private var fastNote: some View {
        if let day = model.liturgicalDay(model.selectedDate),
           day.isFast, !day.isFastFree,
           entries.contains(where: { $0.rule.isFastingRule }) || model.settings.observances.fasting == .observed {
            VStack(alignment: .leading, spacing: 10) {
                Text("The calendar marks this as \(day.fastDescription).")
                    .font(Chotki.reading(13))
                    .foregroundStyle(Chotki.violet)
                if !day.abstentions.isEmpty {
                    Text("Customarily set aside: \(day.abstentions.joined(separator: ", ")).")
                        .font(.system(size: 12))
                        .foregroundStyle(Chotki.faint)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    private var firstRule: some View {
        Button(action: openLibrary) {
            VStack(spacing: 14) {
                Text("+")
                    .font(.system(size: 28))
                    .foregroundStyle(Chotki.gold)
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(Chotki.goldDim, lineWidth: 1.5))
                Text("Create your first rule")
                    .font(Chotki.reading(22))
                    .fontWeight(.medium)
                    .foregroundStyle(Chotki.parchment)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create your first rule")
    }
}

/// Nothing due, and the way to change that.
///
/// The words alone sent someone to a small icon in a corner they had not
/// noticed. The library is named in the sentence, so the library is drawn under
/// it, at a size that reads as the thing to press. The corner button stays
/// where it is: it is how the library is reached on every other day, and a
/// control that moves depending on whether the day is empty is worse than one
/// that does not.
private struct EmptyDay: View {
    /// Opens the same sheet the toolbar does.
    var open: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("Nothing on the rule for this day.")
                .foregroundStyle(Chotki.muted)
            Text("Take something on from the library when you are ready.")
                .font(.footnote)
                .foregroundStyle(Chotki.faint)

            Button(action: open) {
                LibraryIcon(tint: Chotki.gold, side: 56)
                    .frame(width: 88, height: 88)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .accessibilityLabel("Take something on from the library")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(24)
    }
}


/// The zoom that carries a tapped thing into the screen it opens.
///
/// Guarded rather than assumed: it arrived in iOS 18 and the floor here is 17,
/// so on 17 the push is the ordinary one. A transition is not worth excluding a
/// device over.
extension View {
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
