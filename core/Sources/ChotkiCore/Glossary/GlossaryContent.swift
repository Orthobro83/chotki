import Foundation

// Explanations of the terms this app puts on screen, written for someone new to
// Orthodoxy. Bundled rather than fetched: it must work offline, and it should
// not change under the reader.
//
// Accuracy caveat: this is introductory, not authoritative. Practice varies
// between jurisdictions and parishes, and anything touching fasting or
// preparation for communion should come from a priest rather than an app.
extension Glossary {

    public static let bundled: [GlossaryEntry] = general + prayerWords + russianPractice
        + jordanvilleWords

    static let general: [GlossaryEntry] = [

        // MARK: the church year

        GlossaryEntry(
            slug: "pascha", term: "Pascha", aliases: ["Holy Pascha", "Orthodox Easter"],
            pronunciation: "PAS-kha",
            short: "The Resurrection of Christ — the greatest feast of the year.",
            full: """
            Pascha is the Resurrection, and the centre of the whole church year. Everything \
            movable in the calendar is measured from it: Great Lent before, Pentecost fifty \
            days after.

            Its date is worked out on the Julian reckoning by nearly every Orthodox church, \
            including those that otherwise use the New Calendar. That is why Orthodox Pascha \
            often falls on a different Sunday from Western Easter, and why Old and New \
            Calendar Orthodox nevertheless keep it on the same day as each other.
            """,
            category: .calendar, related: ["great-lent", "pentecost", "bright-week", "pascha-distance"]
        ),

        GlossaryEntry(
            slug: "great-feast", term: "Great Feast",
            aliases: ["Great Feasts", "Major feast", "Twelve Great Feasts", "Major Feast of the Lord", "Major Feast of the Theotokos"],
            short: "The twelve principal feasts of the year, with Pascha above them all.",
            full: """
            Twelve feasts stand above the rest of the calendar. They divide into Feasts of the \
            Lord — the Nativity, Theophany, Transfiguration and others — and Feasts of the \
            Theotokos, such as her Dormition and Annunciation.

            Pascha is not counted among the twelve. It stands alone, above them.

            Each Great Feast has days of preparation before it and an afterfeast following, \
            ending in its leavetaking. So a Great Feast is a season in miniature rather than a \
            single day.
            """,
            category: .calendar, related: ["theotokos", "leavetaking", "pascha", "feast-rank"]
        ),

        GlossaryEntry(
            slug: "theotokos", term: "Theotokos", aliases: ["Most-Holy Theotokos", "Birth-giver of God", "God-bearer"],
            pronunciation: "thee-oh-TOH-kos",
            short: "A title of the Virgin Mary meaning \"the one who gives birth to God\".",
            full: """
            The word is Greek: *Theos*, God, and *tokos*, birth-giver.

            It was affirmed at the Council of Ephesus in 431, and the argument was about Christ \
            rather than about Mary. To say she gave birth only to a man would divide Christ into \
            two persons. Calling her Theotokos insists that the one she bore is a single person, \
            fully God and fully man.

            You will hear it constantly in the services. It is not a claim that Mary is the \
            origin of the divine nature — it is a statement about who her son is.
            """,
            category: .calendar, related: ["great-feast", "dormition", "annunciation"]
        ),

        GlossaryEntry(
            slug: "tone", term: "Tone", aliases: ["Tone 1", "Octoechos", "the eight tones"],
            short: "One of eight melodies the church cycles through, a new one each week.",
            full: """
            Orthodox hymns are sung in eight tones — eight melodic patterns, each with its own \
            character. The church moves through them one per week, so the cycle takes eight \
            weeks and then begins again.

            The collection of hymns arranged this way is called the Octoechos, "eight tones". \
            When the calendar says "Tone 2", it is telling you which set of melodies the \
            week's hymns are sung to.

            You do not need to know this to pray. It becomes useful when you start following \
            services in a book.
            """,
            category: .calendar, related: ["vespers", "matins"]
        ),

        GlossaryEntry(
            slug: "leavetaking", term: "Leavetaking", aliases: ["Apodosis", "leave-taking"],
            short: "The last day a feast is celebrated, when its hymns are sung a final time.",
            full: """
            A Great Feast is not kept for one day. It has an afterfeast lasting several days or \
            more, during which its hymns continue to appear in the services.

            The leavetaking is the final day of that afterfeast. The feast's hymns are sung once \
            more in full, and then the calendar moves on. The Greek word is *apodosis*, "giving \
            back".
            """,
            category: .calendar, related: ["great-feast", "nativity"]
        ),

        GlossaryEntry(
            slug: "old-calendar", term: "Old Calendar", aliases: ["Julian calendar", "Julian reckoning", "Old Style", "o.s."],
            short: "The older reckoning, thirteen days behind the civil calendar for fixed feasts.",
            full: """
            Most Orthodox Christians — the Russian, Serbian, Georgian and Jerusalem churches \
            among others — keep fixed feasts on the Julian calendar, which now runs thirteen \
            days behind the civil one. So the Nativity falls on 7 January by the wall calendar, \
            not 25 December.

            Two things it does *not* change. Days of the week are identical: Wednesday is \
            Wednesday everywhere. And Pascha, with everything measured from it, is the same for \
            Old and New Calendar Orthodox alike, because nearly all of them compute it the Julian \
            way regardless.

            So the disagreement between calendars clusters around the Nativity and Theophany \
            rather than spreading through the year.
            """,
            category: .calendar, related: ["new-calendar", "pascha", "nativity", "theophany"]
        ),

        GlossaryEntry(
            slug: "new-calendar", term: "New Calendar", aliases: ["Revised Julian", "New Style", "n.s."],
            short: "The newer reckoning, on which fixed feasts match the civil calendar.",
            full: """
            Adopted in the 1920s by the Greek, Romanian, Bulgarian and Antiochian churches among \
            others. Fixed feasts fall on the same dates as the civil calendar, so the Nativity is \
            25 December.

            Almost every church that adopted it kept the old way of computing Pascha, so Pascha \
            and everything measured from it stay in step with the Old Calendar churches. Only \
            fixed feasts moved.
            """,
            category: .calendar, related: ["old-calendar", "pascha"]
        ),

        GlossaryEntry(
            slug: "pascha-distance", term: "Days since Pascha", aliases: ["pascha distance"],
            short: "How far the day sits from Pascha, which places every movable feast.",
            full: """
            Much of the calendar is not fixed to a date but to a distance from Pascha: Great Lent \
            before it, Pentecost fifty days after, the Apostles' Fast beginning after that.

            Counting days from Pascha is how those are located in any given year.
            """,
            category: .calendar, related: ["pascha", "pentecost", "apostles-fast"]
        ),

        GlossaryEntry(
            slug: "pentecost", term: "Pentecost",
            short: "The descent of the Holy Spirit on the apostles, fifty days after Pascha.",
            full: """
            Fifty days after Pascha, the Holy Spirit descended on the apostles. The church counts \
            weeks from it for the rest of the year — which is why the calendar says things like \
            "Wednesday of the 12th week after Pentecost".
            """,
            category: .calendar, related: ["pascha", "apostles-fast"]
        ),

        GlossaryEntry(
            slug: "theophany", term: "Theophany", aliases: ["Epiphany"],
            pronunciation: "thee-OFF-uh-nee",
            short: "The baptism of Christ in the Jordan, and one of the Great Feasts.",
            full: """
            Celebrated on 6 January — 19 January by the wall calendar for Old Calendar churches. \
            The name means "manifestation of God": at the baptism the Father is heard, the Spirit \
            descends as a dove, and the Son stands in the water.

            Water is blessed on this feast, and people take it home.
            """,
            category: .calendar, related: ["great-feast", "nativity", "old-calendar"]
        ),

        GlossaryEntry(
            slug: "nativity", term: "Nativity", aliases: ["Nativity of Christ", "Christmas"],
            short: "The birth of Christ — 25 December, which is 7 January on the Old Calendar.",
            full: """
            One of the Great Feasts, preceded by a forty-day fast. Old Calendar churches keep it \
            on 7 January by the wall calendar, New Calendar churches on 25 December — the same \
            feast on the same church date, differently placed against the civil year.
            """,
            category: .calendar, related: ["nativity-fast", "great-feast", "old-calendar", "leavetaking"]
        ),

        GlossaryEntry(
            slug: "dormition", term: "Dormition", aliases: ["Dormition of the Theotokos", "Falling asleep"],
            short: "The falling-asleep of the Theotokos, kept on 15 August.",
            full: """
            A Great Feast, preceded by a two-week fast. "Dormition" means falling asleep — the \
            church's ordinary way of speaking about the death of a Christian, and here about the \
            end of the Theotokos's earthly life.
            """,
            category: .calendar, related: ["theotokos", "dormition-fast", "great-feast"]
        ),

        GlossaryEntry(
            slug: "transfiguration", term: "Transfiguration",
            short: "Christ shining with uncreated light on the mountain, kept on 6 August.",
            full: """
            A Great Feast. Christ took Peter, James and John up the mountain and was transfigured \
            before them, his face shining. Grapes and other first fruits are blessed on this day.
            """,
            category: .calendar, related: ["great-feast", "dormition-fast"]
        ),

        GlossaryEntry(
            slug: "annunciation", term: "Annunciation",
            short: "The angel's announcement to the Theotokos, kept on 25 March.",
            full: """
            A Great Feast of the Theotokos: the archangel Gabriel announces to Mary that she will \
            bear Christ, and she consents. It falls during Great Lent almost every year, and the \
            fast is relaxed for it.
            """,
            category: .calendar, related: ["theotokos", "great-feast", "great-lent"]
        ),

        GlossaryEntry(
            slug: "bright-week", term: "Bright Week",
            short: "The week following Pascha — entirely fast-free, even Wednesday and Friday.",
            full: """
            The seven days after Pascha are kept as one continuous feast. No fasting at all, \
            including on the Wednesday and Friday that would normally be fast days. The royal \
            doors of the icon screen stand open all week.
            """,
            category: .calendar, related: ["pascha", "fast-free", "wednesday-friday-fast"]
        ),

        GlossaryEntry(
            slug: "feast-rank", term: "Feast rank", aliases: ["Polyeleos", "typikon symbol", "Red cross", "Black squiggle"],
            short: "How solemnly a day is kept, marked in service books by small symbols.",
            full: """
            Not every commemoration is equal. Service books grade days with small printed symbols \
            — a black squiggle for a modest commemoration, a red cross for a more festal one, a \
            red cross in a circle for the highest ranks.

            The rank tells the clergy which hymns and which parts of the services to use. For \
            most people it is simply a signal of how significant the day is.
            """,
            category: .calendar, related: ["great-feast", "typikon", "matins"]
        ),

        // MARK: fasting

        GlossaryEntry(
            slug: "wednesday-friday-fast", term: "Wednesday and Friday fast", aliases: ["Wed/Fri fast", "the weekly fast"],
            short: "The ordinary weekly fast, kept most Wednesdays and Fridays of the year.",
            full: """
            Wednesday recalls the betrayal of Christ, Friday the crucifixion. Together they are \
            the most common fast in the Orthodox year, kept outside fast-free periods.

            The days of the week are the same under both calendars, so this rhythm is identical \
            whichever reckoning your parish keeps.
            """,
            category: .fasting, related: ["fast-free", "wine-and-oil", "old-calendar"]
        ),

        GlossaryEntry(
            slug: "great-lent", term: "Great Lent", aliases: ["Lenten Fast", "Lent"],
            short: "The long fast before Holy Week and Pascha — the most demanding of the year.",
            full: """
            Forty days, followed by Holy Week. It is the most strictly kept fast in the calendar \
            and is as much about prayer, almsgiving and confession as about food.

            The services change substantially during it, including the Presanctified Liturgy on \
            weekdays.
            """,
            category: .fasting, related: ["pascha", "presanctified-liturgy", "forgiveness-sunday"]
        ),

        GlossaryEntry(
            slug: "nativity-fast", term: "Nativity Fast", aliases: ["Advent fast", "Philip's Fast"],
            short: "Forty days of fasting before the Nativity.",
            full: """
            Begins forty days before the Nativity and is kept less strictly than Great Lent, with \
            fish permitted on many days. Sometimes called Philip's Fast, because it starts the day \
            after the feast of the Apostle Philip.
            """,
            category: .fasting, related: ["nativity", "great-lent"]
        ),

        GlossaryEntry(
            slug: "apostles-fast", term: "Apostles' Fast", aliases: ["Apostles Fast", "Peter and Paul Fast"],
            short: "A fast of variable length, ending on the feast of Saints Peter and Paul.",
            full: """
            It begins the Monday after All Saints — which depends on Pascha — and always ends on \
            29 June, the feast of the Apostles Peter and Paul. Because the start moves and the end \
            does not, its length changes every year, from a few days to several weeks.

            An early Pascha makes it long; a late Pascha makes it short.
            """,
            category: .fasting, related: ["pentecost", "pascha", "pascha-distance"]
        ),

        GlossaryEntry(
            slug: "dormition-fast", term: "Dormition Fast",
            short: "Two weeks of fasting before the Dormition of the Theotokos.",
            full: """
            1 to 14 August, before the feast of the Dormition. Short but kept fairly strictly. \
            The Transfiguration falls inside it, and the fast is relaxed for that day.
            """,
            category: .fasting, related: ["dormition", "transfiguration", "theotokos"]
        ),

        GlossaryEntry(
            slug: "fast-free", term: "Fast free", aliases: ["Fast Free", "no fast"],
            short: "A day with no fasting at all, including Wednesday and Friday.",
            full: """
            Certain periods lift fasting entirely: Bright Week after Pascha, the days between the \
            Nativity and Theophany, the week after Pentecost, and the week following the Sunday \
            of the Publican and Pharisee.

            On these days the usual Wednesday and Friday fast does not apply.
            """,
            category: .fasting, related: ["bright-week", "wednesday-friday-fast", "nativity"]
        ),

        GlossaryEntry(
            slug: "wine-and-oil", term: "Wine and oil are allowed", aliases: ["Fish, Wine and Oil are Allowed", "wine and oil"],
            short: "A relaxation of a fast for a feast — not the lifting of it.",
            full: """
            Fasting in the Orthodox tradition has degrees rather than being on or off. The strictest \
            days set aside meat, fish, dairy, eggs, wine and oil. A feast falling within a fast \
            often permits some of these back — commonly wine and oil, sometimes fish as well.

            So "fish, wine and oil are allowed" means the fast continues in a gentler form, not \
            that it has been suspended.
            """,
            category: .fasting, related: ["fast-free", "great-feast", "xerophagy"]
        ),

        GlossaryEntry(
            slug: "xerophagy", term: "Xerophagy", pronunciation: "zeh-ROFF-uh-jee",
            short: "The strictest form of fasting: uncooked food, without oil or wine.",
            full: """
            Literally "dry eating". Appointed on the strictest days of Great Lent. It is the far end \
            of the fasting scale and is not what most people keep.

            How much of the traditional discipline any individual keeps is settled with your priest or \
            spiritual father, taking health, work and circumstances into account. It is not a competition, and it is \
            not the point.
            """,
            category: .fasting, related: ["great-lent", "wine-and-oil"]
        ),

        // MARK: services

        GlossaryEntry(
            slug: "divine-liturgy", term: "Divine Liturgy", aliases: ["Liturgy"],
            short: "The principal service, at which communion is given.",
            full: """
            The central service of the church, served on Sundays and feast days. The Eucharist is \
            celebrated and the faithful receive communion.

            Preparation for receiving — fasting beforehand, confession, prayers — varies between \
            parishes and is something to settle with your priest or spiritual father rather than to
            work out alone.
            """,
            category: .services, related: ["vespers", "matins", "presanctified-liturgy", "antidoron"]
        ),

        GlossaryEntry(
            slug: "vespers", term: "Vespers",
            short: "The evening service, which begins the church's day.",
            full: """
            The liturgical day starts at sunset, not midnight — so Vespers on Saturday evening is \
            already the beginning of Sunday. This is why Saturday evening services matter, and why \
            a feast is celebrated from the evening before.
            """,
            category: .services, related: ["matins", "vigil", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "matins", term: "Matins", aliases: ["Orthros"],
            short: "The morning service, often served the evening before as part of a vigil.",
            full: """
            The long morning service. In many parishes it is joined to Vespers and served the \
            evening before as an All-Night Vigil, rather than at dawn.
            """,
            category: .services, related: ["vespers", "vigil", "tone"]
        ),

        GlossaryEntry(
            slug: "vigil", term: "All-Night Vigil", aliases: ["Vigil"],
            short: "Vespers and Matins joined together on the eve of a Sunday or feast.",
            full: """
            Despite the name it rarely lasts all night now — usually two to three hours on a \
            Saturday evening or the eve of a great feast.
            """,
            category: .services, related: ["vespers", "matins", "great-feast"]
        ),

        GlossaryEntry(
            slug: "presanctified-liturgy", term: "Presanctified Liturgy",
            short: "A Lenten evening service giving communion from gifts consecrated earlier.",
            full: """
            The full Divine Liturgy is not served on the weekdays of Great Lent, because it is \
            always a celebration. So that people may still receive communion, the Presanctified \
            Liturgy distributes gifts consecrated on the previous Sunday.
            """,
            category: .services, related: ["great-lent", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "akathist", term: "Akathist", pronunciation: "uh-KAH-thist",
            short: "A long hymn of praise, sung standing.",
            full: """
            The name means "not sitting" — it is sung standing throughout. The best known is the \
            Akathist to the Theotokos, sung during Great Lent, but there are akathists to many \
            saints and feasts.
            """,
            category: .services, related: ["theotokos", "great-lent"]
        ),

        GlossaryEntry(
            slug: "typikon", term: "Typikon", pronunciation: "TIP-ee-kon",
            short: "The book of rules governing how services are put together.",
            full: """
            The Typikon settles what is sung and read on any given day, how feasts combine when \
            they coincide, and how the fasts are kept. It is a reference book for clergy and \
            readers rather than something most people consult.
            """,
            category: .services, related: ["feast-rank", "tone"]
        ),

        // MARK: prayer

        GlossaryEntry(
            slug: "prayer-rule", term: "Prayer rule", aliases: ["rule of prayer", "kanon"],
            short: "The set of prayers a person keeps daily, agreed with their priest or spiritual father.",
            full: """
            A rule is personal. It usually includes morning and evening prayers and grows over \
            time — and it is meant to be settled with your priest or spiritual father, who will \
            normally suggest starting with far less than a newcomer expects.

            A small rule kept faithfully is worth more than a large one abandoned. Reducing a rule \
            is a normal and sometimes necessary act, not a failure.
            """,
            category: .prayer, related: ["jesus-prayer", "chotki", "trisagion"]
        ),

        // Written by Ryan. The reflections send the reader to his spiritual
        // father, and the glossary explained Confession and Confessor but not
        // this — which are related and not the same thing.
        GlossaryEntry(
            slug: "spiritual-father", term: "Spiritual father",
            aliases: ["spiritual fathers", "spiritual guide"],
            short: "A guide in the life in Christ, who accompanies a person toward repentance and communion with God.",
            full: """
            In Orthodox Christianity, a spiritual father is a guide in the life in Christ — someone \
            who helps form, heal, and accompany a person toward repentance and communion with God.
            """,
            category: .prayer, related: ["confession", "confessor", "prayer-rule"]
        ),

        GlossaryEntry(
            slug: "jesus-prayer", term: "Jesus Prayer",
            short: "\"Lord Jesus Christ, Son of God, have mercy on me, a sinner.\"",
            full: """
            A single short prayer, repeated. It can be said anywhere, silently, at any time, and \
            is often counted on a prayer rope.

            Traditions around it vary considerably, and the deeper practices are meant to be taken \
            up under guidance rather than from a book.
            """,
            category: .prayer, related: ["chotki", "prayer-rule"]
        ),

        GlossaryEntry(
            slug: "chotki", term: "Chotki", aliases: ["prayer rope", "komboskini", "komvoschoinion"],
            pronunciation: "KHOT-kee",
            short: "A knotted wool rope used for counting the Jesus Prayer.",
            full: """
            A loop of wool tied in knots — commonly 33, 50 or 100 — used to count repetitions of \
            the Jesus Prayer without having to keep track mentally.

            The Russian name is *chotki*, the Greek *komboskini*. Each knot is traditionally tied \
            in a pattern of interlocking crosses.
            """,
            category: .prayer, related: ["jesus-prayer", "prayer-rule"]
        ),

        GlossaryEntry(
            slug: "trisagion", term: "Trisagion", pronunciation: "tri-SAH-gee-on",
            short: "\"Holy God, Holy Mighty, Holy Immortal, have mercy on us.\"",
            full: """
            The name means "thrice holy". The prayer is said three times, and it opens a great many \
            services and private prayer rules — often as part of a short set of opening prayers \
            called the Trisagion Prayers.
            """,
            category: .prayer, related: ["prayer-rule", "divine-liturgy"]
        ),

        // MARK: scripture

        GlossaryEntry(
            slug: "epistle", term: "Epistle", aliases: ["Apostol"],
            short: "The day's reading from the New Testament letters or Acts.",
            full: """
            Each day has appointed readings. The Epistle comes from the letters of the apostles or \
            from Acts, and is read before the Gospel at the Divine Liturgy.

            The book containing these readings in their appointed order is called the Apostol.
            """,
            category: .scripture, related: ["gospel", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "gospel", term: "Gospel",
            short: "The day's reading from Matthew, Mark, Luke or John.",
            full: """
            Read after the Epistle at the Divine Liturgy, and at Matins on Sundays and feasts. The \
            church works through the Gospels on a fixed yearly cycle, so the reading is appointed \
            rather than chosen.
            """,
            category: .scripture, related: ["epistle", "divine-liturgy", "matins"]
        ),

        // MARK: saints and titles

        GlossaryEntry(
            slug: "venerable", term: "Venerable", aliases: ["Ven.", "Righteous"],
            short: "A title for a saint who lived as a monk or nun.",
            full: """
            Marks a saint who followed the monastic life. In Greek usage the equivalent is *Hosios*. \
            It says how the saint lived rather than how they died.
            """,
            category: .saints, related: ["martyr", "wonderworker"]
        ),

        GlossaryEntry(
            slug: "martyr", term: "Martyr", aliases: ["Virgin Martyr"],
            short: "A saint who was killed for confessing Christ.",
            full: """
            The word means "witness". Martyrs are among the earliest saints venerated by the church, \
            and the calendar is full of them.
            """,
            category: .saints, related: ["greatmartyr", "hieromartyr", "confessor"]
        ),

        GlossaryEntry(
            slug: "greatmartyr", term: "Greatmartyr", aliases: ["Great Martyr", "Greatmartyrs"],
            short: "A martyr of particular renown, often one who suffered at length.",
            full: """
            Reserved for martyrs whose sufferings were especially severe or whose veneration spread \
            especially widely — Saint George and Saint Barbara among them.
            """,
            category: .saints, related: ["martyr", "hieromartyr"]
        ),

        GlossaryEntry(
            slug: "hieromartyr", term: "Hieromartyr", pronunciation: "HIGH-ero-martyr",
            short: "A martyr who was a bishop or priest.",
            full: """
            *Hiero-* means priestly. The title marks a martyr who held holy orders. The equivalent for \
            a monastic martyr is Venerable Martyr.
            """,
            category: .saints, related: ["martyr", "venerable"]
        ),

        GlossaryEntry(
            slug: "confessor", term: "Confessor",
            short: "A saint who suffered for the faith but was not killed.",
            full: """
            Confessors were imprisoned, tortured or exiled and survived. The title was much used in the \
            twentieth century of those who endured persecution under communist governments.
            """,
            category: .saints, related: ["martyr"]
        ),

        GlossaryEntry(
            slug: "wonderworker", term: "Wonderworker",
            short: "A saint particularly known for miracles.",
            full: """
            Applied to saints through whom many miracles were worked, in life or after death — Saint \
            Nicholas and Saint Spyridon among the best known.
            """,
            category: .saints, related: ["venerable", "unmercenaries"]
        ),

        GlossaryEntry(
            slug: "unmercenaries", term: "Unmercenaries", aliases: ["Unmercenary", "Holy Unmercenaries"],
            short: "Saints, often physicians, who healed without taking payment.",
            full: """
            The best known are Cosmas and Damian. The title means they took no fee — the healing was \
            given freely, as a gift received freely.
            """,
            category: .saints, related: ["wonderworker"]
        ),

        GlossaryEntry(
            slug: "stratelates", term: "Stratelates", pronunciation: "strat-eh-LAH-tees",
            short: "\"Commander\" — a military rank, used as part of a saint's name.",
            full: """
            A Greek term for a senior military officer. When the calendar says "Martyr Andrew \
            Stratelates", it is telling you he was a general who was martyred, not giving him a second \
            name.
            """,
            category: .saints, related: ["martyr", "greatmartyr"]
        ),

        // MARK: objects and places

        GlossaryEntry(
            slug: "prosphora", term: "Prosphora", pronunciation: "PROS-fo-ra",
            short: "The bread offered for the Liturgy, stamped with a seal.",
            full: """
            Leavened bread baked for the Liturgy and marked with a seal. Portions are cut from it \
            during the preparation service, one of which becomes the Eucharist while others are \
            offered for the living and the departed.
            """,
            category: .things, related: ["divine-liturgy", "antidoron"]
        ),

        GlossaryEntry(
            slug: "antidoron", term: "Antidoron", pronunciation: "an-TID-o-ron",
            short: "Blessed bread given out at the end of the Liturgy — not communion.",
            full: """
            The name means "instead of the gift". It is what remains of the prosphora after the portion \
            for communion is taken, blessed but not consecrated.

            Anyone present may receive it, including those who did not take communion. It is a common \
            first point of contact for a visitor.
            """,
            category: .things, related: ["prosphora", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "iconostasis", term: "Iconostasis", aliases: ["icon screen", "royal doors"],
            pronunciation: "eye-ko-no-STAH-sis",
            short: "The screen of icons between the nave and the altar.",
            full: """
            A wall of icons separating the altar from the body of the church, with a central pair of \
            royal doors and doors to either side. Its icons follow a customary arrangement: Christ to \
            the right of the royal doors, the Theotokos to the left.
            """,
            category: .things, related: ["theotokos", "divine-liturgy", "bright-week"]
        ),

        GlossaryEntry(
            slug: "jurisdiction", term: "Jurisdiction",
            short: "The church body a parish belongs to — Russian, Greek, Antiochian and so on.",
            full: """
            The Orthodox Church is one communion made up of self-governing churches, usually organised \
            by nation or historic see. A parish belongs to one of them, and that determines which \
            calendar it keeps and which local saints appear on it.

            If you are unsure which yours is, the parish website or your priest will say.
            """,
            category: .things, related: ["old-calendar", "new-calendar"]
        ),

        GlossaryEntry(
            slug: "forgiveness-sunday", term: "Forgiveness Sunday", aliases: ["Cheesefare Sunday", "Meatfare Sunday", "Cheesefare", "Meatfare"],
            short: "The Sunday Great Lent begins, when people ask forgiveness of one another.",
            full: """
            Lent is approached in stages. Meatfare Sunday is the last day meat is eaten; Cheesefare \
            Sunday, a week later, the last for dairy — and that evening, at Forgiveness Vespers, the \
            congregation asks forgiveness of one another individually before the fast begins.
            """,
            category: .calendar, related: ["great-lent", "vespers"]
        ),

        GlossaryEntry(
            slug: "abstention", term: "Abstention", aliases: ["abstentions", "what is abstained from"],
            short: "The foods a given fast day sets aside — meat, fish, dairy, eggs, wine and oil.",
            full: """
            The church calendar marks each fast day with what is customarily set aside. The strictest \
            days list all six: meat, fish, dairy, eggs, wine and oil. Lesser days relax some of them, \
            so a feast falling in a fast may allow fish, wine and oil.

            "Wine" and "oil" are older categories covering alcohol and cooking oil generally rather \
            than those two items alone.

            This is what the calendar marks, not an instruction. What any individual keeps is \
            settled with your priest or spiritual father, and health, work and circumstance \
            are ordinary reasons for it to look different.
            """,
            category: .fasting, related: ["wednesday-friday-fast", "fast-free", "great-lent"]
        ),

        GlossaryEntry(
            slug: "synaxarion", term: "Synaxarion", pronunciation: "sin-ak-SAR-ee-on",
            short: "The collection of saints' lives, and the account read for the day's commemoration.",
            full: """
            The book of saints' lives arranged by the day they are commemorated, and by extension the \
            short life read at Matins for whoever is remembered today.

            Reading the day's life is a common part of a rule, and it is how most people gradually \
            learn who the saints are — one at a time, on their own day, rather than all at once.
            """,
            category: .saints, related: ["matins", "patron-saint", "wonderworker"]
        )
    ]
}
