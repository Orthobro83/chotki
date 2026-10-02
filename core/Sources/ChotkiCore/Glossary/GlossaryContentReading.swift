import Foundation

// Ported verbatim from the Android overhaul; religious wording is not newly authored here.
extension Glossary {
    static let readingWords: [GlossaryEntry] = [
        GlossaryEntry(
            slug: "kathisma",
            term: "Kathisma",
            aliases: ["kathismata", "kathismas"],
            pronunciation: "kah-THEES-mah",
            short: "One of the twenty sections of the Psalter.",
            full: "The Orthodox Psalter is divided into twenty parts so it can be read through in the course of a week. Each part is a kathisma, from the Greek for sitting: the portion is long enough that the church sits to hear it.\n\nA kathisma is not one psalm. Most hold several. The seventeenth is Psalm 118 on its own, because that psalm is long enough to be a sitting by itself. Psalm 151 belongs to none of them.\n\nAt Vespers and Matins the church appoints which kathismata are read. A rule of one kathisma a day means one of these sections, not the whole book.",
            category: .scripture,
            related: ["psalter", "vespers", "matins"]
        ),
        GlossaryEntry(
            slug: "pause",
            term: "Pause",
            aliases: ["Selah", "Diapsalma"],
            pronunciation: "SEE-lah",
            short: "A musical mark in the Psalms. This Psalter prints it as \"Pause.\"",
            full: "Where a verse here ends with \"Pause.\", the Hebrew has Selah and the Greek has diapsalma. What the singers were meant to do is no longer known. It may be a rest, a lift in the melody, or a place where instruments played alone.\n\nIt is not a word of the prayer. You do not address it to God. It marks a break in the psalm, and then the psalm goes on.",
            category: .scripture,
            related: ["psalter"]
        ),
        GlossaryEntry(
            slug: "song-of-degrees",
            term: "Song of Degrees",
            aliases: ["Songs of Degrees", "Song of Ascents", "Songs of Ascents"],
            short: "One of fifteen psalms sung going up to Jerusalem.",
            full: "Fifteen psalms in a row — 119 to 133 in this Psalter, 120 to 134 in many Bibles — are headed \"A Song of Degrees.\" Degrees means steps. They were sung on the way up to Jerusalem, or up the steps of the Temple.\n\nThey are short. Most of them are about the road, the city, and coming home.",
            category: .scripture,
            related: ["sion", "psalter", "tabernacle"]
        ),
        GlossaryEntry(
            slug: "alleluia",
            term: "Alleluia",
            aliases: ["Hallelujah"],
            pronunciation: "ah-leh-LOO-yah",
            short: "Hebrew for \"praise the Lord.\"",
            full: "Alleluia is two Hebrew words kept untranslated: hallelu, praise, and Yah, the name of God. The Church kept the word itself, as it kept Amen.\n\nYou will meet it in the Psalms and between readings at the Liturgy. Through most of Great Lent the services set it aside, and it returns at Pascha.",
            category: .prayer,
            related: ["pascha", "great-lent", "psalter"]
        ),
        GlossaryEntry(
            slug: "sion",
            term: "Sion",
            aliases: ["Zion"],
            pronunciation: "ZYE-on",
            short: "The Temple hill in Jerusalem, and a name for God's people.",
            full: "Sion — Zion in most newer Bibles — is the hill in Jerusalem where the Temple stood. The Psalms use it for the city, for the place God is worshipped, and for the people who belong to Him.\n\n\"The daughter of Sion\" is not a woman. It is the city, spoken of as a daughter. \"Out of Sion\" means from that holy place.",
            category: .scripture,
            related: ["psalter", "tabernacle"]
        ),
        GlossaryEntry(
            slug: "hades",
            term: "Hades",
            aliases: ["Sheol"],
            pronunciation: "HAY-deez",
            short: "The realm of the dead, as the Psalms mean it.",
            full: "In the Psalms, Hades is where the dead go down. The Hebrew word is Sheol. It is the grave, the land of the departed, not a picture of punishment.\n\nWhen a psalm says a soul was brought up from Hades, it means the person was rescued from death. The Church also says that at His death Christ descended into Hades and broke it open. That is not the same sentence as saying someone was condemned.",
            category: .scripture,
            related: ["pascha", "psalter"]
        ),
        GlossaryEntry(
            slug: "for-the-end",
            term: "For the end",
            aliases: ["Eis to telos"],
            pronunciation: "ice toh TEH-los",
            short: "A heading on many psalms in the Greek Old Testament.",
            full: "Many psalms here begin \"For the end.\" That is the Greek eis to telos. It translates a Hebrew note, lamnatzeach, which most English Bibles give as \"for the choir director.\"\n\nThe Greek says \"for the end\" instead. Christian readers have often taken the phrase as pointing to Christ, called the end — the fulfilment — of the law. Either way it is a heading, not the first line of the prayer. The psalm itself begins after it.",
            category: .scripture,
            related: ["psalter", "septuagint"]
        ),
        GlossaryEntry(
            slug: "septuagint",
            term: "Septuagint",
            aliases: ["LXX"],
            pronunciation: "sep-TOO-uh-jint",
            short: "The ancient Greek translation of the Old Testament.",
            full: "The Septuagint is the Greek Old Testament, made in the centuries before Christ. Its name means seventy, from the tradition that seventy scholars produced it. The Orthodox Church reads the Old Testament from this Greek text, not from a later Hebrew one.\n\nThe Psalms in this app are Brenton's English of that Greek. A psalm's number, and some of its headings, therefore differ from a Bible translated from Hebrew. Neither numbering is a mistake. They are two editions.",
            category: .scripture,
            related: ["psalter"]
        ),
        GlossaryEntry(
            slug: "tabernacle",
            term: "Tabernacle",
            aliases: ["Tent of witness"],
            short: "The tent where Israel worshipped before there was a Temple.",
            full: "Before Solomon built the Temple, Israel kept the ark and offered worship in a tent, the Tabernacle. The Psalms still speak of it, and later of the Temple, as the place where God meets His people.\n\nA heading about \"the Tabernacle\" is about that worship. It is not a modern church hall.",
            category: .scripture,
            related: ["sion", "psalter"]
        ),
        GlossaryEntry(
            slug: "asaph",
            term: "Asaph",
            pronunciation: "AY-saf",
            short: "A Levite choirmaster. His name heads a group of psalms.",
            full: "Asaph led the singing in the time of David and Solomon. He was of the tribe of Levi, the tribe set aside for the Temple's service. Twelve psalms are headed as his, or for him. They may be his own, or they may belong to the guild of singers who kept his name.\n\nThe heading says which choir the psalm was given to. It is not part of the prayer.",
            category: .scripture,
            related: ["psalter", "sons-of-core", "tabernacle"]
        ),
        GlossaryEntry(
            slug: "sons-of-core",
            term: "Sons of Core",
            aliases: ["Sons of Korah", "sons of Core"],
            pronunciation: "KOR-ah",
            short: "A family of Temple singers. Their name heads a group of psalms.",
            full: "Core is the Greek spelling of Korah. His descendants were Levites who sang at the Temple, and a number of psalms are headed \"for the sons of Core.\" That means the psalm was theirs to sing.\n\nIn a heading, the name is the choir. It is not part of the prayer.",
            category: .scripture,
            related: ["asaph", "psalter", "tabernacle"]
        ),
        GlossaryEntry(
            slug: "idithun",
            term: "Idithun",
            aliases: ["Jeduthun"],
            pronunciation: "JED-uh-thun",
            short: "One of David's chief musicians.",
            full: "Idithun — Jeduthun in Hebrew Bibles — was a Levite musician beside Asaph. \"For Idithun\" on a psalm gives it to his choir. Like the other musical headings, it is not a line you pray.",
            category: .scripture,
            related: ["asaph", "psalter"]
        ),
        GlossaryEntry(
            slug: "gentiles",
            term: "Gentiles",
            aliases: ["heathen"],
            short: "The peoples other than Israel.",
            full: "A Gentile is someone from the nations, not of Israel. This Psalter often says \"the heathen\" for the same peoples.\n\nIn the Church the word is not an insult. The Psalms that call the nations to worship are read as having come about, because the Gospel went out to them.",
            category: .scripture,
            related: ["psalter"]
        ),
        GlossaryEntry(
            slug: "heavenly-king",
            term: "Heavenly King",
            aliases: ["O Heavenly King"],
            short: "The short prayer to the Holy Spirit that begins many rules.",
            full: "\"O Heavenly King\" is addressed to the Holy Spirit: the Comforter, the Spirit of truth, everywhere present and filling all things. Morning and evening prayers usually open with it, and then go on to the Trisagion and the Our Father.\n\nFrom Pascha until Pentecost it is left unsaid. In those days the Church greets the Resurrection first, and takes this prayer up again when Pentecost comes.",
            category: .prayer,
            related: ["comforter", "trisagion", "holy-trinity", "pentecost", "pascha"]
        ),
        GlossaryEntry(
            slug: "it-is-truly-meet",
            term: "It is truly meet",
            aliases: ["Axion Estin", "It is truly meet to bless thee"],
            pronunciation: "AX-ee-on ES-tin",
            short: "A hymn in praise of the Theotokos.",
            full: "\"It is truly meet to bless thee, O Theotokos\" calls her more honourable than the cherubim and more glorious beyond compare than the seraphim. The Greek opening, Axion estin, means \"it is worthy.\"\n\nIt is sung at the Divine Liturgy after the holy gifts have been consecrated, unless the feast appoints another hymn in its place. It also stands near the end of the morning and evening prayers.",
            category: .prayer,
            related: ["theotokos", "divine-liturgy", "cherubim", "seraphim"]
        ),
        GlossaryEntry(
            slug: "compunction",
            term: "Compunction",
            short: "Sorrow for one's sins that softens the heart.",
            full: "Compunction is not gloom, and it is not shame kept for its own sake. It is the sting of seeing that one has done wrong, and the softening that lets a person pray instead of defending himself. A psalm says \"feel compunction upon your beds.\"\n\nThe Church treats it as something to ask for, especially in Lent, not as a mood to force.",
            category: .prayer,
            related: ["great-lent", "confession"]
        ),
        GlossaryEntry(
            slug: "hyssop",
            term: "Hyssop",
            pronunciation: "HISS-up",
            short: "A small plant used to sprinkle water for cleansing.",
            full: "Hyssop is a bushy herb. In Israel's worship a bunch of it sprinkled the blood of the Passover and the water that declared a person clean. \"Purge me with hyssop\" in the Psalms means \"cleanse me.\" It is not a recipe.\n\nThe plant is ordinary. The meaning is the washing.",
            category: .scripture,
            related: ["psalter"]
        ),
        GlossaryEntry(
            slug: "aggaeus-and-zacharias",
            term: "Aggæus and Zacharias",
            aliases: ["Haggai and Zechariah", "Aggaeus and Zacharias"],
            pronunciation: "AG-ay-us, zak-uh-RYE-us",
            short: "Two prophets named in the headings of a few psalms.",
            full: "Aggæus and Zacharias are Haggai and Zechariah, prophets after the exile who pressed Israel to rebuild the Temple. A few psalms in the Greek Psalter are headed with their names. The heading ties the psalm to that time, the return and the rebuilding. It is not a line of the prayer.",
            category: .scripture,
            related: ["tabernacle", "sion", "psalter", "septuagint"]
        ),
    ]
}
