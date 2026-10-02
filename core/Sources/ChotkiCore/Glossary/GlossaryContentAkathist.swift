import Foundation

// Words of the Akathist that a newcomer would have no way to decode from the
// sentence alone. The hymn is linked where these words appear. Thee and thou
// are already explained, and a metaphor that is plain English is left alone.
extension Glossary {

    static let akathistWords: [GlossaryEntry] = [

        GlossaryEntry(
            slug: "bride-unwedded", term: "Bride unwedded", aliases: ["unwedded"],
            short: "A title of Mary: a mother, and still a virgin.",
            full: """
            The refrain of the Akathist. It means she gave birth and remained a virgin. \
            The Church's word for this is ever-virgin.

            Joseph was her betrothed. "Unwedded" is not a claim that she had no husband. \
            It is about how she conceived.
            """,
            category: .faith, related: ["theotokos", "annunciation", "akathist"]
        ),
        GlossaryEntry(
            slug: "incarnation", term: "Incarnation", aliases: ["incarnate", "Incarnating"],
            pronunciation: "in-kar-NAY-shun",
            short: "God the Son taking human nature, and being born.",
            full: """
            The Son of God became man without ceasing to be God. "Incarnate" means in the flesh. \
            The hymn's "Incarnating" is the same word.

            It is the event the Nativity celebrates, and the reason Mary is called Mother of God: \
            the one she bore is God in the flesh.
            """,
            category: .faith, related: ["theotokos", "nativity", "annunciation"]
        ),
        GlossaryEntry(
            slug: "holy-ghost", term: "Holy Ghost", aliases: ["Holy Spirit"],
            short: "The Holy Spirit, the third person of the Trinity.",
            full: """
            Older English says Ghost where newer English says Spirit. It is the same person, \
            not a ghost in the later sense of someone who has died.

            In this hymn the Holy Ghost is the one by whom Christ was conceived.
            """,
            category: .faith, related: ["holy-trinity", "comforter", "annunciation"]
        ),
        GlossaryEntry(
            slug: "oblation", term: "Oblation", aliases: ["oblations"],
            pronunciation: "ob-LAY-shun",
            short: "Something offered to God.",
            full: """
            An oblation is a gift set apart for God. In the Temple it was a sacrifice. In the \
            Church it is, above all, the bread and wine of the Liturgy, and what is offered with them.

            The hymn calls Mary an oblation for the whole world: the one through whom Christ, \
            the offering, was given.
            """,
            category: .prayer, related: ["prosphora", "divine-liturgy", "theotokos"]
        ),
        GlossaryEntry(
            slug: "intercession", term: "Intercession",
            pronunciation: "in-ter-SESH-un",
            short: "Asking God on someone else's behalf.",
            full: """
            To intercede is to stand before God for another person. The Church asks the saints, \
            and above all the Mother of God, to intercede.

            The hymn's "incense of intercession" is that prayer, spoken of as incense rising.
            """,
            category: .prayer, related: ["theotokos", "akathist"]
        ),
        GlossaryEntry(
            slug: "paradise", term: "Paradise",
            short: "The garden of God, and the place Christ promised the thief.",
            full: """
            Paradise is the garden where Adam and Eve were placed, and the name Christ used for \
            where the repentant thief would be with him that day.

            The hymn says Mary opens its gates: through her Son the way back is opened. It is \
            not a loose word for heaven in general, though the two are often spoken of together.
            """,
            category: .faith, related: ["pascha", "hades"]
        ),
        GlossaryEntry(
            slug: "resurrection", term: "Resurrection",
            short: "Christ's rising from the dead.",
            full: """
            The Resurrection is Christ rising, body and all, on the third day. Pascha is the feast \
            of it. The same word is used for the rising promised to everyone.

            A "type" of the Resurrection is an earlier image of that rising, not the rising itself.
            """,
            category: .faith, related: ["pascha"]
        ),
        GlossaryEntry(
            slug: "manna", term: "Manna",
            pronunciation: "MAN-uh",
            short: "The bread God gave Israel in the desert.",
            full: """
            When Israel was in the wilderness, bread appeared on the ground each morning. They \
            called it manna. Christ later called himself the true bread from heaven.

            The hymn sets Mary in that line: the one through whom that bread came into the world.
            """,
            category: .scripture, related: ["tabernacle"]
        ),
        GlossaryEntry(
            slug: "magi", term: "Magi", aliases: ["Wise Men"],
            pronunciation: "MAY-jye",
            short: "The wise men from the East who came to the child Christ.",
            full: """
            The Magi were scholars of the East who followed a star to Bethlehem and brought gold, \
            frankincense and myrrh. The hymn also calls them the sons of the Chaldees and, once \
            they had left Herod, the King's messengers.

            "Wise Men" is the same people.
            """,
            category: .scripture, related: ["nativity", "chaldees"]
        ),
        GlossaryEntry(
            slug: "chaldees", term: "Chaldees", aliases: ["Chaldeans"],
            pronunciation: "KAL-deez",
            short: "The people of the country the Magi came from.",
            full: """
            Chaldea was in the south of what is now Iraq, around Babylon. The hymn calls the Magi \
            the sons of the Chaldees: the same men, named by their country. They are not a second group.
            """,
            category: .scripture, related: ["magi", "nativity"]
        ),
        GlossaryEntry(
            slug: "laver", term: "Laver",
            pronunciation: "LAY-ver",
            short: "A basin for washing, and a name for baptism.",
            full: """
            In the Temple a laver was the great basin the priests washed in. The Church uses the \
            word for baptism, the washing that cleanses the conscience.

            The hymn calls Mary a laver in that sense: through the child she bore, that washing came.
            """,
            category: .scripture, related: ["font", "holy-mysteries"]
        ),
        GlossaryEntry(
            slug: "font", term: "Font",
            short: "The basin baptism is done in.",
            full: """
            The font holds the water of baptism. The hymn says Mary traced, from her own life, \
            the image of that font: her bearing God in the flesh is set beside the washing that \
            joins a person to Christ.
            """,
            category: .things, related: ["laver", "holy-mysteries"]
        ),
        GlossaryEntry(
            slug: "uncircumscribed", term: "Uncircumscribed",
            pronunciation: "un-SUR-kum-skrybd",
            short: "Not enclosed by any place or limit.",
            full: """
            To circumscribe something is to draw a boundary around it. God is uncircumscribed: \
            no place holds him.

            The hymn says the Uncircumscribed Word was wholly with those on earth and still not \
            absent from heaven. Being born did not move him from one place to another. It was a \
            descent, not a change of address.
            """,
            category: .faith, related: ["incarnation", "holy-trinity"]
        ),
        GlossaryEntry(
            slug: "bodiless", term: "Bodiless",
            short: "Without a body. Said of the angels.",
            full: """
            Angels are persons without flesh. The hymn says the angel cried to Mary with a \
            bodiless voice: a real voice, and not one made by a mouth.

            It is the ordinary way the Church speaks of the angels.
            """,
            category: .faith, related: ["guardian-angel"]
        ),
        GlossaryEntry(
            slug: "salutation", term: "Salutation",
            short: "A greeting. Here, the one Mary brought to Elizabeth.",
            full: """
            A salutation is a greeting. In this hymn it is the one Mary gave Elizabeth, whose \
            unborn child leapt when he heard it.

            The Greek name of these Friday services, the Salutations, is the same word: the \
            "Hail" repeated through the hymn.
            """,
            category: .prayer, related: ["annunciation", "theotokos", "akathist"]
        ),
        GlossaryEntry(
            slug: "quires", term: "Quires", aliases: ["Quire"],
            pronunciation: "KWIREZ",
            short: "An old spelling of choirs.",
            full: """
            "Quires of Angels" means choirs of angels, companies of them singing. It does not \
            mean gatherings of paper. The spelling is the one the translation kept.
            """,
            category: .prayer, related: ["alleluia"]
        ),
        GlossaryEntry(
            slug: "supernal", term: "Supernal",
            pronunciation: "soo-PUR-nul",
            short: "From above; belonging to heaven.",
            full: """
            Supernal means what comes from above, as against what is earthly. The Supernal Light \
            in the hymn is the light of God, which Mary is said to kindle for those in darkness.
            """,
            category: .faith, related: ["transfiguration"]
        ),
        GlossaryEntry(
            slug: "incorruption", term: "Incorruption",
            short: "Freedom from decay, and from the ruin of death.",
            full: """
            Corruption here is not mainly bad behaviour. It is decay, the way a body breaks down, \
            and the ruin that entered human life. Incorruption is the opposite: what does not decay.

            The hymn calls Mary the flower of it, because the child she bore passed through death \
            and did not stay dead.
            """,
            category: .faith, related: ["resurrection", "pascha"]
        ),
        GlossaryEntry(
            slug: "ark", term: "Ark",
            short: "The gold-covered chest of the holy things, and a title of Mary.",
            full: """
            Two arks appear in Scripture. Noah's ark was the ship. The Ark of the Covenant was \
            the chest, covered in gold, that held the manna and the tablets and stood in the Tabernacle.

            The hymn means the second. It calls Mary an ark because God came to dwell in her, as \
            his presence had dwelt over that chest.
            """,
            category: .scripture, related: ["tabernacle", "manna", "theotokos"]
        ),
        GlossaryEntry(
            slug: "gabriel", term: "Gabriel",
            pronunciation: "GAY-bree-ul",
            short: "The angel who told Mary she would bear Christ.",
            full: """
            Gabriel is the angel sent to Mary. His message is the Annunciation, and the hymn \
            opens with him crying "Hail" to her.

            He is an angel, not a saint who was once a man.
            """,
            category: .saints, related: ["annunciation", "theotokos"]
        ),
        GlossaryEntry(
            slug: "ineffable", term: "Ineffable",
            pronunciation: "in-EFF-uh-bul",
            short: "Too great to be put into words.",
            full: """
            Ineffable means what cannot be spoken adequately. The hymn uses it of God's counsel \
            and of Christ's wisdom: not hidden for the sake of secrecy, but more than words can hold.
            """,
            category: .faith, related: ["holy-trinity"]
        ),
        GlossaryEntry(
            slug: "champion-leader", term: "Champion Leader",
            short: "A title of Mary as the one who defends her city.",
            full: """
            The opening of the Akathist calls her the Champion Leader. The Greek is a military \
            title: the commander who fights in front. The city speaking is Constantinople, giving \
            thanks for a deliverance.

            The title stayed in the hymn after that occasion had passed.
            """,
            category: .faith, related: ["theotokos", "akathist"]
        ),
        GlossaryEntry(
            slug: "stainless-conception", term: "Stainless conception",
            short: "Christ's conception, of a virgin and without sin.",
            full: """
            The hymn's "stainless conception" is how Christ was conceived: by the Holy Spirit, \
            of a virgin, without sin. The maiden says it is hard to believe, and she is speaking \
            of his conception, not of her own.

            It is not the later Western teaching that Mary herself was conceived without stain. \
            The Orthodox Church does not teach that.
            """,
            category: .faith, related: ["incarnation", "annunciation", "theotokos"]
        ),
        GlossaryEntry(
            slug: "type-of-the-resurrection", term: "Type of the Resurrection",
            short: "An earlier image of Christ's rising from the dead.",
            full: """
            A type is a person or an event that pictures, ahead of time, something God will do. \
            The hymn says Mary flashes forth the type of the Resurrection: in her, an image of \
            Christ's rising is already visible.

            The Resurrection itself is his rising on the third day. Pascha is the feast of it.
            """,
            category: .faith, related: ["resurrection", "pascha"]
        ),
        GlossaryEntry(
            slug: "redeemer", term: "Redeemer",
            short: "Christ, as the one who sets his people free.",
            full: """
            To redeem is to pay what it costs to set someone free. The Church calls Christ the \
            Redeemer because his death is that cost, and the captivity was death and sin.

            The hymn says Mary engendered him, the Redeemer of captives.
            """,
            category: .faith, related: ["pascha", "incarnation"]
        ),
        GlossaryEntry(
            slug: "mystery", term: "Mystery",
            short: "Something hidden, now made known. Also a name for a sacrament.",
            full: """
            A mystery, in the hymn, is something beyond what the mind can take in — above all \
            that Mary bore a child and remained a virgin. It is not a puzzle meant to be solved.

            The same word names the sacraments. Those are the Holy Mysteries: baptism, communion \
            and the rest, where what is done outwardly carries what God does.
            """,
            category: .faith, related: ["incarnation", "holy-mysteries"]
        ),
    ]
}
