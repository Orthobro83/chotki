import Foundation

/// The Akathist to the Theotokos, and the days the Church appoints it.
///
/// Not a hymn chosen at random, and not a weekly rule through the year. The
/// Fridays follow Pascha, so the old calendar and the new share them.
///
/// Greek and Antiochian practice reads one stasis — six of the twenty-four
/// stanzas — on each of the first four Fridays, and the whole hymn on the
/// fifth. Russian, Serbian and Bulgarian practice reads the whole hymn on the
/// fifth Friday only. Romanian and Georgian practice is not the one given
/// here; those churches are shown the Russian Orthodox Church Outside
/// Russia's appointment, which is that same fifth Friday.
///
/// The wording is the English of *The Akathist Hymn and Little Compline*
/// (London: Williams & Norgate, 1919), the hymn only: not Little Compline, and
/// not the Canon of Joseph that the book interleaves with it.
public enum Akathist {

    /// Friday of each of the first five weeks of Great Lent, as a distance
    /// from Pascha. Clean Monday is −48. Week-1 Friday is four days later.
    public static let lentFridays = [-44, -37, -30, -23, -16]

    public static let source = "The Akathist Hymn and Little Compline. London: Williams & Norgate, 1919"
    public static let sourceURL = "https://archive.org/details/akathisthymnlitt00londuoft"

    /// True when this tradition's own appointment is the one given here.
    /// Romanian and Georgian are not among them.
    public static func hasOwnAppointment(_ tradition: Tradition) -> Bool {
        switch tradition {
        case .greek, .antiochian, .russian, .serbian, .bulgarian: return true
        case .romanian, .georgian: return false
        }
    }

    /// 1...4 is that stasis; 5 is the whole hymn. Nil when it is not appointed.
    /// A tradition without its own appointment is given the Russian one.
    public static func week(paschaDistance: Int, tradition: Tradition) -> Int? {
        guard let index = lentFridays.firstIndex(of: paschaDistance) else { return nil }
        let week = index + 1
        let practice: Tradition = hasOwnAppointment(tradition) ? tradition : .russian
        let salutations = practice == .greek || practice == .antiochian
        if week < 5 && !salutations { return nil }
        return week
    }

    /// Said once the section is opened, and only when ROCOR's appointment is
    /// standing in for a church whose own is not given here. Nil otherwise.
    public static func fallbackNote(for tradition: Tradition) -> String? {
        switch tradition {
        case .romanian: return fallbackNote(church: "Romanian Orthodox Church")
        case .georgian: return fallbackNote(church: "Georgian Orthodox Church")
        case .greek, .antiochian, .russian, .serbian, .bulgarian: return nil
        }
    }

    private static func fallbackNote(church: String) -> String {
        "The \(church)'s own appointment is not the one given here. This is how the Russian Orthodox Church Outside Russia keeps it: the whole hymn, on Friday of the fifth week of Great Lent."
    }

    /// What is read on that Friday. The opening kontakion frames each part,
    /// and is read again at the end of it. On the fifth Friday the book also
    /// says to read the first stanza once more, and then the kontakion.
    /// Little Compline and the Canon are not part of this.
    public static func paragraphs(week: Int) -> [String] {
        let body: [String]
        if week == 5 {
            body = stanzas
        } else if (1...4).contains(week) {
            let start = (week - 1) * 6
            body = Array(stanzas[start..<(start + 6)])
        } else {
            return []
        }
        if week == 5, let first = stanzas.first {
            return [kontakion] + body + [again, first, kontakion]
        }
        return [kontakion] + body + [kontakion]
    }

    public static func heading(week: Int) -> String {
        switch week {
        case 1: return "The first part, appointed for this Friday."
        case 2: return "The second part, appointed for this Friday."
        case 3: return "The third part, appointed for this Friday."
        case 4: return "The fourth part, appointed for this Friday."
        default: return "The whole hymn, appointed for this Friday."
        }
    }

    /// "To thee, the Champion Leader." Read before a stasis, and again after it.
    /// Printed page 26. The hyphen in "thank-offerings" is the book's own.
    static let kontakion = "To thee, the Champion Leader, do I, thy City, ascribe thank-offerings of victory, for thou, O Mother of God, hast delivered me from terrors; but as thou hast invincible power, do thou free me from every kind of danger, so that to thee I may cry : Hail, thou Bride unwedded."

    /// Printed at the end of the whole hymn, before the first stanza is read again.
    static let again = "And again the first Stanza :"

    /// The twenty-four alphabetical stanzas, six to a stasis. The English of
    /// the 1919 book, the hymn only. A hyphen that only broke a line is joined;
    /// a hyphen the book prints inside a word is kept. "Choir" is a rubric and
    /// is not copied.
    static let stanzas: [String] = [
        """
        An Angel, and the chiefest among them, was sent from Heaven to cry : Hail! to the Mother of God (thrice). And beholding Thee, O Lord, taking bodily form, he stood marvelling, and with his bodiless voice cried aloud to her saying :

        Hail, thou, through whom joy shall shine forth ; hail, thou through whom the curse shall be blotted out.

        Hail, thou, the Restoration of the fallen Adam ; hail, thou, the Redemption of the tears of Eve.

        Hail, Height, hard to climb, for human minds ; hail, Depth, hard to explore, even for the eyes of angels.

        Hail, thou that art the Throne of a King ; hail, thou that sustainest the Sustainer of all.

        Hail, Star that causest the Sun to appear ; hail, Womb of the divine Incarnating.

        Hail, thou through whom Creation is renewed ; hail, thou through whom the Creator becomes a babe.

        Hail, thou Bride unwedded.
        """,
        "Boldly and without fear the holy maiden spake to Gabriel, knowing her own chastity : To my soul thy strange message is hard to believe ; how speakest thou of a virgin and stainless conception? crying aloud : Alleluia.",
        """
        Craving to know unknown knowledge, the pure Maiden cried to him who ministered unto her : From a virgin body how is it possible for a Son to be born? Tell thou me. Then spake he to her in fear, crying aloud only :

        Hail, thou initiate of the ineffable counsel ; hail, surety of those who beseech thee in silence.

        Hail, beginner of the miracles of Christ ; hail, completer of His ordinances.

        Hail, heavenly Ladder by which God came down ; hail, Bridge leading from earth to heaven.

        Hail, thou great marvel and wonder of Angels ; hail, thou great cause of wailing in Demons.

        Hail, thou who ineffably gavest birth to the Light ; hail, thou who withheldest the divine secret from all.

        Hail, thou who oversoarest the knowledge of the wise ; hail, thou who givest light to the understanding of the faithful.

        Hail, thou Bride unwedded.
        """,
        "Divine power for her conceiving then overshadowed her who knew not wedlock, and showed her fruitful womb as a fertile field to all those who desire to reap their salvation, as they sing : Alleluia.",
        """
        Enshrining God in her womb, the Virgin hastened to Elizabeth, whose unborn babe at once recognised the Salutation of the Mother of God, and rejoiced and as it were leapt and sung and cried to her :

        Hail, Branch of unfading growth ; hail, Wealth of unmingled fruit.

        Hail, thou who labourest for Him, whose labour is love ; hail, thou who tendest Him who tendeth our Life.

        Hail, Corn-land growing fertility of mercies ; hail, Table sustaining abundance of oblations.

        Hail, thou who revivest the green fields of joy ; hail, thou who preparest a haven for souls.

        Hail, acceptable Incense of intercession ; hail, Oblation for all the world.

        Hail, Favour of God to mortals ; hail, Access of mortals to God.

        Hail, thou Bride unwedded.
        """,
        "Floods of doubtful thoughts troubled the wise Joseph within, when he saw thee, O blameless and unwedded Maiden, and he feared for thee ; but when he learnt of thy conception through the Holy Ghost, he cried : Alleluia.",
        """
        Gloriously the Angels hymned the incarnate Presence of Christ, and the shepherds heard ; and hastening as to a Shepherd, they beheld Him as a Lamb without spot, reposing on Mary's breast, and her they hymned and they said :

        Hail, Mother of the Lamb and of the Shepherd ; hail, Fold for the sheep of His pasture.

        Hail, Bulwark from invisible foes ; hail, opener of the Gates of Paradise.

        Hail, for the things of Heaven rejoice with the earth ; hail, for the things of earth join chorus with the Heavens.

        Hail, never-silent Voice of the Apostles ; hail, never-conquered courage of the Champions.

        Hail, firm Support of faith ; hail, shining Token of grace.

        Hail, thou through whom Hades was laid bare ; hail, thou through whom we are clothed with glory.

        Hail, thou Bride unwedded.
        """,
        "High in the heavens the Magi beheld the Godward-pointing Star, and they followed its rays and kept it as a beacon before them ; through it they sought a mighty King, and as they approached the Unapproachable they rejoiced and cried to Him : Alleluia.",
        """
        In the Virgin's hand the sons of the Chaldees saw Him Who with His Hand had made man ; and knowing Him as Master, though He had taken the form of a servant, they hastened with gifts to do homage, and cried to her who is blessed :

        Hail, Mother of the Star that never sets ; hail, Dawn of the mystic Day.

        Hail, thou who quenchest the furnace of error ; hail, thou who enlightenest those who know the Trinity.

        Hail, thou who castest out the inhuman tyrant of old ; hail, thou who showest forth the Lord, the merciful Christ.

        Hail, thou who redeemest from the creeds of barbarism ; hail, thou who releasest from the morass of evil deeds.

        Hail, thou who madest the worship of fire to cease ; hail, thou who madest the flame of suffering to be allayed.

        Hail, Guide of the wisdom of the faithful ; hail, Joy of all generations.

        Hail, thou Bride unwedded.
        """,
        "King's messengers, the Wise Men became, when they returned to Babylon ; they fulfilled Thy prophecy and to all preached Thee as the Christ, and they left Herod as a trifler, who knew not how to cry : Alleluia.",
        """
        Lighting in Egypt the lamp of truth, Thou, O Saviour, didst cast out the darkness of falsehood, and their idols endured not Thy strength but fell ; and those among them who were saved cried to the Mother of God :

        Hail, uplifting of men ; hail, downfall of demons.

        Hail, thou who tramplest upon the wanderings of error ; hail, thou who refutest the lies of idols.

        Hail, Sea which drowned Pharaoh and his schemes ; hail, Rock which refreshed those athirst for Life.

        Hail, fiery Pillar, leading those in darkness ; hail, Shelter of the world, broader than a cloud.

        Hail, Sustenance in succession to Manna ; hail, messenger of holy joy.

        Hail, Land of promise ; hail, thou from whence flow honey and milk.

        Hail, thou Bride unwedded.
        """,
        "Marvelling at Thine ineffable wisdom when Thou wast presented to him as a new-born Babe, Simeon, who was nearing his time of departure from this age of error, recognised Thee as perfect God and he cried : Alleluia.",
        """
        New was the Creation which the Creator shewed to us His creatures, when He appeared born from the womb of a Virgin ; and she was guarded, as she was, in perfect purity ; so that when we see this marvel, we may praise her and sing :

        Hail, Flower of incorruption ; hail, Crown of chastity.

        Hail, thou who flashest forth the Type of the Resurrection ; hail, thou who showest clearly the life of the Angels.

        Hail, Plant of goodly Fruit by which the faithful are nourished ; hail, Tree of leafy branches by which many are sheltered.

        Hail, thou who bearest the Guide of wanderers ; hail, thou who engenderest the Redeemer of captives.

        Hail, pleader before the Righteous Judge ; hail, forgiveness for many transgressors.

        Hail, Robe of boldness for the naked ; hail, tenderness vanquishing all desire.

        Hail, thou Bride unwedded.
        """,
        "Our minds are transported to Heaven when we behold this strange birthgiving, so let us now be estranged from the world ; it was for this that the Most High God appeared on earth as mortal man, and that He might raise on high those who sing to Him : Alleluia.",
        """
        Present in all completeness with those below, was the Uncircumscribed Word, yet in no way absent from those above ; for this was a divine descent and not a mere change of place ; and His birth was from a Virgin, and in her inspiration she heard words like these :

        Hail, Space for the Uncontained God ; hail, Door of solemn Mystery.

        Hail, doubtful Rumour of the faithless ; hail, undoubting Boast of the faithful.

        Hail, all-holy Chariot of Him Who rideth upon the Cherubim ; hail, all-glorious Chair of Him Who sitteth upon the Seraphim.

        Hail, thou who makest things that differ to agree ; hail, thou who yokest together Virginity and Motherhood.

        Hail, thou by whom transgression is annulled ; hail, thou by whom Paradise is opened.

        Hail, Key of the Kingdom of Christ ; hail, Hope of eternal blessedness.

        Hail, thou Bride unwedded.
        """,
        "Quires of Angels were amazed by thy great deed of Incarnation ; for they saw the inaccessible God as Man accessible to all, dwelling among us and hearing from all : Alleluia.",
        """
        Rhetoric's many followers were mute as fish when they saw thee, O Mother of God ; for they dared not ask : How canst thou bear a Child, and yet remain a Virgin? But we marvel at this mystery, and with faith cry :

        Hail, Vessel of the wisdom of God ; hail, Treasury of His foreknowledge.

        Hail, thou that showest philosophers fools ; hail, thou that provest logicians illogical.

        Hail, for the subtle disputants are confounded ; hail, for the writers of myths are withered.

        Hail, thou who didst break the webs of the Athenians ; hail, thou who didst fill the nets of the fishermen.

        Hail, thou who drawest us from the depths of ignorance ; hail, thou who enlightenest many with knowledge.

        Hail, Raft for those who desire to be saved ; hail, Haven for those who swim on the waves of the world.

        Hail, thou Bride unwedded.
        """,
        "Salvation it was that the Architect of all desired to bring to the world, and for this, by His own will, He came ; and, though as God He is the Shepherd, for us He appeared to us as a Man, and called the same by the same, still as God He hears : Alleluia.",
        """
        Thou, O Virgin Mother of God, art as a city wall to virgins and to all who flee to thee ; for the Maker of Heaven and earth prepared thee, O pure Maiden, and dwelt in thy womb, and taught all to call upon thee :

        Hail, Pillar of virginity ; hail, Gate of salvation.

        Hail, beginning of rational restoration ; hail, leader of divine righteousness.

        Hail, for thou didst regenerate our fallen race ; hail, for thou didst remind those who were mindless.

        Hail, thou who didst bring to nought the corruption of hearts ; hail, thou who didst give birth to the Sower of chastity.

        Hail, bridal Chamber of a virgin marriage ; hail, thou who dost join the faithful to the Lord.

        Hail, fair nursing-mother of virgins ; hail, bridal Escort of holy souls.

        Hail, thou Bride unwedded.
        """,
        "Unworthy is every hymn that would encompass the multitude of Thy many mercies ; for if we should offer to Thee, O Holy King, hymns of praise numberless as the sands, we should still have done nothing to compare to what Thou hast given to us who sing to Thee : Alleluia.",
        """
        Verily we behold the Holy Virgin as a shining beacon light appearing to those in darkness : for she kindles the Supernal Light and leads all to divine knowledge ; she illumines our minds with radiance and is honoured by these our chants :

        Hail, Ray of the Living Sun : hail, Flash of fadeless lustre.

        Hail, Lightning, shining upon our souls ; hail, thou, who dost as thunder, strike down the enemy.

        Hail, for thou didst cause the many-starred Light to dawn ; hail, for thou didst cause the ever-flowing River to gush forth.

        Hail, thou who didst from life trace the image of the font ; hail, thou who didst take away the stain of sin.

        Hail, Laver purifying conscience ; hail, Wine-bowl for the mingling of joy.

        Hail, sweet-scented Fragrance of Christ ; hail, life of mystic festival.

        Hail, thou Bride unwedded.
        """,
        "When He, Who forgives the ancient debts of all men, would grant grace, of His own will He came to dwell among those who had departed from His favour ; and when He had rent asunder the handwriting against them, He hears from all : Alleluia.",
        """
        Yet while we sing to Him Whom thou didst bear, we all praise thee, O Mother of God, as a living temple ; for the Lord, Who holds all things in His hand, dwelt in thy womb, and He hallowed and glorified thee, and taught all to cry to thee :

        Hail, Tabernacle of God and of the Word ; hail, holiest of holy saints.

        Hail, Ark made golden by the Spirit ; hail, inexhaustible treasury of Life.

        Hail, precious Diadem of godly kings ; hail, venerable Boast of faithful priests.

        Hail, immovable Tower of the Church ; hail, impregnable Bulwark of the Kingdom.

        Hail, thou through whom trophies are set up ; hail, thou through whom our enemies are cast down.

        Hail, healing of my flesh ; hail, salvation of my soul.

        Hail, thou Bride unwedded.
        """,
        "Zealously we praise thee, O Mother, who didst bear Him Who was the most holy Word of all the Saints (thrice) ; and when thou receivest this our offering, deliver us all from every ill, and redeem from future woe those who cry to thee : Alleluia.",
    ]
}
