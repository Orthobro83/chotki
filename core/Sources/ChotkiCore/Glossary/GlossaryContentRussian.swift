import Foundation

// Terms from Russian and ROCOR practice specifically, plus the remaining Great
// Feasts and the services and customs a newcomer meets first.
//
// Practice described here is Russian-tradition. Greek, Antiochian and Romanian
// parishes differ on several of these — most visibly on how often confession is
// expected before communion. Where a point is contested or pastoral, the entry
// says to ask a priest rather than pretending to settle it.
extension Glossary {

    /// Specific to the Russian Church and its history — not shown to someone
    /// who has told the app they are Greek or Antiochian.
    private static let russianOnly: Set<String> = [
        "rocor", "act-of-canonical-communion", "new-martyrs", "kursk-root-icon",
        "john-of-shanghai", "jordanville", "jordanville-prayer-book", "church-slavonic"
    ]

    /// Slavic usage more broadly — Russian, Serbian and Bulgarian practice.
    private static let slavicOnly: Set<String> = [
        "zapivka", "panikhida", "molieben", "radonitsa", "pokrov", "kolivo"
    ]

    static let russianPractice: [GlossaryEntry] = unscopedRussianPractice.map { entry in
        if russianOnly.contains(entry.slug) { return entry.limited(to: [.russian]) }
        if slavicOnly.contains(entry.slug) { return entry.limited(to: [.russian, .serbian, .bulgarian]) }
        return entry
    }

    private static let unscopedRussianPractice: [GlossaryEntry] = [

        // MARK: ROCOR and Russian church history

        GlossaryEntry(
            slug: "rocor", term: "ROCOR", aliases: ["Russian Orthodox Church Outside Russia", "Russian Orthodox Church Abroad", "Church Abroad"],
            short: "The Russian Orthodox Church Outside Russia, formed by exiles after 1917.",
            full: """
            After the Russian Revolution, bishops and faithful who had fled Russia organised \
            themselves abroad, unable to communicate freely with a church under Soviet control. \
            That body became the Russian Orthodox Church Outside Russia.

            It remained administratively separate from the Moscow Patriarchate for most of the \
            twentieth century. In 2007 the two were reconciled by the Act of Canonical Communion: \
            ROCOR is now a self-governing part of the Russian Orthodox Church, keeping its own \
            synod, bishops and traditions.

            It keeps the Old Calendar, and its practice is generally more traditional than that of \
            many other jurisdictions.
            """,
            category: .things, related: ["act-of-canonical-communion", "old-calendar", "jurisdiction", "new-martyrs", "jordanville"]
        ),

        GlossaryEntry(
            slug: "act-of-canonical-communion", term: "Act of Canonical Communion",
            short: "The 2007 agreement reconciling ROCOR with the Moscow Patriarchate.",
            full: """
            Signed on 17 May 2007, it restored full communion between the Russian Orthodox Church \
            Outside Russia and the Moscow Patriarchate after decades of separation.

            ROCOR did not dissolve into the Moscow Patriarchate. It remains self-governing, with \
            its own First Hierarch and Synod of Bishops, while being part of the wider Russian \
            Orthodox Church.
            """,
            category: .things, related: ["rocor", "jurisdiction"]
        ),

        GlossaryEntry(
            slug: "new-martyrs", term: "New Martyrs and Confessors of Russia",
            aliases: ["New Martyrs", "New Martyrs and Confessors"],
            short: "Those killed or persecuted for the faith under Soviet rule.",
            full: """
            Clergy, monastics and laypeople who were executed, imprisoned or exiled during the \
            Soviet persecutions — many thousands of them, of whom a great number have been \
            canonised.

            ROCOR canonised them in 1981, before the Moscow Patriarchate was able to. They are \
            central to the identity of the Church Abroad, and are commemorated together as well \
            as individually.
            """,
            category: .saints, related: ["rocor", "martyr", "confessor"]
        ),

        GlossaryEntry(
            slug: "kursk-root-icon", term: "Kursk Root Icon", aliases: ["Kursk Icon", "Protectress of the Russian Diaspora"],
            short: "A wonderworking icon of the Theotokos, carried with the Russian exiles.",
            full: """
            Found in the forest near Kursk in 1295, at the root of a tree — hence the name. It left \
            Russia after the Revolution and has travelled with the diaspora ever since, which is \
            why it is called the Protectress of the Russian Diaspora.

            It is kept at the Synodal Cathedral of the Sign in New York and travels to ROCOR \
            parishes through the year. Saint John of Shanghai died while praying before it.
            """,
            category: .things, related: ["rocor", "john-of-shanghai", "theotokos"]
        ),

        GlossaryEntry(
            slug: "john-of-shanghai", term: "Saint John of Shanghai and San Francisco",
            aliases: ["St John of Shanghai", "John Maximovitch", "St John the Wonderworker"],
            short: "A twentieth-century ROCOR bishop and wonderworker, canonised in 1994.",
            full: """
            A bishop who served in Shanghai, western Europe and finally San Francisco, known for \
            extreme asceticism — he did not sleep lying down — and for a great many miracles \
            during his life and after.

            He reposed in 1966 while praying before the Kursk Root Icon, and was canonised by \
            ROCOR in 1994. His relics are in the cathedral in San Francisco.
            """,
            category: .saints, related: ["rocor", "kursk-root-icon", "wonderworker"]
        ),

        GlossaryEntry(
            slug: "jordanville", term: "Jordanville", aliases: ["Holy Trinity Monastery", "Holy Trinity Seminary"],
            short: "ROCOR's monastery and seminary in upstate New York, and its publishing house.",
            full: """
            Holy Trinity Monastery at Jordanville, New York, has been the intellectual and \
            liturgical centre of the Church Abroad for decades. Its seminary trains much of the \
            clergy, and its press produced the English service books and prayer books most widely \
            used in ROCOR parishes.
            """,
            category: .things, related: ["rocor", "jordanville-prayer-book", "church-slavonic"]
        ),

        GlossaryEntry(
            slug: "jordanville-prayer-book", term: "Jordanville Prayer Book", aliases: ["Holy Trinity Prayer Book"],
            short: "The standard English prayer book in ROCOR parishes.",
            full: """
            Published by Holy Trinity Monastery, it contains the morning and evening prayers, the \
            Order of Preparation for Holy Communion, the canons, and much else. When a ROCOR \
            priest refers to "the prayer book", this is usually the one meant.
            """,
            category: .prayer, related: ["jordanville", "prayer-rule", "preparation-for-communion"]
        ),

        GlossaryEntry(
            slug: "church-slavonic", term: "Church Slavonic",
            short: "The old liturgical language of the Slavic churches, still widely used.",
            full: """
            Not the same as modern Russian: an older liturgical language, related but distinct, \
            developed for the Slavic churches and still used in services.

            Many parishes outside Russia serve partly or wholly in English. Others alternate, or \
            keep Slavonic for the fixed parts and use English for the readings.
            """,
            category: .things, related: ["rocor", "jordanville", "divine-liturgy"]
        ),

        // MARK: confession and communion

        GlossaryEntry(
            slug: "holy-mysteries", term: "Holy Mysteries", aliases: ["Communion", "Holy Communion", "the Mysteries", "Eucharist"],
            short: "Communion — the Body and Blood of Christ, received at the Divine Liturgy.",
            full: """
            "Mystery" is the Orthodox word where the West says "sacrament". The Holy Mysteries most \
            often means communion itself.

            Preparation is taken seriously and the expectations differ between jurisdictions. In \
            Russian practice they are relatively demanding — see the entry on preparing for \
            communion — and they are always something to settle with a priest rather than to work \
            out alone.
            """,
            category: .services, related: ["preparation-for-communion", "confession", "divine-liturgy", "eucharistic-fast", "zapivka"]
        ),

        GlossaryEntry(
            slug: "confession", term: "Confession", aliases: ["Sacrament of Confession", "Repentance"],
            short: "Confessing sins before a priest — expected before communion in Russian practice.",
            full: """
            The penitent confesses before Christ, with the priest as witness, and receives \
            absolution.

            Russian practice, ROCOR included, generally expects confession before each communion \
            from around the age of seven, most often at the evening service the night before \
            rather than during the Liturgy itself. This is noticeably stricter than Greek practice, \
            where confession is less frequently tied to each communion — a common source of \
            confusion when someone moves between parishes.

            A first confession is a normal thing to be nervous about, and priests expect \
            newcomers. Ask yours how he would like you to prepare.
            """,
            category: .services, related: ["holy-mysteries", "preparation-for-communion", "vespers", "rocor"]
        ),

        GlossaryEntry(
            slug: "preparation-for-communion", term: "Preparation for Holy Communion",
            aliases: ["Order of Preparation", "preparation rule", "communion prayers"],
            short: "The prayers, fasting and confession kept before receiving communion.",
            full: """
            In Russian practice the preparation usually includes: confession beforehand; nothing to \
            eat or drink from midnight; the Order of Preparation for Holy Communion from the prayer \
            book; and commonly three canons and an akathist read the evening before.

            That is the full traditional shape. What any individual actually keeps is settled with \
            a priest, who will take health, work, family and how new you are into account — and \
            who will very often ask for less at the start. Asking is the normal thing to do, not a \
            sign of not managing.
            """,
            category: .prayer, related: ["confession", "holy-mysteries", "eucharistic-fast", "canon", "akathist", "jordanville-prayer-book"]
        ),

        GlossaryEntry(
            slug: "eucharistic-fast", term: "Eucharistic fast", aliases: ["fasting before communion", "fast from midnight"],
            short: "Taking no food or drink from midnight before receiving communion.",
            full: """
            Distinct from the calendar fasts. It is a complete abstention from food and drink from \
            midnight until communion.

            Necessary medication is an ordinary exception, as are conditions such as diabetes. \
            These are pastoral matters, discussed with your priest or spiritual father — not something \
            to be worked out \
            alone or quietly skipped.
            """,
            category: .fasting, related: ["preparation-for-communion", "holy-mysteries", "wednesday-friday-fast"]
        ),

        GlossaryEntry(
            slug: "zapivka", term: "Zapivka", pronunciation: "za-PEEV-ka",
            short: "Bread and warm diluted wine taken immediately after communion.",
            full: """
            Literally "washing down". After receiving, communicants are given a little blessed bread \
            and wine diluted with warm water, so that nothing of the Holy Mysteries remains in the \
            mouth.

            It is a practical reverence, not a second communion. A newcomer usually meets it as a \
            small table beside the chalice that everyone visits on their way back.
            """,
            category: .services, related: ["holy-mysteries", "antidoron", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "canon", term: "Canon", aliases: ["Canon of Repentance", "the three canons"],
            short: "A long structured hymn of nine odes, read in services and in private prayer.",
            full: """
            A canon is built of odes, each modelled on a biblical hymn. Canons appear in Matins and \
            in preparation for communion — the "three canons" commonly read beforehand are those to \
            the Saviour, the Theotokos and the Guardian Angel.

            Note the word does double duty: canons are also the church's disciplinary rules. Context \
            distinguishes them.
            """,
            category: .prayer, related: ["preparation-for-communion", "matins", "great-canon", "akathist"]
        ),

        GlossaryEntry(
            slug: "great-canon", term: "Great Canon of Saint Andrew", aliases: ["Great Canon"],
            short: "A long penitential canon read during the first week of Great Lent.",
            full: """
            Written by Saint Andrew of Crete, it walks through the whole of scripture, turning each \
            episode into self-examination. It is read in four parts across the first week of Great \
            Lent and again in full in the fifth week.

            It is long, and it is meant to be. Standing through it is many people's first real \
            encounter with Lenten services.
            """,
            category: .prayer, related: ["great-lent", "canon", "prostration"]
        ),

        // MARK: services and customs

        GlossaryEntry(
            slug: "panikhida", term: "Panikhida", aliases: ["Panikhida service", "memorial service"],
            pronunciation: "pa-NEE-khi-da",
            short: "A memorial service for the departed.",
            full: """
            Served for the dead, commonly on the third, ninth and fortieth days after a death, then \
            on anniversaries. It may be served in church or at the grave.

            Kolivo — boiled wheat with honey — is often prepared for it, an image of the seed that \
            must fall into the ground before it rises.
            """,
            category: .services, related: ["radonitsa", "saturday-of-souls", "molieben", "kolivo"]
        ),

        GlossaryEntry(
            slug: "molieben", term: "Molieben", aliases: ["Moleben", "service of supplication"],
            pronunciation: "mo-LYEH-ben",
            short: "A short service of supplication or thanksgiving, to Christ, the Theotokos or a saint.",
            full: """
            A flexible service asking for help or giving thanks — before travel, at the start of a \
            school year, in illness, or in honour of a particular saint. Often served after the \
            Liturgy.

            Any parishioner may ask for one. It is a normal request, not an imposition.
            """,
            category: .services, related: ["panikhida", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "radonitsa", term: "Radonitsa", aliases: ["Day of Rejoicing"],
            pronunciation: "ra-DON-it-sa",
            short: "The Tuesday after Thomas Sunday, when the dead are commemorated with Paschal joy.",
            full: """
            The church does not serve memorials during Bright Week, because the whole week is \
            Pascha. Radonitsa, on the Tuesday after Thomas Sunday, is when the commemoration \
            resumes — and it is done with the Paschal greeting, announcing the Resurrection at the \
            graves.

            Distinctly Slavic, and widely kept: families visit cemeteries that day.
            """,
            category: .calendar, related: ["pascha", "bright-week", "thomas-sunday", "panikhida"]
        ),

        GlossaryEntry(
            slug: "saturday-of-souls", term: "Saturday of Souls", aliases: ["Soul Saturday", "Memorial Saturday"],
            short: "Saturdays set aside in the calendar for commemorating all the departed.",
            full: """
            Several Saturdays in the year are appointed for a general commemoration of the dead, \
            most of them before and during Great Lent. Names of the departed are given in for \
            reading at these services.
            """,
            category: .calendar, related: ["panikhida", "great-lent", "radonitsa"]
        ),

        GlossaryEntry(
            slug: "prostration", term: "Prostration", aliases: ["metania", "bows", "full prostration"],
            short: "Bowing to the ground in prayer — used heavily during Great Lent.",
            full: """
            A full prostration means the sign of the cross, then kneeling and touching the forehead \
            to the ground. A metania, or bow from the waist with the hand touching the floor, is \
            the lesser form.

            Prostrations are not made on Sundays or during the Paschal season, when the church \
            stands to mark the Resurrection. They come thick during Great Lent, especially at the \
            Prayer of Saint Ephraim.

            People with bad knees or backs bow instead, and nobody minds.
            """,
            category: .prayer, related: ["great-lent", "great-canon", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "blessing", term: "Asking a blessing",
            short: "Approaching a priest with cupped hands to receive a blessing.",
            full: """
            The customary greeting to a priest or bishop: hands crossed right over left, palms up, \
            saying "Father, bless". He blesses and you kiss his hand.

            Blessings are also asked before undertakings — travel, a change of work, taking on a \
            larger prayer rule. Asking one is ordinary, and it is how much of Orthodox practice is \
            meant to be settled: in conversation, not alone.
            """,
            category: .things, related: ["prayer-rule", "confession", "preparation-for-communion"]
        ),

        GlossaryEntry(
            slug: "name-day", term: "Name day", aliases: ["patronal feast", "angel day"],
            short: "The feast of the saint whose name you bear — celebrated more than a birthday.",
            full: """
            Orthodox Christians take the name of a saint at baptism, and that saint's feast becomes \
            their name day. In Russian tradition it is often marked more warmly than a birthday: \
            people commune that day, and are congratulated.

            If several saints share your name, your own is usually the one nearest your baptism or \
            the one your priest names.
            """,
            category: .things, related: ["patron-saint", "chrismation", "holy-mysteries"]
        ),

        GlossaryEntry(
            slug: "patron-saint", term: "Patron saint",
            short: "The saint whose name you took, asked for as an intercessor.",
            full: """
            Your patron is asked to pray for you, and their icon usually sits in the icon corner at \
            home. Their life is worth reading — it is the particular example given to you.
            """,
            category: .saints, related: ["name-day", "icon-corner", "chrismation"]
        ),

        GlossaryEntry(
            slug: "catechumen", term: "Catechumen", pronunciation: "kat-eh-KYOO-men",
            short: "Someone being prepared for baptism or reception into the Church.",
            full: """
            A formal state, not just an intention: a catechumen is prayed for by name in the \
            Liturgy and is being instructed toward reception.

            How long it lasts varies — often a year or more. There is no standard timetable, and \
            being told to wait is normal rather than a judgement.
            """,
            category: .things, related: ["chrismation", "godparent", "divine-liturgy"]
        ),

        GlossaryEntry(
            slug: "chrismation", term: "Chrismation",
            short: "Anointing with holy chrism — how most converts are received into the Church.",
            full: """
            Anointing with chrism, a consecrated oil, conferring the gift of the Holy Spirit. It \
            follows baptism immediately, and is also the usual way a Christian baptised elsewhere is \
            received into Orthodoxy.

            Whether a particular convert is baptised or chrismated is a decision for the bishop and \
            priest.
            """,
            category: .things, related: ["catechumen", "godparent", "name-day"]
        ),

        GlossaryEntry(
            slug: "godparent", term: "Godparent", aliases: ["sponsor"],
            short: "The person who stands for you at baptism and answers for you afterwards.",
            full: """
            A godparent makes the baptismal confession on behalf of an infant, or stands with an \
            adult, and is responsible thereafter for their spiritual upbringing.

            For an adult convert the godparent is often the person who has been showing them the \
            ropes, and the relationship usually continues as exactly that.
            """,
            category: .things, related: ["chrismation", "catechumen", "patron-saint"]
        ),

        GlossaryEntry(
            slug: "icon-corner", term: "Icon corner", aliases: ["red corner", "krasny ugol", "beautiful corner"],
            short: "The corner of a home where icons are kept and prayers are said.",
            full: """
            Traditionally the east corner of the main room, holding icons of Christ and the \
            Theotokos and usually a patron saint, with a lampada burning before them.

            It is where the morning and evening prayers of a rule are said. Setting one up is often \
            a newcomer's first concrete step.
            """,
            category: .things, related: ["lampada", "prayer-rule", "patron-saint"]
        ),

        GlossaryEntry(
            slug: "lampada", term: "Lampada", aliases: ["icon lamp", "vigil lamp"],
            short: "The small oil lamp kept burning before icons.",
            full: """
            A hanging or standing lamp burning olive oil before the icons, at home or in church. \
            Many households light it for prayers and on feast days, some keep it burning \
            continually.
            """,
            category: .things, related: ["icon-corner", "iconostasis"]
        ),

        GlossaryEntry(
            slug: "kolivo", term: "Kolivo", aliases: ["koliva", "kutia"],
            short: "Boiled wheat with honey, prepared for memorial services.",
            full: """
            Wheat boiled and sweetened, often with honey, raisins and nuts, blessed at memorial \
            services. The wheat is the image: a seed must fall into the ground and die before it \
            rises.
            """,
            category: .things, related: ["panikhida", "saturday-of-souls"]
        ),

        // MARK: remaining services

        GlossaryEntry(
            slug: "hours", term: "The Hours", aliases: ["First Hour", "Third Hour", "Sixth Hour", "Ninth Hour"],
            short: "Four short services marking points of the day, often read before the Liturgy.",
            full: """
            The First, Third, Sixth and Ninth Hours correspond roughly to 6am, 9am, noon and 3pm. \
            In parish practice the Third and Sixth are usually read immediately before the Divine \
            Liturgy while the clergy prepare.

            If you arrive and hear someone reading psalms before the Liturgy begins, this is what \
            it is.
            """,
            category: .services, related: ["divine-liturgy", "compline", "psalter"]
        ),

        GlossaryEntry(
            slug: "compline", term: "Compline", aliases: ["Great Compline", "Small Compline"],
            short: "The last service of the day, before sleep.",
            full: """
            Small Compline is short and often read at home. Great Compline is a much longer form \
            served on weekdays of Great Lent and on the eves of certain great feasts.
            """,
            category: .services, related: ["great-lent", "hours", "vespers"]
        ),

        GlossaryEntry(
            slug: "psalter", term: "Psalter", aliases: ["kathisma", "kathismata"],
            short: "The Book of Psalms as the church reads it, divided into twenty sections.",
            full: """
            The Psalter is divided into twenty kathismata, read through in the services across a \
            week — and twice a week during Great Lent. Many people also read a kathisma daily as \
            part of a rule.

            The numbering follows the Greek Septuagint, so it is usually one behind the numbering \
            in most English Bibles.
            """,
            category: .scripture, related: ["matins", "vespers", "prayer-rule", "great-lent"]
        ),

        GlossaryEntry(
            slug: "six-psalms", term: "Six Psalms", aliases: ["Hexapsalmos"],
            short: "Six psalms read in near-darkness at the start of Matins, in complete silence.",
            full: """
            Read at the beginning of Matins with the lights lowered and no movement in the church — \
            traditionally one does not walk about or sit during them. They are understood as an \
            image of standing before God at the judgement.
            """,
            category: .services, related: ["matins", "psalter", "vigil"]
        ),

        GlossaryEntry(
            slug: "litya", term: "Litya", pronunciation: "LEE-tya",
            short: "A procession and blessing of bread, wheat, wine and oil at festal vigils.",
            full: """
            Served during the Vigil before a feast. Five loaves are blessed along with wheat, wine \
            and oil, recalling the feeding of the five thousand, and the bread is distributed to \
            those present.
            """,
            category: .services, related: ["vigil", "great-feast", "prosphora"]
        ),

        GlossaryEntry(
            slug: "great-blessing-of-water", term: "Great Blessing of Water", aliases: ["Theophany water", "blessing of the waters"],
            short: "The blessing of water at Theophany, taken home and kept through the year.",
            full: """
            Served at Theophany, when a cross is immersed in the water and it is blessed with a long \
            set of prayers. People take it home, drink a little of it, and keep it — traditionally \
            it does not spoil.

            Priests also bless homes with it in the weeks after the feast.
            """,
            category: .services, related: ["theophany", "great-feast"]
        ),

        // MARK: the remaining Great Feasts

        GlossaryEntry(
            slug: "palm-sunday", term: "Palm Sunday", aliases: ["Entry into Jerusalem"],
            short: "Christ's entry into Jerusalem, the Sunday before Pascha.",
            full: """
            One of the Great Feasts. Willow branches are usually blessed and held in Slavic practice \
            rather than palms, which is why it is sometimes called Willow Sunday. It opens Holy Week.
            """,
            category: .calendar, related: ["great-feast", "holy-week", "pascha"]
        ),

        GlossaryEntry(
            slug: "holy-week", term: "Holy Week", aliases: ["Passion Week", "Great Week"],
            short: "The week between Palm Sunday and Pascha, the most intense of the year.",
            full: """
            Services almost every day, following the events of Christ's passion. The great ones are \
            the Bridegroom Matins early in the week, the Twelve Passion Gospels on Thursday evening, \
            the Burial Shroud on Friday, and the Paschal service late on Saturday night.

            Attendance expectations vary and few people manage everything. Going to what you can is \
            the ordinary case.
            """,
            category: .calendar, related: ["pascha", "palm-sunday", "great-lent", "bright-week"]
        ),

        GlossaryEntry(
            slug: "ascension", term: "Ascension",
            short: "Christ's ascent into heaven, forty days after Pascha.",
            full: """
            A Great Feast, and always a Thursday, because it falls forty days after Pascha. Christ \
            blesses the disciples and is taken up; they are told he will return in the same way.

            The ten days between Ascension and Pentecost are the church's brief interval of waiting.
            """,
            category: .calendar, related: ["great-feast", "pascha", "pentecost"]
        ),

        GlossaryEntry(
            slug: "elevation-of-the-cross", term: "Elevation of the Cross", aliases: ["Exaltation of the Cross", "Universal Elevation"],
            short: "The finding and raising of the Cross, kept on 14 September with a strict fast.",
            full: """
            A Great Feast commemorating the discovery of the Cross in Jerusalem. Unusually for a \
            feast, it is kept as a strict fast day — the Cross is venerated with mourning rather \
            than feasting.
            """,
            category: .calendar, related: ["great-feast", "wednesday-friday-fast"]
        ),

        GlossaryEntry(
            slug: "entry-into-the-temple", term: "Entry of the Theotokos into the Temple", aliases: ["Entry into the Temple", "Presentation of the Theotokos"],
            short: "The Theotokos brought to the Temple as a child, kept on 21 November.",
            full: """
            A Great Feast of the Theotokos, falling within the Nativity Fast. Her parents bring her \
            to the Temple as a small child to be raised there, in fulfilment of a vow.

            Because it lands inside a fast, the fast is relaxed for the day rather than lifted.
            """,
            category: .calendar, related: ["theotokos", "great-feast", "nativity-fast"]
        ),

        GlossaryEntry(
            slug: "meeting-of-the-lord", term: "Meeting of the Lord", aliases: ["Presentation of Christ", "Candlemas", "Sretenie"],
            short: "The infant Christ met by Simeon in the Temple, kept on 2 February.",
            full: """
            A Great Feast, forty days after the Nativity. The elder Simeon takes the child in his \
            arms and says the words the church sings at every Vespers: "Now lettest thou thy servant \
            depart in peace."
            """,
            category: .calendar, related: ["great-feast", "nativity", "vespers"]
        ),

        GlossaryEntry(
            slug: "nativity-of-the-theotokos", term: "Nativity of the Theotokos",
            short: "The birth of the Virgin Mary, kept on 8 September.",
            full: """
            A Great Feast, and the first of the twelve in the church year — which begins on \
            1 September, not in January.

            The year therefore opens with the birth of the Theotokos and closes with her Dormition.
            """,
            category: .calendar, related: ["theotokos", "great-feast", "church-new-year"]
        ),

        GlossaryEntry(
            slug: "church-new-year", term: "Church New Year", aliases: ["Indiction", "ecclesiastical new year"],
            short: "The church year begins on 1 September, not in January.",
            full: """
            The liturgical year runs from 1 September, so the first Great Feast of the year is the \
            Nativity of the Theotokos and the last is her Dormition — the year opens with her birth \
            and closes with her falling asleep.
            """,
            category: .calendar, related: ["nativity-of-the-theotokos", "dormition", "great-feast"]
        ),

        GlossaryEntry(
            slug: "pokrov", term: "Pokrov", aliases: ["Protection of the Theotokos", "Intercession of the Theotokos"],
            pronunciation: "po-KROF",
            short: "The Protection of the Theotokos, beloved in Slavic practice, kept on 1 October.",
            full: """
            Commemorates the appearance of the Theotokos at Blachernae in Constantinople, spreading \
            her veil over the people as a sign of protection.

            Not one of the Twelve Great Feasts, but among the most loved feasts in Russian and \
            Slavic practice — many parishes and monasteries are dedicated to it.
            """,
            category: .calendar, related: ["theotokos", "great-feast", "rocor"]
        ),

        GlossaryEntry(
            slug: "sunday-of-orthodoxy", term: "Sunday of Orthodoxy", aliases: ["Triumph of Orthodoxy"],
            short: "The first Sunday of Great Lent, marking the restoration of the icons.",
            full: """
            Commemorates the end of the iconoclast controversy in 843 and the restoration of icons to \
            the churches. Parishes usually hold a procession in which everyone carries an icon.
            """,
            category: .calendar, related: ["great-lent", "iconostasis"]
        ),

        GlossaryEntry(
            slug: "thomas-sunday", term: "Thomas Sunday", aliases: ["Antipascha", "St Thomas Sunday"],
            short: "The Sunday after Pascha, when Thomas touches the risen Christ.",
            full: """
            Also called Antipascha — not "against Pascha" but "in place of", because it repeats the \
            Paschal celebration a week on. It closes Bright Week. Radonitsa follows two days later.
            """,
            category: .calendar, related: ["pascha", "bright-week", "radonitsa"]
        )
    ]
}
