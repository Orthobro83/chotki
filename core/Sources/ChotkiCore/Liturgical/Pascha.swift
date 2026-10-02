import Foundation

/// Civil date of Orthodox Pascha, and a day's distance from it.
///
/// Orthocal's `pascha_distance` is what decides the Akathist Fridays. Reading it
/// only from a fetched day meant a Friday a year ahead had no hymn until the
/// network had been asked about that exact day. The distance follows Pascha, and
/// Pascha is the Julian computus, so it can be known without a request.
///
/// The sign matches orthocal, not "days until the nearest Pascha". From the
/// Sunday of Zacchaeus (77 days before the upcoming Pascha) through Pascha
/// itself the distance is negative, and zero on Pascha. Before that Sunday it
/// is the number of days since the previous Pascha.
public enum Pascha {

    /// Meeus's Julian computus, then the Julian-to-Gregorian shift for that year.
    /// Pascha falls in Julian March or April, so adding the shift as civil days
    /// does not cross a February 29 on which the two calendars disagree.
    public static func civil(year: Int) -> CalendarDate {
        let a = year % 4
        let b = year % 7
        let c = year % 19
        let d = (19 * c + 15) % 30
        let e = (2 * a + 4 * b - d + 34) % 7
        let base = d + e + 114
        let month = base / 31
        let day = (base % 31) + 1
        let julian = CalendarDate(year: year, month: month, day: day)!
        let century = year / 100
        let shift = century - century / 4 - 2
        return julian.adding(days: shift)
    }

    public static func distance(on date: CalendarDate) -> Int {
        let thisYear = civil(year: date.year)
        let upcoming = date <= thisYear ? thisYear : civil(year: date.year + 1)
        let previous = date <= thisYear ? civil(year: date.year - 1) : thisYear
        let zacchaeus = upcoming.adding(days: -77)
        if date >= zacchaeus {
            return -date.days(until: upcoming)
        }
        return previous.days(until: date)
    }
}
