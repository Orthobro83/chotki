import Foundation

// The words a newcomer meets in the prayers themselves.
//
// The rest of the glossary grew out of the calendar — feasts, fasts, service
// names. Scanning the bundled prayers against it found exactly one term the
// reader could look up, which made the prayer screens linkable in principle and
// useless in practice. These entries close that gap: every one of them appears
// in a prayer this app displays.
//
// Same caveat as the rest of the glossary. This is introductory, written to get
// someone through their first months, and it is not a substitute for a priest.
extension Glossary {

    static let prayerWords: [GlossaryEntry] = [

        // MARK: praying

        GlossaryEntry(
            slug: "amen", term: "Amen",
            pronunciation: "AH-meen",
            short: "A Hebrew word meaning \"so be it\" — agreement with what has just been said.",
            full: """
            Amen is not punctuation. It is assent: the person praying puts their name to the \
            words, and means them.

            This is clearest in the services, where the priest prays and the people answer \
            "Amen". The prayer is not finished until they have agreed to it. Said alone at the \
            end of a prayer, it does the same thing more quietly.

            It is one of a handful of words the Church never translated, kept in Hebrew from \
            the beginning.
            """,
            category: .prayer, related: ["divine-liturgy", "prayer-rule"]
        ),

        GlossaryEntry(
            slug: "thee-and-thou", term: "Thee, Thou and Thy",
            aliases: ["Thou", "Thee", "Thy", "Thine"],
            short: "The old English forms kept in prayer. They mean \"you\" and \"your\", to one person.",
            full: """
            Thou is the subject — Thou art, Thou hast. Thee is the object — we praise Thee. \
            Thy and Thine are the possessives, thine before a vowel. Verbs that follow thou \
            usually end in -est, and third-person verbs in -eth: He giveth.

            These are often heard as stiff or formal. They are the reverse. In older English \
            thou was the singular and familiar form, used with one person you were close to, \
            and "you" was the plural and the distant one. It survives in prayer partly by \
            habit of translation, but it does something the modern word cannot: it keeps the \
            address unmistakably singular. God is spoken to as one, and as near.

            Nothing turns on using it. Many English-speaking Orthodox pray in modern English, \
            and both are in print.
            """,
            category: .prayer, related: ["church-slavonic", "prayer-rule"]
        ),

        // MARK: the faith

        GlossaryEntry(
            slug: "holy-trinity", term: "Holy Trinity",
            aliases: ["Trinity", "Most Holy Trinity"],
            short: "One God in three persons — Father, Son and Holy Spirit.",
            full: """
            The Church confesses one God in three persons: Father, Son and Holy Spirit, of one \
            essence and undivided. Not three Gods, and not one person appearing in three \
            guises — three who are distinct, and one God.

            It is the shape of almost everything said in the services. Prayers commonly end by \
            glorifying all three together, "now and ever, and unto ages of ages". The three \
            joined fingers of the sign of the cross confess the same thing before a word is \
            said.

            The doctrine is not an explanation. It is a description of what was revealed, held \
            to without being resolved into something more manageable.
            """,
            category: .faith, related: ["symbol-of-faith", "trisagion", "comforter"]
        ),

        GlossaryEntry(
            slug: "symbol-of-faith", term: "Symbol of Faith",
            aliases: ["Nicene Creed", "Creed", "Nicene-Constantinopolitan Creed"],
            short: "The statement of belief agreed in 325 and 381, said at every Liturgy.",
            full: """
            Agreed at the council of Nicaea in 325 and completed at Constantinople in 381, in \
            answer to disputes about who Christ is. "Symbol" here means a token or badge — the \
            thing you produce to show whose you are.

            It is said by everyone at the Divine Liturgy, and it stands in the morning rule of \
            most prayer books. Learning it by heart is usually the first thing a catechumen is \
            asked to do.

            The Orthodox text is the original one. The Western version adds "and the Son" to \
            the clause on the procession of the Holy Spirit — the Filioque — which the \
            Orthodox churches have never accepted. It is the single best-known difference \
            between the two texts.
            """,
            category: .faith, related: ["holy-trinity", "divine-liturgy", "catechumen"]
        ),

        GlossaryEntry(
            slug: "comforter", term: "Comforter",
            // No "The Comforter": the longest needle wins, and an underline that
            // starts on "the" looks like a mistake.
            aliases: ["Paraclete"],
            short: "A title of the Holy Spirit: the one called to your side.",
            full: """
            The Greek is Parakletos — one called alongside, to stand with someone and speak for \
            them. English versions render it Comforter, Advocate, or Helper, and none of them \
            quite carries it.

            Comforter is the oldest of those, and it is worth knowing that "comfort" once meant \
            to strengthen rather than to soothe — the same root as fortify. The prayer "O \
            Heavenly King", which opens most rules, addresses the Holy Spirit by this name.
            """,
            category: .faith, related: ["holy-trinity"]
        ),

        GlossaryEntry(
            slug: "only-begotten", term: "Only-begotten",
            aliases: ["Only-begotten Son", "Only begotten"],
            short: "A title of Christ — the Son born of the Father, not made by Him.",
            full: """
            The Greek is monogenes: the only one of His kind. The Creed spells out what it \
            guards against — "begotten, not made" — because to call the Son made would put Him \
            on the creature's side of the line.

            Begetting here has nothing to do with time or with bodies. It says the Son is of \
            the Father's own being, eternally, as light is of a flame.
            """,
            category: .faith, related: ["symbol-of-faith", "holy-trinity"]
        ),

        // MARK: angels

        GlossaryEntry(
            slug: "cherubim", term: "Cherubim",
            aliases: ["Cherub", "Cherubims"],
            pronunciation: "CHAIR-oo-vim",
            short: "One of the highest ranks of angels, named constantly in the hymns.",
            full: """
            Angels are traditionally spoken of in nine ranks, drawn from Scripture and set out \
            by Saint Dionysius. Cherubim and Seraphim are the two nearest to God, and so they \
            are the ones the hymns reach for when they want to say "higher than anything \
            created".

            That is the force of the line said daily of the Mother of God: more honourable than \
            the Cherubim, and beyond compare more glorious than the Seraphim. It is not a \
            comparison of ranks so much as a way of saying there is nothing left to compare \
            her to.
            """,
            category: .saints, related: ["seraphim", "theotokos", "guardian-angel"]
        ),

        GlossaryEntry(
            slug: "seraphim", term: "Seraphim",
            aliases: ["Seraph", "Seraphims"],
            pronunciation: "SER-a-fim",
            short: "The angels Isaiah saw around the throne, crying \"Holy, holy, holy\".",
            full: """
            The name means the burning ones. Isaiah saw them above the throne, each with six \
            wings, calling to one another "Holy, holy, holy is the Lord of hosts" — the cry the \
            Church still takes up at the Liturgy.

            With the Cherubim they are the highest of the angelic ranks, which is why the two \
            are so often named together.
            """,
            category: .saints, related: ["cherubim", "theotokos"]
        ),

        GlossaryEntry(
            slug: "guardian-angel", term: "Guardian Angel",
            short: "The angel given to watch over a person, addressed at the end of the evening prayers.",
            full: """
            It is the common teaching that each person is given an angel to guard them, and \
            most prayer books close the evening rule with a short prayer to one's own — asking \
            forgiveness for having grieved him during the day, and his covering through the \
            night.

            The ground for it is Christ's word that the angels of the little ones always behold \
            the face of the Father.
            """,
            category: .saints, related: ["cherubim", "prayer-rule"]
        ),

        // MARK: people in the prayers

        GlossaryEntry(
            slug: "publican", term: "Publican",
            aliases: ["tax collector"],
            short: "A tax collector — in the parable, the man whose prayer is the model for ours.",
            full: """
            Publicans collected taxes for Rome from their own people, and were despised for it.

            In the parable, one goes up to the temple to pray beside a Pharisee. The Pharisee \
            thanks God for what he is not. The publican will not lift his eyes, and says only: \
            God be merciful to me a sinner. Christ says it was the publican who went home \
            justified.

            Those few words are prayed in their own right, often on the rope, and the parable \
            opens the weeks of preparation before Great Lent.
            """,
            category: .scripture, related: ["jesus-prayer", "great-lent", "chotki"]
        ),

        GlossaryEntry(
            slug: "saint-ephrem", term: "Saint Ephrem the Syrian",
            aliases: ["Ephrem", "Saint Ephraim", "Ephraim the Syrian", "Ephraim"],
            pronunciation: "EF-rem",
            short: "A fourth-century deacon and poet, whose Lenten prayer is said with prostrations.",
            full: """
            He lived in Nisibis and then Edessa, and died in 373. A deacon rather than a \
            priest, and above all a hymnographer: much of what he wrote was sung.

            His prayer — O Lord and Master of my life — is said at nearly every service of \
            Great Lent, and by many at home through the fast. It asks to be spared the spirit \
            of sloth, faint-heartedness, lust of power and idle talk, and given instead \
            chastity, humility, patience and love. Prostrations are made with it.
            """,
            category: .saints, related: ["great-lent", "prostration", "prayer-rule"]
        ),

        GlossaryEntry(
            slug: "saint-macarius", term: "Saint Macarius the Great",
            aliases: ["Macarius", "Saint Macarius of Egypt", "Macarius of Egypt"],
            pronunciation: "ma-KAR-ee-us",
            short: "A fourth-century desert father. Several of the morning prayers carry his name.",
            full: """
            He went into the Egyptian desert at Scetis in the fourth century and spent sixty \
            years there. He is one of the fathers whose sayings make up the desert collections.

            The morning rule in Slavic prayer books opens with prayers attributed to him. As \
            with much ancient material, the attribution is traditional rather than certain, \
            which changes nothing about how the prayers are used.
            """,
            category: .saints, related: ["prayer-rule"]
        ),

        GlossaryEntry(
            slug: "saint-ioannikios", term: "Saint Ioannikios the Great",
            aliases: ["Ioannikios", "Saint Joannicius", "Joannicius"],
            pronunciation: "yo-a-NEE-kee-os",
            short: "A ninth-century ascetic. His one-line prayer closes the evening rule.",
            full: """
            A soldier who became a monk on Mount Olympus in Bithynia, and one of the defenders \
            of the icons during the second iconoclast persecution. He died in 846.

            The prayer that carries his name is a single sentence — my hope is the Father, my \
            refuge the Son, my protection the Holy Spirit — and it stands at the very end of \
            the evening prayers, after everything else has been said.
            """,
            category: .saints, related: ["holy-trinity", "prayer-rule"]
        ),
    ]
}
