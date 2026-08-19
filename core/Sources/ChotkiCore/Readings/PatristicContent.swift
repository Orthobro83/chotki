import Foundation

// Passages from the Fathers, all from public-domain sources: the Ante-Nicene
// Fathers and Nicene and Post-Nicene Fathers series (1885–1900), and early
// translations of the Sayings of the Desert Fathers.
//
// Attributions name the work so each can be checked. Awaiting a priest's review
// before the app goes beyond personal use.
extension PatristicReadings {

    public static let bundled: [PatristicReading] = [

        PatristicReading(
            id: "athanasius-incarnation-54",
            text: "He was made man that we might be made God.",
            author: "Saint Athanasius the Great",
            source: "On the Incarnation, 54"
        ),
        PatristicReading(
            id: "irenaeus-glory",
            text: "The glory of God is a living man, and the life of man consists in beholding God.",
            author: "Saint Irenaeus of Lyons",
            source: "Against Heresies, IV.20.7"
        ),
        PatristicReading(
            id: "chrysostom-honour-body",
            text: "Do you wish to honour the body of Christ? Do not despise him when he is naked. Do not honour him here in the church with silken garments while neglecting him outside, where he suffers cold and nakedness.",
            author: "Saint John Chrysostom",
            source: "Homilies on Matthew, 50"
        ),
        PatristicReading(
            id: "basil-bread",
            text: "The bread which you keep belongs to the hungry; the coat which you guard in your wardrobe, to the naked; the shoes which are rotting in your possession, to the shoeless.",
            author: "Saint Basil the Great",
            source: "Homily on the saying of the Gospel, I will pull down my barns"
        ),
        PatristicReading(
            id: "ignatius-wheat",
            text: "I am the wheat of God, and let me be ground by the teeth of the wild beasts, that I may be found the pure bread of Christ.",
            author: "Saint Ignatius of Antioch",
            source: "Epistle to the Romans, 4"
        ),
        PatristicReading(
            id: "anthony-humility",
            text: "I saw the snares that the enemy spreads out over the world, and I said groaning, What can get through from such snares? Then I heard a voice saying to me, Humility.",
            author: "Saint Anthony the Great",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "poemen-heart",
            text: "Do not give your heart to that which does not satisfy your heart.",
            author: "Abba Poemen",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "gregory-nazianzus-become",
            text: "Let us become like Christ, since Christ became like us.",
            author: "Saint Gregory the Theologian",
            source: "Oration 1, On Pascha"
        ),
        PatristicReading(
            id: "chrysostom-prayer-light",
            text: "Prayer is the light of the soul, giving us true knowledge of God. It is a mediator between God and man.",
            author: "Saint John Chrysostom",
            source: "Homilies on the Statues"
        ),
        PatristicReading(
            id: "ephrem-lenten-prayer",
            text: "O Lord and Master of my life, take from me the spirit of sloth, faint-heartedness, lust of power, and idle talk. But give rather the spirit of chastity, humility, patience and love to Thy servant.",
            author: "Saint Ephrem the Syrian",
            source: "The Lenten Prayer"
        ),
        PatristicReading(
            id: "cyprian-unity",
            text: "He can no longer have God for his Father, who has not the Church for his mother.",
            author: "Saint Cyprian of Carthage",
            source: "On the Unity of the Church, 6"
        ),
        PatristicReading(
            id: "polycarp-endurance",
            text: "Let us then serve Him in fear, and with all reverence, even as He Himself has commanded us.",
            author: "Saint Polycarp of Smyrna",
            source: "Epistle to the Philippians, 6"
        ),
        PatristicReading(
            id: "moses-cell",
            text: "Go, sit in your cell, and your cell will teach you everything.",
            author: "Abba Moses",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "agathon-tongue",
            text: "If an angry man raises the dead, God is still displeased with his anger.",
            author: "Abba Agathon",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "chrysostom-almsgiving",
            text: "Not to share our own wealth with the poor is theft from the poor and deprivation of their means of life.",
            author: "Saint John Chrysostom",
            source: "Homilies on Lazarus, 2"
        ),
        PatristicReading(
            id: "basil-time",
            text: "A tree is known by its fruit; a man by his deeds. A good deed is never lost.",
            author: "Saint Basil the Great",
            source: "Letters"
        ),
        PatristicReading(
            id: "sisoes-beginning",
            text: "A brother asked Abba Sisoes, What shall I do? He said, What you seek is great humility.",
            author: "Abba Sisoes",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "augustine-restless",
            text: "Thou hast made us for Thyself, and our heart is restless until it rests in Thee.",
            author: "Saint Augustine of Hippo",
            source: "Confessions, I.1"
        ),
        PatristicReading(
            id: "gregory-nyssa-ascent",
            text: "This is truly the vision of God: never to be satisfied in the desire to see Him.",
            author: "Saint Gregory of Nyssa",
            source: "The Life of Moses"
        ),
        PatristicReading(
            id: "john-damascus-icons",
            text: "I do not worship matter, but I worship the Creator of matter, who became matter for my sake.",
            author: "Saint John of Damascus",
            source: "On the Divine Images, I.16"
        ),
        PatristicReading(
            id: "chrysostom-scripture",
            text: "The Scriptures were not given us that we should enclose them in books, but that we should engrave them upon our hearts.",
            author: "Saint John Chrysostom",
            source: "Homilies on Matthew"
        ),
        PatristicReading(
            id: "macarius-heart",
            text: "The heart itself is but a small vessel, and yet dragons are there, and there are also lions; there are poisonous beasts and all the treasures of evil. But there too is God, the angels, the life and the kingdom.",
            author: "Saint Macarius the Great",
            source: "Fifty Spiritual Homilies, 43"
        ),
        PatristicReading(
            id: "hermas-simplicity",
            text: "Be simple and guileless, and thou shalt be as the children who know not the wickedness that ruins the life of men.",
            author: "The Shepherd of Hermas",
            source: "Commandment Second"
        ),
        PatristicReading(
            id: "clement-rome-humility",
            text: "Let us be humble-minded, laying aside all haughtiness and pride and folly and angry feelings.",
            author: "Saint Clement of Rome",
            source: "Epistle to the Corinthians, 13"
        ),
        PatristicReading(
            id: "syncletica-beginning",
            text: "In the beginning there are a great many battles and a good deal of suffering for those who are advancing towards God, and afterwards, ineffable joy.",
            author: "Amma Syncletica",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "chrysostom-thanksgiving",
            text: "Glory to God for all things.",
            author: "Saint John Chrysostom",
            source: "attributed, his last words"
        ),
        PatristicReading(
            id: "justin-truth",
            text: "Whatever things were rightly said among all men, are the property of us Christians.",
            author: "Saint Justin Martyr",
            source: "Second Apology, 13"
        ),
        PatristicReading(
            id: "athanasius-scripture",
            text: "For not only does the divine Scripture speak, but the whole creation confesses its Maker.",
            author: "Saint Athanasius the Great",
            source: "Against the Heathen"
        ),
        PatristicReading(
            id: "arsenius-silence",
            text: "I have often repented of having spoken, but never of having held my peace.",
            author: "Abba Arsenius",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "john-short-patience",
            text: "We have put the light burden on one side, that is to say, self-accusation, and we have loaded ourselves with a heavy one, that is to say, self-justification.",
            author: "Abba John the Short",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "basil-prayer-constant",
            text: "Prayer is a request for what is good, offered by the devout to God.",
            author: "Saint Basil the Great",
            source: "Homily on the Martyr Julitta"
        ),
        PatristicReading(
            id: "gregory-theologian-word",
            text: "It is more important that we should remember God than that we should breathe.",
            author: "Saint Gregory the Theologian",
            source: "Oration 27, First Theological Oration"
        ),
        PatristicReading(
            id: "ambrose-word",
            text: "When we speak about wisdom, we are speaking of Christ. When we speak about virtue, we are speaking of Christ.",
            author: "Saint Ambrose of Milan",
            source: "Exposition on Psalm 118"
        ),
        PatristicReading(
            id: "isaac-mercy",
            text: "Be persecuted, rather than be a persecutor. Be crucified, rather than be a crucifier. Be treated unjustly, rather than treat anyone unjustly.",
            author: "Saint Isaac the Syrian",
            source: "Ascetical Homilies"
        ),
        PatristicReading(
            id: "pambo-conscience",
            text: "If you have a heart, you can be saved.",
            author: "Abba Pambo",
            source: "Sayings of the Desert Fathers"
        ),
        PatristicReading(
            id: "chrysostom-anger",
            text: "He who is angry without cause shall be in danger; but he who is angry with cause shall not be in danger; for without anger, teaching would be useless.",
            author: "Saint John Chrysostom",
            source: "Homilies on Matthew, 16"
        )
    ]
}
