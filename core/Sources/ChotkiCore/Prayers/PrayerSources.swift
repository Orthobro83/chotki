import Foundation

/// A place to read prayers online.
public struct PrayerSource: Sendable, Hashable, Identifiable {
    public let title: String
    public let organisation: String
    public let url: String

    public var id: String { url }

    public init(title: String, organisation: String, url: String) {
        self.title = title
        self.organisation = organisation
        self.url = url
    }
}

/// Where to read prayers beyond the ones bundled here.
///
/// **These are references, not the source of the app's wording.** Almost all of
/// them publish modern translations, which are under copyright however freely
/// they can be read — being on a public web page is not the same as being in
/// the public domain. The text bundled in `PrayerContent` comes from older
/// public-domain translations for that reason.
///
/// They are listed so that someone can compare the wording here against their
/// own jurisdiction's, and find the fuller rules this app does not carry.
public enum PrayerSources {

    public static let further: [PrayerSource] = [
        PrayerSource(title: "Morning Prayers", organisation: "Orthodox Church in America",
                     url: "https://www.oca.org/orthodoxy/prayers/morning-prayers"),
        PrayerSource(title: "Evening Prayers", organisation: "Orthodox Church in America",
                     url: "https://www.oca.org/orthodoxy/prayers/evening-prayers"),
        PrayerSource(title: "O Heavenly King and the Trisagion Prayers",
                     organisation: "Orthodox Church in America",
                     url: "https://www.oca.org/orthodoxy/prayers/trisagion"),
        PrayerSource(title: "The Daily Cycles of Prayer", organisation: "Orthodox Church in America",
                     url: "https://www.oca.org/orthodoxy/the-orthodox-faith/worship/the-daily-cycles-of-prayer"),
        PrayerSource(title: "Morning Prayers", organisation: "Greek Orthodox Archdiocese of America",
                     url: "https://www.goarch.org/-/morning-prayers"),
        PrayerSource(title: "Daily Personal Prayers: In the Morning",
                     organisation: "Greek Orthodox Archdiocese of America",
                     url: "https://www.goarch.org/-/daily-personal-prayers-in-the-morning"),
        PrayerSource(title: "Daily Personal Prayers: At Night (Compline)",
                     organisation: "Greek Orthodox Archdiocese of America",
                     url: "https://www.goarch.org/-/daily-personal-prayers-at-night-compline-"),
        PrayerSource(title: "Prayers Before Sleep", organisation: "Greek Orthodox Archdiocese of America",
                     url: "https://www.goarch.org/-/prayers-before-sleep"),
        PrayerSource(title: "Prayerbook", organisation: "Orthodox Archdiocese of America",
                     url: "https://orthodoxarchdiocese.com/prayerbook/"),
        PrayerSource(title: "Daily Morning Prayer",
                     organisation: "Assembly of Canonical Orthodox Bishops of the United States",
                     url: "https://www.assemblyofbishops.org/resources-and-publications/military/prayers/daily-morning-prayer"),
        PrayerSource(title: "The Abbreviated Daily Cycle", organisation: "OrthoChristian",
                     url: "https://orthochristian.com/175618.html"),
        PrayerSource(title: "The Daily Cycle, or Hours of Prayer", organisation: "OrthodoxPrayer.org",
                     url: "https://www.orthodoxprayer.org/Hours.html"),
        PrayerSource(title: "Orthodox Evening Prayers", organisation: "Orthodox River",
                     url: "http://www.orthodoxriver.org/prayers/orthodox-evening-prayers/"),
        PrayerSource(title: "Evening Prayers", organisation: "OrthodoxChristian.info",
                     url: "https://www.orthodoxchristian.info/pages/Evening_Prayers.htm"),
        PrayerSource(title: "Morning and Evening Prayers", organisation: "The Old Believers",
                     url: "https://oldbeliever.substack.com/p/morning-and-evening-prayers"),
        PrayerSource(title: "A Prayer Rule for Beginners", organisation: "The Eastern Church",
                     url: "https://www.theeasternchurch.com/saints/orthodox-prayer-rule-beginners"),
        PrayerSource(title: "Morning and Evening Prayers", organisation: "St Barnabas Orthodox Church",
                     url: "https://stbarnabasoc.org/morning-and-evening-prayers/"),
        PrayerSource(title: "A Prayer Rule", organisation: "St Nicholas Orthodox Church, Billings",
                     url: "https://orthodoxbillings.org/a-prayer-rule/"),
        PrayerSource(title: "Prayer", organisation: "St Mark Orthodox Church",
                     url: "https://stmarkoca.org/prayer/"),
        PrayerSource(title: "Orthodox Prayers", organisation: "St John the Merciful Orthodox Church",
                     url: "https://orthodoxorlando.com/orthodox-prayers/"),
        PrayerSource(title: "Daily Orthodox Prayers", organisation: "St Nina Orthodox Church, Orlando",
                     url: "https://www.stninaorlando.org/prayers/"),
        PrayerSource(title: "Morning Prayers", organisation: "St George Orthodox Church",
                     url: "https://www.stgorthodox.org/morning-prayers"),
        PrayerSource(title: "Evening Prayers", organisation: "St George of Troy Antiochian Orthodox Church",
                     url: "https://stgeorgeoftroy.churchcenter.com/pages/evening-prayers"),
        PrayerSource(title: "Services of the Daily Cycle", organisation: "St Herman of Alaska Orthodox Church",
                     url: "https://www.sthermansoca.org/orthodox-christianity/services-of-the-daily-cycle/")
    ]
}
