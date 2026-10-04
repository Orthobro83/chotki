import Foundation

// The rules offered in the library.
//
// Where a rule carries prayers, the sequence is the prayers common to almost
// every form of that rule rather than any one prayer book's full order. Prayer
// books differ, and the full morning and evening rules are settled with a
// priest — so the app shows what is true of nearly all of them and leaves the
// rest to be added. Nothing here is enabled by default: taking
// something on is always a deliberate act, and first launch invites two or
// three rather than presenting all of it.
//
// Summaries describe what the rule is, never how well anyone keeps it, and
// never imply a standard. Where practice varies, the summary says so.
extension RuleLibrary {

    private static func t(_ h: Int, _ m: Int) -> TimeOfDay { TimeOfDay(hour: h, minute: m)! }

    public static let bundled: [RuleTemplate] = [

        // MARK: prayer

        RuleTemplate(
            id: "morning-prayers", title: "Morning prayers",
            summary: "The morning prayers from the prayer book, on rising.",
            recurrence: .daily, timeOfDay: t(6, 30), category: .prayer,
            glossarySlugs: ["prayer-rule", "trisagion", "icon-corner"],
            prayerIDs: PrayerSequence.morning.prayerIDs
        ),
        RuleTemplate(
            id: "evening-prayers", title: "Evening prayers",
            summary: "The evening prayers, before sleep.",
            recurrence: .daily, timeOfDay: t(21, 30), category: .prayer,
            glossarySlugs: ["prayer-rule", "compline", "icon-corner"],
            prayerIDs: PrayerSequence.evening.prayerIDs
        ),
        RuleTemplate(
            id: "jesus-prayer", title: "The Jesus Prayer",
            summary: "A set number of repetitions, often counted on a prayer rope.",
            note: "Start with a number you can keep. It is meant to grow slowly.",
            recurrence: .daily, category: .prayer, reminders: RuleReminders(leads: []),
            glossarySlugs: ["jesus-prayer", "chotki", "prayer-rule"],
            prayerIDs: ["jesus-prayer"]
        ),
        RuleTemplate(
            id: "trisagion-prayers", title: "The Trisagion prayers",
            summary: "The short opening prayers — a complete rule in itself when time is short.",
            recurrence: .daily, category: .prayer,
            glossarySlugs: ["trisagion", "prayer-rule"],
            prayerIDs: PrayerSequence.trisagionPrayers.prayerIDs
        ),
        RuleTemplate(
            id: "prayer-before-meals", title: "Prayer before meals",
            summary: "The Lord's Prayer, and the blessing of the table.",
            recurrence: .daily, category: .prayer, reminders: .silent,
            glossarySlugs: ["grace-before-meals", "prayer-rule"],
            prayerIDs: ["our-father", "table-blessing"]
        ),
        RuleTemplate(
            id: "akathist", title: akathistRuleTitle,
            summary: "The Akathist to the Theotokos, on the Fridays of Great Lent when the Church appoints it.",
            note: "The whole hymn is appointed for Friday of the fifth week. Greek and Antiochian practice also reads one part on each of the first four Fridays. The Fridays follow Pascha, so they are the same civil days on the old calendar and the new.",
            recurrence: .liturgical(.akathist), category: .prayer, reminders: .silent,
            glossarySlugs: ["akathist", "theotokos"]
        ),
        RuleTemplate(
            id: "psalter-kathisma", title: "A kathisma of the Psalter",
            summary: "One of the twenty sections the Psalms are divided into.",
            recurrence: .daily, category: .prayer,
            glossarySlugs: ["psalter", "kathisma", "prayer-rule"]
        ),

        // MARK: fasting

        RuleTemplate(
            id: "wednesday-friday-fast", title: "The Wednesday and Friday fast",
            summary: "The weekly fast, lifted by the Church in a few stretches of the year.",
            // Wednesdays and Fridays, literally. This used to be
            // `.liturgical(.fastDay)`, which means *any* day the calendar marks
            // as a fast — so through the Dormition Fast, Great Lent and the
            // Nativity Fast it fired every single day. The fast-free stretches
            // are handled as dispensations, not by changing which days apply.
            recurrence: .weekly(days: [.wednesday, .friday]), category: .fasting,
            glossarySlugs: ["wednesday-friday-fast", "fast-free", "abstention"]
        ),
        RuleTemplate(
            id: "great-lent", title: "Great Lent",
            summary: "The fast of the weeks before Pascha.",
            recurrence: .liturgical(.season(.greatLent)), category: .fasting,
            glossarySlugs: ["great-lent", "pascha", "great-canon", "prostration"]
        ),
        RuleTemplate(
            id: "nativity-fast", title: "The Nativity Fast",
            summary: "The forty days before the Nativity.",
            recurrence: .liturgical(.season(.nativityFast)), category: .fasting,
            glossarySlugs: ["nativity-fast", "nativity"]
        ),
        RuleTemplate(
            id: "apostles-fast", title: "The Apostles' Fast",
            summary: "The fast after Pentecost, of variable length each year.",
            recurrence: .liturgical(.season(.apostlesFast)), category: .fasting,
            glossarySlugs: ["apostles-fast", "pentecost"]
        ),
        RuleTemplate(
            id: "dormition-fast", title: "The Dormition Fast",
            summary: "The two weeks before the Dormition of the Theotokos.",
            recurrence: .liturgical(.season(.dormitionFast)), category: .fasting,
            glossarySlugs: ["dormition-fast", "dormition", "theotokos"]
        ),

        // MARK: services

        RuleTemplate(
            id: "sunday-liturgy", title: "Sunday Liturgy",
            summary: "The Divine Liturgy on Sunday morning.",
            recurrence: .weekly(days: [.sunday]), timeOfDay: t(9, 30),
            category: .services, reminders: .forService,
            glossarySlugs: ["divine-liturgy", "holy-mysteries", "antidoron"]
        ),
        RuleTemplate(
            id: "saturday-vigil", title: "Saturday evening service",
            summary: "Vespers or the All-Night Vigil before Sunday.",
            recurrence: .weekly(days: [.saturday]), timeOfDay: t(17, 0),
            category: .services, reminders: .forService,
            glossarySlugs: ["vespers", "vigil", "confession"]
        ),
        RuleTemplate(
            id: "great-feast-liturgy", title: "Liturgy on a Great Feast",
            summary: "The Liturgy on the Twelve Great Feasts, where you are able to attend.",
            note: "Not everyone lives within reach of a parish. This can be left off, or kept for the feasts you can get to.",
            recurrence: .liturgical(.greatFeast), timeOfDay: t(9, 30),
            category: .services, reminders: .forService,
            glossarySlugs: ["great-feast", "divine-liturgy"]
        ),
        RuleTemplate(
            id: "confession", title: "Confession",
            summary: "Monthly to begin with. Russian practice expects it before each communion.",
            note: "The app cannot know when you next commune, so this is a regular reminder rather than a rule. How often is settled with your priest or spiritual father.",
            recurrence: .monthly(day: 1), category: .services,
            glossarySlugs: ["confession", "preparation-for-communion", "holy-mysteries"]
        ),
        RuleTemplate(
            id: "communion", title: "Holy Communion",
            summary: "Receiving the Holy Mysteries.",
            note: "Frequency and preparation are settled with your priest or spiritual father.",
            recurrence: .weekly(days: [.sunday]), category: .services,
            glossarySlugs: ["holy-mysteries", "preparation-for-communion", "eucharistic-fast", "zapivka"]
        ),

        // MARK: reading

        RuleTemplate(
            id: "daily-gospel", title: "The day's Gospel",
            summary: "The Gospel reading appointed for today.",
            recurrence: .daily, timeOfDay: t(12, 0), category: .reading,
            glossarySlugs: ["gospel", "epistle"]
        ),
        RuleTemplate(
            id: "daily-epistle", title: "The day's Epistle",
            summary: "The Epistle reading appointed for today.",
            recurrence: .daily, timeOfDay: t(12, 0), category: .reading,
            glossarySlugs: ["epistle", "gospel"]
        ),
        RuleTemplate(
            id: "lives-of-saints", title: "The life of the day's saint",
            summary: "Read about whoever is commemorated today.",
            recurrence: .daily, category: .reading, reminders: RuleReminders(leads: []),
            glossarySlugs: ["synaxarion", "patron-saint"]
        ),

        // MARK: life

        RuleTemplate(
            id: "almsgiving", title: "Almsgiving",
            summary: "Giving, in whatever form you have settled on.",
            recurrence: .weekly(days: [.sunday]), category: .life, reminders: .silent,
            glossarySlugs: ["almsgiving", "great-lent"]
        ),
        RuleTemplate(
            id: "prayer-for-the-departed", title: departedRuleTitle,
            summary: "Remembering your dead by name.",
            note: "Said daily, by name. The Church also remembers the departed at the Liturgy, and on the Saturdays of Souls.",
            recurrence: .daily, category: .life, reminders: .silent,
            traditions: [.russian, .serbian, .bulgarian],
            glossarySlugs: ["panikhida", "radonitsa", "saturday-of-souls"]
        )
    ]
}
