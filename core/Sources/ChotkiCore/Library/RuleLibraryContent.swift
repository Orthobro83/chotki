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
            prayerIDs: ["beginning", "heavenly-king", "trisagion", "all-holy-trinity", "our-father", "having-risen", "guardian-angel", "rejoice-o-virgin", "it-is-truly-meet"]
        ),
        RuleTemplate(
            id: "evening-prayers", title: "Evening prayers",
            summary: "The evening prayers, before sleep.",
            recurrence: .daily, timeOfDay: t(21, 30), category: .prayer,
            glossarySlugs: ["prayer-rule", "compline", "icon-corner"],
            prayerIDs: ["beginning", "heavenly-king", "trisagion", "all-holy-trinity", "our-father", "evening-forgiveness", "guardian-angel", "it-is-truly-meet"]
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
            prayerIDs: ["beginning", "heavenly-king", "trisagion", "all-holy-trinity", "our-father"]
        ),
        RuleTemplate(
            id: "prayer-before-meals", title: "Prayer before meals",
            summary: "Grace before eating.",
            recurrence: .daily, category: .prayer, reminders: .silent
        ),
        RuleTemplate(
            id: "akathist", title: "An akathist",
            summary: "A hymn of praise, most often to the Theotokos or a saint.",
            recurrence: .weekly(days: [.saturday]), category: .prayer,
            glossarySlugs: ["akathist", "theotokos"]
        ),
        RuleTemplate(
            id: "psalter-kathisma", title: "A kathisma of the Psalter",
            summary: "One of the twenty sections the Psalms are divided into.",
            recurrence: .daily, category: .prayer,
            glossarySlugs: ["psalter", "prayer-rule"]
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
            note: "The app cannot know when you next commune, so this is a regular reminder rather than a rule. How often is settled with your priest.",
            recurrence: .monthly(day: 1), category: .services,
            glossarySlugs: ["confession", "preparation-for-communion", "holy-mysteries"]
        ),
        RuleTemplate(
            id: "communion", title: "Holy Communion",
            summary: "Receiving the Holy Mysteries.",
            note: "Frequency and preparation are settled with your priest.",
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
            recurrence: .weekly(days: [.sunday]), category: .life, reminders: .silent
        ),
        RuleTemplate(
            id: "spiritual-reading", title: "Spiritual reading",
            summary: "A set time with the Fathers or a life of a saint.",
            recurrence: .daily, category: .life, reminders: RuleReminders(leads: [])
        ),
        RuleTemplate(
            id: "prayer-for-the-departed", title: "Prayer for the departed",
            summary: "Remembering your dead by name.",
            recurrence: .daily, category: .life, reminders: .silent,
            traditions: [.russian, .serbian, .bulgarian],
            glossarySlugs: ["panikhida", "radonitsa", "saturday-of-souls"]
        )
    ]
}
