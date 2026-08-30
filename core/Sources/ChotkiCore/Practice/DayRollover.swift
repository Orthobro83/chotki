import Foundation

/// What the day view should be showing once the clock has moved on.
///
/// The app was opened on the 28th, closed, and opened again on the 29th still
/// showing the 28th — so the day you were looking at was yesterday, and the
/// rules on it were yesterday's. The same happens to a Mac left running over
/// midnight.
///
/// **Following today is only right when today is what you were looking at.**
/// Someone who went back to look at last week should still be looking at last
/// week when midnight passes; yanking them to today would lose their place for
/// a reason they did not ask for. That is the whole rule, and it is here rather
/// than in three interfaces because all three must answer it the same way.
///
/// Note what is *not* stored: no "am I following today" flag to keep in step
/// with every tap. The model remembers the day it last believed was today, and
/// the comparison does the work — which means tapping back onto today resumes
/// following with nothing to maintain.
public enum DayRollover {

    /// The day to show, given the day being shown, the day that was believed to
    /// be today when it was chosen, and the day it actually is now.
    public static func selection(
        showing selected: CalendarDate,
        wasToday: CalendarDate,
        isToday today: CalendarDate
    ) -> CalendarDate {
        selected == wasToday ? today : selected
    }
}
