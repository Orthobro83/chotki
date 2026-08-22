import Foundation

// The prayers themselves.
//
// EVERY TEXT HERE AWAITS A PRIEST'S REVIEW. They are the most consequential
// content in the app and the easiest to get subtly wrong.
//
// The wording is older public-domain liturgical English — the Hapgood Service
// Book (1906) and translations of the same period — for the same reason the
// patristic passages are: modern prayer books, the Jordanville book included,
// remain in copyright. A parish that uses different wording should have this
// file edited rather than the app worked around.
//
// Deliberately a **core set** rather than a full prayer rule. The morning and
// evening rules are long, vary by prayer book, and are settled with a priest;
// what is here are the prayers common to almost every form of them, so that a
// rule can show something true rather than something invented.
extension PrayerBook {

    public static let bundled: [Prayer] = [

        // MARK: the opening prayers

        Prayer(
            id: "beginning",
            title: "The Beginning",
            rubric: "How every rule opens.",
            paragraphs: [
                "In the name of the Father, and of the Son, and of the Holy Spirit. Amen.",
                "Glory to Thee, our God, glory to Thee."
            ],
            source: "Common usage"
        ),
        Prayer(
            id: "heavenly-king",
            title: "O Heavenly King",
            rubric: "To the Holy Spirit. Not said between Pascha and Pentecost.",
            paragraphs: [
                "O Heavenly King, the Comforter, the Spirit of Truth, Who art everywhere present and fillest all things; Treasury of good things and Giver of life: come and abide in us, and cleanse us from every impurity, and save our souls, O Good One."
            ],
            source: "Hapgood, Service Book, 1906",
            sourceURL: "https://archive.org/details/servicebookofhol00hapg"
        ),
        Prayer(
            id: "trisagion",
            title: "The Trisagion",
            rubric: "Said three times.",
            paragraphs: [
                "Holy God, Holy Mighty, Holy Immortal, have mercy on us.",
                "Glory to the Father, and to the Son, and to the Holy Spirit, both now and ever, and unto ages of ages. Amen."
            ],
            source: "Hapgood, Service Book, 1906",
            sourceURL: "https://archive.org/details/servicebookofhol00hapg"
        ),
        Prayer(
            id: "all-holy-trinity",
            title: "O Most Holy Trinity",
            paragraphs: [
                "O Most Holy Trinity, have mercy on us. O Lord, cleanse us from our sins. O Master, pardon our iniquities. O Holy One, visit and heal our infirmities for Thy name's sake.",
                "Lord, have mercy. Lord, have mercy. Lord, have mercy.",
                "Glory to the Father, and to the Son, and to the Holy Spirit, both now and ever, and unto ages of ages. Amen."
            ],
            source: "Hapgood, Service Book, 1906",
            sourceURL: "https://archive.org/details/servicebookofhol00hapg"
        ),
        Prayer(
            id: "our-father",
            title: "The Lord's Prayer",
            paragraphs: [
                "Our Father, Who art in the heavens, hallowed be Thy name. Thy kingdom come. Thy will be done, on earth as it is in heaven. Give us this day our daily bread, and forgive us our debts, as we forgive our debtors. And lead us not into temptation, but deliver us from the evil one.",
                "For Thine is the kingdom, and the power, and the glory, of the Father, and of the Son, and of the Holy Spirit, now and ever, and unto ages of ages. Amen."
            ],
            source: "Matthew 6.9–13"
        ),

        // MARK: morning and evening

        Prayer(
            id: "having-risen",
            title: "Having Risen from Sleep",
            rubric: "On rising.",
            paragraphs: [
                "Having risen from sleep, I thank Thee, O Holy Trinity, that for the sake of Thy great goodness and long-suffering Thou hast not been wroth with me, slothful and sinful as I am, neither hast Thou destroyed me in my transgressions; but Thou hast shown Thy usual love for mankind, and hast raised me up as I lay in heedlessness, that I might rise early and glorify Thy sovereignty."
            ],
            source: "Hapgood, Service Book, 1906",
            sourceURL: "https://archive.org/details/servicebookofhol00hapg"
        ),
        Prayer(
            id: "evening-forgiveness",
            title: "Before Sleep",
            rubric: "At the end of the day.",
            paragraphs: [
                "O Lord our God, if during this day I have sinned, whether in word or deed or thought, forgive me all, for Thou art good and lovest mankind.",
                "Grant me peaceful and undisturbed sleep, and deliver me from all the influence and temptation of the evil one. Raise me up again in due time, that I may glorify Thee; for Thou art blessed, with Thine only-begotten Son and Thine all-holy Spirit, unto ages of ages. Amen."
            ],
            source: "Hapgood, Service Book, 1906",
            sourceURL: "https://archive.org/details/servicebookofhol00hapg"
        ),
        Prayer(
            id: "guardian-angel",
            title: "To the Guardian Angel",
            paragraphs: [
                "O Angel of God, my holy guardian, given to me from heaven by God: enlighten me this day, and keep me from all evil, guide me toward good deeds, and set me upon the path of salvation. Amen."
            ],
            source: "Common usage"
        ),

        // MARK: to the Theotokos

        Prayer(
            id: "rejoice-o-virgin",
            title: "Rejoice, O Virgin Theotokos",
            paragraphs: [
                "Rejoice, O Virgin Theotokos, Mary full of grace, the Lord is with thee. Blessed art thou among women, and blessed is the fruit of thy womb, for thou hast borne the Saviour of our souls."
            ],
            source: "Hapgood, Service Book, 1906",
            sourceURL: "https://archive.org/details/servicebookofhol00hapg",
            isForRope: true
        ),
        Prayer(
            id: "it-is-truly-meet",
            title: "It Is Truly Meet",
            paragraphs: [
                "It is truly meet to bless thee, O Theotokos, ever-blessed and most blameless, and Mother of our God.",
                "More honourable than the cherubim, and beyond compare more glorious than the seraphim, who without corruption gavest birth to God the Word: true Theotokos, we magnify thee."
            ],
            source: "Hapgood, Service Book, 1906",
            sourceURL: "https://archive.org/details/servicebookofhol00hapg"
        ),

        // MARK: for the rope

        Prayer(
            id: "jesus-prayer",
            title: "The Jesus Prayer",
            rubric: "The prayer of the heart. Said slowly, with attention.",
            paragraphs: [
                "Lord Jesus Christ, Son of God, have mercy on me, a sinner."
            ],
            source: "Common usage",
            isForRope: true
        ),
        Prayer(
            id: "jesus-prayer-short",
            title: "The Jesus Prayer, shorter form",
            rubric: "Used when the longer form crowds the breath.",
            paragraphs: [
                "Lord Jesus Christ, have mercy on me."
            ],
            source: "Common usage",
            isForRope: true
        ),
        Prayer(
            id: "publican",
            title: "The Prayer of the Publican",
            paragraphs: [
                "God, be merciful to me, a sinner."
            ],
            source: "Luke 18.13",
            isForRope: true
        ),
        Prayer(
            id: "lord-have-mercy",
            title: "Lord, Have Mercy",
            paragraphs: [
                "Lord, have mercy."
            ],
            source: "Common usage",
            isForRope: true
        ),

        // MARK: seasonal and occasional

        Prayer(
            id: "ephrem",
            title: "The Prayer of Saint Ephrem",
            rubric: "Said through Great Lent, with prostrations.",
            paragraphs: [
                "O Lord and Master of my life, take from me the spirit of sloth, faint-heartedness, lust of power, and idle talk.",
                "But give rather the spirit of chastity, humility, patience, and love to Thy servant.",
                "Yea, O Lord and King, grant me to see my own transgressions, and not to judge my brother; for blessed art Thou unto ages of ages. Amen."
            ],
            source: "Saint Ephrem the Syrian"
        ),
        Prayer(
            id: "creed",
            title: "The Symbol of Faith",
            rubric: "The Nicene Creed.",
            paragraphs: [
                "I believe in one God, the Father Almighty, Maker of heaven and earth, and of all things visible and invisible.",
                "And in one Lord Jesus Christ, the Son of God, the Only-begotten, begotten of the Father before all ages; Light of Light, true God of true God; begotten, not made; of one essence with the Father, by Whom all things were made.",
                "Who for us men and for our salvation came down from heaven, and was incarnate of the Holy Spirit and the Virgin Mary, and became man.",
                "And was crucified for us under Pontius Pilate, and suffered, and was buried.",
                "And rose again on the third day according to the Scriptures.",
                "And ascended into heaven, and sitteth at the right hand of the Father.",
                "And He shall come again with glory to judge the living and the dead; Whose kingdom shall have no end.",
                "And in the Holy Spirit, the Lord, the Giver of Life, Who proceedeth from the Father; Who with the Father and the Son together is worshipped and glorified; Who spake by the prophets.",
                "In one Holy, Catholic, and Apostolic Church.",
                "I confess one baptism for the remission of sins.",
                "I look for the resurrection of the dead, and the life of the age to come. Amen."
            ],
            source: "The Council of Nicaea, 325, and Constantinople, 381"
        )
    ]
}
