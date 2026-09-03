import Foundation

// The prayers themselves.
//
// EVERY TEXT HERE AWAITS A PRIEST'S REVIEW. They are the most consequential
// content in the app and the easiest to get subtly wrong.
//
// The wording is the **Jordanville Prayer Book** — *A Prayer Book for Orthodox
// Christians*, Holy Trinity Monastery, 4th edition revised — used with the
// copyright holder's permission, which Ryan obtained. It replaced the Hapgood
// Service Book (1906) wording that stood here before, because Jordanville is
// the book his parish actually uses and a prayer app that disagrees with the
// book in your hands is worse than no prayer app.
//
// **Generated, not typed**, by `tools/jordanville/`. The book exists only as a
// scan, so the text was extracted, its OCR repaired, and the sections parsed —
// 46 prayers is far too many to retype without introducing exactly the errors
// the repair was for. `tools/jordanville/README.md` says what the scanner did
// to this book and what was done about it; the judgement that is *not*
// generated — which blocks are prayers, which belong on the rope — is the
// table at the top of `generate.py`.
//
// Do not hand-edit the generated prayers below. Fix the pipeline and run it
// again, or the next run will quietly undo the correction.
extension PrayerBook {

    public static let bundled: [Prayer] = [
        // MARK: on the rope
        //
        // Short, repeated, traditionally counted. Jordanville gives the Jesus
        // Prayer in its closing essay rather than as a numbered prayer, so
        // these three are set down by hand from that passage; the rest of the
        // file is generated.
        Prayer(
            id: "jesus-prayer",
            title: "The Jesus Prayer",
            rubric: "The prayer of the heart. Said slowly, with attention.",
            paragraphs: [
                "Lord Jesus Christ, Son of God, have mercy on me a sinner."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/",
            isForRope: true
        ),
        Prayer(
            id: "jesus-prayer-short",
            title: "The Jesus Prayer, shorter form",
            rubric: "As Saint Theophan gives it, for when the longer form crowds the breath.",
            paragraphs: [
                "Lord Jesus Christ, Son of God, have mercy on me."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/",
            isForRope: true
        ),
        Prayer(
            id: "lord-have-mercy",
            title: "Lord, Have Mercy",
            rubric: "Said in threes, twelves, or forties.",
            paragraphs: [
                "Lord, have mercy."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/",
            isForRope: true
        ),

        Prayer(
            id: "ephrem",
            title: "The Prayer of Saint Ephraim the Syrian",
            rubric: "Said through Great Lent, with a prostration at each pause.",
            paragraphs: [
                "O Lord and Master of my life, a spirit of idleness, despondency, ambition, and idle talking give me not.",
                "But rather a spirit of chastity, humble-mindedness, patience, and love bestow upon me Thy servant.",
                "Yea, O Lord King, grant me to see my failings and not condemn my brother; for blessed art Thou unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),

        // MARK: generated from the book
        Prayer(
            id: "publican",
            title: "The Prayer of the Publican",
            paragraphs: [
                "O God, be merciful to me a sinner."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/",
            isForRope: true
        ),
        Prayer(
            id: "opening-prayer",
            title: "The Opening Prayer",
            rubric: "Said first of all.",
            paragraphs: [
                "O Lord Jesus Christ, Son of God, for the sake of the prayers of Thy most pure Mother and all the saints, have mercy on us. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "beginning",
            title: "The Beginning",
            rubric: "How every rule opens.",
            paragraphs: [
                "Glory to Thee, our God, glory to Thee."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "heavenly-king",
            title: "O Heavenly King",
            rubric: "To the Holy Spirit. Not said between Pascha and Pentecost.",
            paragraphs: [
                "O Heavenly King, Comforter, Spirit of Truth, Who art everywhere present and fillest all things, Treasury of good things and Giver of life: Come and dwell in us, and cleanse us of all impurity, and save our souls, O Good One."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "trisagion",
            title: "The Trisagion",
            rubric: "Said three times.",
            paragraphs: [
                "Holy God, Holy Mighty, Holy Immortal, have mercy on us. Thrice.",
                "Glory to the Father, and to the Son, and to the Holy Spirit, both now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "all-holy-trinity",
            title: "O Most Holy Trinity",
            paragraphs: [
                "O Most Holy Trinity, have mercy on us. O Lord, blot out our sins. O Master, pardon our iniquities. O Holy One, visit and heal our infirmities for Thy name's sake.",
                "Lord, have mercy. Thrice.",
                "Glory to the Father, and to the Son, and to the Holy Spirit, both now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "our-father",
            title: "Our Father",
            paragraphs: [
                "Our Father, Who art in the heavens, hallowed be Thy name. Thy kingdom come, Thy will be done, on earth as it is in heaven. Give us this day our daily bread, and forgive us our debts, as we forgive our debtors; and lead us not into temptation, but deliver us from the evil one."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "troparia-to-the-holy-trinity",
            title: "Troparia to the Holy Trinity",
            paragraphs: [
                "Having risen from sleep, we fall down before Thee, O Good One, and the angelical hymn we cry aloud to Thee, O Mighty One: Holy, Holy, Holy art Thou, O God; through the Theotokos, have mercy on us.",
                "Glory to the Father, and to the Son, and to the Holy Spirit.",
                "From bed and sleep hast Thou raised me up, O Lord: enlighten my mind and heart, and open my lips that I may hymn Thee, O Holy Trinity: Holy, Holy, Holy art Thou, O God; through the Theotokos, have mercy on us.",
                "Both now and ever, and unto the ages of ages. Amen.",
                "Suddenly the Judge shall come, and the deeds of each shall be laid bare; but with fear do we cry at midnight: Holy, Holy, Holy art Thou, O God; through the Theotokos, have mercy on us.",
                "Lord, have mercy. Twelve."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-of-saint-basil-the-great-to-the-most",
            title: "Prayer of Saint Basil the Great to the Most Holy Trinity",
            paragraphs: [
                "As I rise from sleep, I thank Thee, O Holy Trinity, for through Thy great goodness and patience Thou wast not angry with me, an idler and sinner, nor hast Thou destroyed me with mine iniquities, but hast shown Thy usual love for mankind; and when I was prostrate in despair, Thou hast raised me up to keep the morning watch and glorify Thy power. And now enlighten my mind's eye, and open my mouth that I may meditate on Thy words, and understand Thy commandments, and do Thy will, and hymn Thee in heartfelt confession, and sing praises to Thine all-holy name: of the Father, and of the Son, and of the Holy Spirit, now and ever, and unto the ages of ages. Amen.",
                "O come let us worship God our King.",
                "O come let us worship and fall down before Christ our King and God.",
                "O come let us worship and fall down before Christ Himself, our King and God."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "psalm-50",
            title: "Psalm 50",
            paragraphs: [
                "Have mercy on me, O God, according to Thy great mercy; and according to the multitude of Thy compassions blot out my transgression.",
                "Wash me thoroughly from mine iniquity, and cleanse me from my sin. For I know mine iniquity, and my sin is ever before me. Against Thee only have I sinned and done this evil before Thee, that Thou mightest be justified in Thy words, and prevail when Thou art judged. For behold, I was conceived in iniquities, and in sins did my mother bear me. For behold, Thou hast loved truth; the hidden and secret things of Thy wisdom hast Thou made manifest unto me. Thou shalt sprinkle me with hyssop, and I shall be made clean; Thou shalt wash me, and I shall be made whiter than snow. Thou shalt make me to hear joy and gladness; the bones that be humbled, they shall rejoice. Turn Thy face away from my sins, and blot out all mine iniquities.",
                "Create in me a clean heart, O God, and renew a right spirit within me.",
                "Cast me not away from Thy presence, and take not Thy Holy Spirit from me.",
                "Restore unto me the joy of Thy salvation, and with Thy governing Spirit establish me. I shall teach transgressors Thy ways, and the ungodly shall turn back unto Thee. Deliver me from blood-guiltiness, O God, Thou God of my salvation; my tongue shall rejoice in Thy righteousness. O Lord, Thou shalt open my lips, and my mouth shall declare Thy praise. For if Thou hadst desired sacrifice, I had given it; with whole-burnt offerings Thou shalt not be pleased. A sacrifice unto God is a broken spirit; a heart that is broken and humbled God will not despise. Do good, O Lord, in Thy good pleasure unto Sion, and let the walls of Jerusalem be builded. Then shalt Thou be pleased with a sacrifice of righteousness, with oblation and whole-burnt offerings. Then shall they offer bullocks upon Thine altar."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "creed",
            title: "The Symbol of the Orthodox Faith",
            paragraphs: [
                "I believe in one God, the Father Almighty, Maker of heaven and earth, and of all things visible and invisible. And in one Lord Jesus Christ, the Son of God, the Only-begotten, begotten of the Father before all ages; Light of Light; true God of true God; begotten, not made; of one essence with the Father; by Whom all things were made; Who for us men, and for our salvation, came down from the heavens, and was incarnate of the Holy Spirit and the Virgin Mary, and became man; And was crucified for us under Pontius Pilate, and suffered, and was buried; And arose again on the third day according to the Scriptures; And ascended into the heavens, and sitteth at the right hand of the Father; And shall come again, with glory, to judge both the living and , the dead; Whose kingdom shall have no end. And in the Holy Spirit, the Lord, the Giver of Life; Who proceedeth from the Father; Who with the Father and the Son together is worshipped and glorified; Who spake by the prophets. In One, Holy, Catholic, and Apostolic Church. I confess one baptism for the remission of sins. I look for the resurrection of the dead, And the life of the age to come.",
                "'Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-i-of-st-macarius-the-great",
            title: "Prayer I, of St. Macarius the Great",
            paragraphs: [
                "O God, cleanse me a sinner, for I have never done anything good in Thy sight; but deliver me from the evil one, and let Thy will be done in me, that I may open mine unworthy mouth without condemnation, and praise Thy holy name: of the Father, and of the Son, and of the Holy Spirit, now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-ii-of-the-same-saint",
            title: "Prayer II, of the same saint",
            paragraphs: [
                "Having risen from sleep, I offer unto Thee, O Saviour, the midnight hymn, and falling down I cry unto Thee: Grant me not to fall asleep in the death of sin, but have compassion on me, O Thou Who wast voluntarily crucified, and hasten to raise me who am reclining in idleness, and save me in prayer and intercession; and after the night's sleep shine upon me a sinless day, O Christ God, and save me."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-iii-of-the-same-saint",
            title: "Prayer III, of the same saint",
            paragraphs: [
                "Having risen from sleep, I hasten to Thee, O Master, Lover of mankind, and by Thy loving-kindness, I strive to do Thy work, and I pray to Thee: Help me at all times, in everything, and deliver me from every worldly, evil thing and every impulse of the devil, and save me, and lead me into Thine eternal kingdom. For Thou art my Creator, and the Giver and Provider of everything good, and in Thee is all my hope, and unto Thee do I send up glory, now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-iv-of-the-same-saint",
            title: "Prayer IV, of the same saint",
            paragraphs: [
                "O Lord, Who in Thine abundant goodness and Thy great compassion hast granted me, Thy servant, to go through the time of the night that is past without attack from any opposing evil: Do Thou Thyself, O Master, Creator of all things, vouchsafe me by Thy true light and with an enlightened heart to do Thy will, now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-v-of-st-basil-the-great",
            title: "Prayer V, of St. Basil the Great",
            paragraphs: [
                "O Lord Almighty, God of hosts and of all flesh, Who dwellest on high and lookest down on things that are lowly, Who searchest the heart and innermost being, and clearly foreknowest the secrets of men; O unoriginate and everlasting Light, with Whom is no variableness, neither shadow of turning: Do Thou, O Immortal King, receive our supplications which we, daring because of the multitude of Thy compassions, offer Thee at the present time from defiled lips; and forgive us our sins, in deed, word, and thought, whether commit-ted by us knowingly or in ignorance, and cleanse us from every defilement of flesh and spirit. And grant us to pass through the night of the whole present life with watchful heart and sober thought, ever expecting the coming of the bright and appointed day of Thine Only-begotten Son, our Lord and God and Saviour, Jesus Christ, whereon the Judge of all shall come with glory to reward each according to his deeds. May we not be found fallen and idle, but watching, and upright in activity, ready to accompany Him into the joy and divine palace of His glory, where there is the ceaseless sound of those that keep festival, and the unspeakable delight of those that behold the ineffable beauty of Thy countenance. For Thou art the true Light that enlightenest and sanctifiest all, and all creation doth hymn Thee unto the ages of ages.",
                "Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-vi-likewise-by-st-basil",
            title: "Prayer VI, likewise by St. Basil",
            paragraphs: [
                "We bless Thee, O Most High God and Lord of mercy, Who ever doest with us things both great and inscrutable, both glorious and awesome, of which there is no measure; Who grantest to us sleep for rest from our infirmities, and relaxation from the labours of our much-toiling flesh.",
                "We thank Thee that Thou hast not destroyed us with our iniquities, but hast shown Thy loving-kindness to man as usual, and while we were lying in despair upon our beds, Thou hast raised us up that we might glorify Thy dominion. Wherefore, we implore Thy boundless goodness: Enlighten the eyes of our understanding and raise up our mind from the heavy sleep of indolence; open our mouth and fill it with Thy praise, that we may be able steadily to hymn and confess Thee, Who art God glorified in all and by all, the unoriginate Father, with Thine Only-begotten Son, and Thine All-holy and good and life-creating Spirit, now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-vii-to-the-most-holy-theotokos",
            title: "Prayer VII, to the Most Holy Theotokos",
            paragraphs: [
                "I sing of thy grace, O Sovereign Lady, and I pray thee to grace my mind.",
                "Teach me to step aright in the way of Christ's commandments. Strengthen me to keep awake in song, and drive away the sleep of despondency.",
                "O Bride of God, by thy prayers release me, bound with the bonds of sin.",
                "Guard me by night and by day, and deliver me from foes that defeat me.",
                "O bearer of God the Life-giver, enliven me who am deadened by passions.",
                "O bearer of the Unwaning Light, enlighten my blinded soul. O marvellous palace of the Master, make me to be a house of the Divine Spirit. O bearer of the Healer, heal the perennial passions of my soul. Guide me to the path of repentance, for I am tossed in the storm of life. Deliver me from eternal fire, and from evil worms, and from Tartarus. Let me not be exposed to the rejoicing of demons, guilty as I am of many sins. Renew me, grown old from senseless sins, O most immaculate one. Present me untouched by all torments, and pray for me to the Master of all. Vouchsafe me to find the joys of heaven with all the saints. O most holy Virgin, hearken unto the voice of thine unprofitable servant.",
                "Grant me torrents of tears, O most pure one, to cleanse my soul from impurity. I offer the groans of my heart to thee unceasingly, strive for me, O Sovereign Lady. Accept my service of supplication and offer it to compassionate God. O thou who art above the angels, raise me above this world's confusion. O Light-bearing heavenly tabernacle, direct the grace of the Spirit in me. I raise my hands and lips in thy praise, defiled as they are by impurity, O all-immaculate one. Deliver me from soul-corrupting evils, and fervently intercede with Christ, to Whom is due honour and worship, now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-viii-to-our-lord-jesus-christ",
            title: "Prayer VIII, to our Lord Jesus Christ",
            paragraphs: [
                "O my plenteously-merciful and all-merciful God, Lord Jesus Christ, through Thy great love Thou didst come down and become incarnate so that Thou mightest save all. And again, O Saviour, save me by Thy grace, I pray Thee. For if Thou shouldst save me for my works, this would not be grace or a gift, but rather a duty; yea, Thou Who art great in compassion and ineffable in mercy. For he that believeth in Me, Thou hast said, O my Christ, shall live and never see death. If, then, faith in Thee saveth the desperate, behold, I believe, save me, for Thou art my God and Creator. Let faith instead of works be imputed to me, O my God, for Thou wilt find no works which could justify me. But may my faith suffice instead of all works, may it answer for, may it acquit me, may it make me a partaker of Thine eternal glory. And let Satan not seize me and boast, O Word, that he hath torn me from Thy hand and fold. But whether I desire it or not, save me, O Christ my Saviour, forestall me quickly, quickly, for I perish. Thou art my God from my mother's womb. Vouchsafe me, O Lord, to love Thee now as fervently as I once loved sin itself, and also to work for Thee without idleness, diligently, as I worked before for deceptive Satan. But supremely shall I work for Thee, my Lord and God, Jesus Christ, all the days of my life, now and ever, and unto the ages of ages.",
                "Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-ix-to-the-holy-guardian-angel",
            title: "Prayer IX, to the Holy Guardian Angel",
            paragraphs: [
                "O holy angel that standeth by my wretched soul and my passionate life, forsake not me a sinner, nor shrink from me because of mine intemperance. Give no place for the cunning demon to master me through the violence of my mortal body, strengthen my poor and feeble hand, and guide me in the way of salvation.",
                "Yea, O holy angel of God, guardian and protector of my wretched soul and body, forgive me all wherein I have offended thee all the days of my life; and if I have sinned during the past night, protect me during the present day, and guard me from every temptation of the enemy, that I may not anger God by any sin. And pray to the Lord for me, that He may establish me in His fear, and show me, His servant, to be worthy of His goodness.",
                "Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-x-to-the-most-holy-theotokos",
            title: "Prayer X, to the Most Holy Theotokos",
            paragraphs: [
                "O my most holy lady Theotokos, through thy holy and all-powerful prayers, banish from me, thy lowly and wretched servant, despondency, forgetfulness, folly, carelessness, and all filthy, evil, and blasphemous thoughts from my wretched heart and my darkened mind. And quench the flame of my passions, for I am poor and wretched, and deliver me from many and cruel memories and deeds, and free me from all their evil effects. For blessed art thou by all generations, and glorified is thy most honourable name unto the ages of ages.",
                "Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-for-the-salvation-of-russia",
            title: "Prayer for the Salvation of Russia",
            paragraphs: [
                "O Lord Jesus Christ our God, forgive our iniquities. Through the intercessions of Thy most pure Mother, save the suffering Russian people from the yoke of the godless authority. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayerful-invocation-of-the-saint-whose-name",
            title: "Prayerful Invocation of the Saint Whose Name we bear",
            paragraphs: [
                "Pray unto God for me, O holy God-pleaser N., for I fervently flee unto Thee, the speedy helper and intercessor for my soul."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "rejoice-o-virgin",
            title: "Song to the Most Holy Theotokos",
            paragraphs: [
                "O Theotokos and Virgin, rejoice, Mary, full of grace, the Lord is with thee; blessed art thou among women, and blessed is the Fruit of thy womb, for thou hast borne the Saviour of our souls."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/",
            isForRope: true
        ),
        Prayer(
            id: "troparion-to-the-cross",
            title: "Troparion to the Cross",
            paragraphs: [
                "Save, O Lord, Thy people, and bless Thine inheritance; grant Thou victory to Orthodox Christians over enemies; and by the power of Thy Cross do Thou preserve Thy commonwealth.",
                "Then off er a brief prayer for the health and salvation of thy spiritual fat her, thy parents, relatives, those in authority, benefactors, others known to thee, the ailing, or those passing through sorrows."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "for-the-living",
            title: "For the Living",
            paragraphs: [
                "Remember, O Lord Jesus Christ our God, Thy mercies and compassions which are from the ages, for the sake of which Thou didst become man and didst will to endure crucifixion and death for the salvation of those that rightly believe in Thee; and having risen from the dead didst ascend into the heavens and sittest at the right hand of God the Father, and regardest the humble entreaties of those that call upon Thee with all their heart; incline Thine ear, and hearken unto the humble supplication of me, Thine unprofitable servant, as an odor of spiritual fragrance, which I offer unto Thee for all Thy people. And first, remember Thy Holy, Catholic, and Apostolic Church, which Thou hast provided through Thine honourable Blood, and establish, and strengthen, and expand, increase, pacify, and keep Her unconquerable by the gates of hades; calm the dissensions of the churches, quench the raging of the nations, and quickly destroy and uproot the rising of heresy, and bring them to nought by the power of Thy Holy Spirit. Bow.",
                "Save, O Lord, and have mercy on the Russian Land and her Orthodox people both in the homeland and in the diaspora, this land and its authorities. Bow.",
                "Save, O Lord, and have mercy on the holy Eastern Orthodox patriarchs, most reverend metropolitans, Orthodox archbishops and bishops, and all the priestly and monastic order, and all who serve in the Church, whom Thou hast appointed to shepherd Thy rational flock, and through their prayers have mercy and save me, a sinner. Bow.",
                "Save, O Lord, and have mercy on my spiritual father N., and through his holy prayers forgive my sins. Bow.",
                "Save, O Lord, and have mercy on my parents, Names, brothers and sisters, and my kindred according to the flesh, and all the neighbours of my family and friends, and grant them Thine earthly and spiritual good things. Bow.",
                "Save, O Lord, and have mercy on the aged and the young, the poor and the orphans and widows, and those in sickness and sorrow, misfortune and tribulation, those in difficult circumstances and in captivity, in prisons and dungeons, and especially those of Thy servants that are persecuted for Thy sake and the Orthodox Faith by godless peoples, by apostates, and by heretics; and remember them, visit, strengthen, comfort, and by Thy power quickly grant them relief, freedom, and deliverance. Bow.",
                "Save, O Lord, and have mercy on them that hate and wrong me, and make temptation for me, and let them not perish because of me, a sinner.",
                "Bow.",
                "Illumine with the light of awareness the apostates from the Orthodox Faith, and those blinded by pernicious heresies, and number them with Thy Holy, Apostolic, Catholic Church. Bow."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "for-the-departed",
            title: "For the Departed",
            paragraphs: [
                "Remember, O Lord, those that have departed this life, Orthodox kings and queens, princes and princesses, most holy patriarchs, most reverend metropolitans, Orthodox archbishops and bishops, those in priestly and clerical orders of the Church, and those that have served Thee in the monastic order, and grant them rest with the saints in Thine eternal taber- .",
                "nacles. Bow.",
                "Remember, O Lord, the souls of Thy departed servants, my parents, Names, and all my kindred according to the flesh; and forgive them all transgressions, voluntary and involuntary, granting them the kingdom and a portion of Thine eternal good things, and the delight of Thine endless and blessed life. Bow.",
                "Remember, O Lord, also all our fathers and brethren, and sisters, and those that lie here, and all Orthodox Christians that departed in the hope of resurrection and life eternal, and settle them with Thy saints, where the light of Thy countenance shall visit them, and have mercy on us, for Thou art good and the Lover of mankind. Bow.",
                "Grant, O Lord, remission of sins to all our fathers, brethren, and sisters that have departed before us in the faith and hope of resurrection, and make their memory to be eternal.",
                "Bow."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "it-is-truly-meet",
            title: "Final Prayer",
            paragraphs: [
                "It is truly meet to bless thee, the Theotokos, ever-blessed and most blameless, and Mother of our God.",
                "More honourable than the Cherubim, and beyond compare more glorious than the Seraphim, who without corruption gavest birth to God the Word, the very Theotokos, thee do we magnify.",
                "Glory to the Father, and to the Son, and to the Holy Spirit, both now and ever, and unto the ages of ages. Amen.",
                "Lord, have mercy. Thrice.",
                "O Lord, bless. And the dismissal: O Lord Jesus Christ, Son of God, for the sake of the prayers of Thy most pure Mother, our holy and God-bearing fathers and all the saints, have mercy on us. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "before-the-beginning-of-any-work",
            title: "Before the Beginning of Any Work",
            paragraphs: [
                "O Lord, bless. Or: O Lord Jesus Christ, Only-begotten Son of Thine unoriginate Father, Thou hast said with Thy most pure lips: For without Me, ye can do nothing. My Lord, O Lord, in faith having embraced Thy words, I fall down before Thy goodness; help me, a sinner, to complete through Thee Thyself this work which I am about to begin, in the name of the Father, and of the Son, and of the Holy Spirit.",
                "Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "after-the-completion-of-any-work",
            title: "After the Completion of Any Work",
            paragraphs: [
                "Glory to Thee, O Lord. Or: Thou art the fullness of all good things, O my Christ; fill my soul with joy and gladness, and save me, for Thou alone art plenteous in mercy."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "before-lessons",
            title: "Before Lessons",
            paragraphs: [
                "O Heavenly King, Comforter, Spirit of Truth, Who art everywhere present and fillest all things, Treasury of good things and Giver of life: Come and dwell in us, and cleanse us of all impurity, and save our souls, O Good One.",
                "Or: O Most-good Lord! Send down upon us the grace of Thy Holy Spirit, Who granteth gifts and strengtheneth the powers of our souls, so that by attending to the teaching given us, we may grow to the glory of Thee, our Creator, to the comfort of our parents, and to the service of the Church and our native land."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "after-lessons",
            title: "After Lessons",
            paragraphs: [
                "It is truly meet to bless thee, the Theotokos, ever-blessed and most blameless and Mother of our God.",
                "More honourable than the Cherubim, and beyond compare more glorious than the Seraphim; who without corruption gavest birth to God the Word, the very Theotokos, thee do we magnify.",
                "Or: We thank Thee, O Creator, that Thou hast vouchsafed us Thy grace to attend instruction. Bless our leaders, parents, and instructors who are leading us to an awareness of good, and grant us power and strength to continue this study."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "before-noon-and-evening-meals",
            title: "Before [Breakfast and] Noon and Evening Meals",
            paragraphs: [
                "Our Father, Who art in the heavens, hallowed be Thy name. Thy kingdom come, Thy will be done, on earth as it is in heaven. Give us this day our daily bread, and forgive us our debts, as we forgive our debtors; and lead us not into temptation, but deliver us from the evil one.",
                "Or: The eyes of all look to Thee with hope, and Thou gavest them their food in due season. Thou openest Thy hand and fillest every living thing with Thy favour."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "after-noon-and-evening-meals",
            title: "After [Breakfast and] Noon and Evening Meals",
            paragraphs: [
                "We thank Thee, O Christ our God, that Thou hast satisfied us with Thine earthly gifts; deprive us not of Thy heavenly kingdom, but as Thou earnest among Thy disciples, O Saviour, and gavest them peace, come to us and save us."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "troparia",
            title: "Troparia",
            paragraphs: [
                "Have mercy on us, O Lord, have mercy on us; for at a loss for any defence, this prayer do we sinners offer unto Thee as Master: have mercy on us.",
                "Glory to the Father, and to the Son, and to the Holy Spirit.",
                "Lord, have mercy on us; for we have hoped in Thee, be not angry with us greatly, neither remember our iniquities; but look upon us now as Thou art compassionate, and deliver us from our enemies, for Thou art our God, and we, Thy people; all are the works of the Thy hands, and we call upon Thy name.",
                "Both now and ever, and unto the ages of ages. Amen.",
                "The door of compassion open unto us, O blessed Theotokos, for, hoping in thee, let us not perish; through thee may we be delivered from adversities, for thou art the salvation of the Christian race.",
                "Lord, have mercy. Twelve times."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "sleep-prayer-i-of-st-macarius-the-great",
            title: "Prayer I, of St. Macarius the Great",
            paragraphs: [
                "O Eternal God and King of all creation, Who hast vouchsafed me to arrive at this hour, forgive me the sins that I have committed this day in deed, word, and thought; and cleanse, O Lord, my lowly soul of all impurity of flesh and spirit, and grant me, O Lord, to pass the sleep of this night in peace; that, rising from my lowly bed, I may please Thy most holy name all the days of my life, and thwart the enemies, fleshly and bodiless, that war against me. And deliver me, O Lord, from vain thoughts and evil desires which defile me. For Thine is the kingdom, and the power, and the glory: of the Father, and of the Son, and of the Holy Spirit, now and ever, and unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-ii-of-saint-antiochus",
            title: "Prayer II, of Saint Antiochus",
            paragraphs: [
                "O Ruler of all, Word of the Father, O Jesus Christ, Thou Who art perfect: For the sake of the plenitude of Thy mercy, never depart from me, but always remain in me Thy servant.",
                "O Jesus, Good Shepherd of Thy sheep, deliver me not over to the sedition of the serpent, and leave me not to the will of Satan, for the seed of corruption is in me. But do Thou, O Lord, worshipful God, holy King, Jesus : Christ, as I sleep, guard me by the Unwaning Light, Thy Holy Spirit, by \\\\'horn Thou didst sanctify Thy disciples. O Lord, grant me, Thine unworthy servant, Thy salvation upon my bed. Enlighten my mind with the light of understanding of Thy Holy Gospel; my soul, with the love of Thy Cross; my heart, with the purity of Thy word; my body, with Thy passionless Passion.",
                "Keep my thought in Thy humility, and raise me up at the proper time for Thy glorification. For most glorified art Thou together with Thine unoriginate Father, and the Most-holy Spirit, unto the ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-iii-to-the-holy-spirit",
            title: "Prayer III, to the Holy Spirit",
            paragraphs: [
                "O Lord, Heavenly King, Comforter, Spirit of Truth, show compassion and have mercy on me Thy sinful servant, and loose me from mine unworthiness, and forgive all wherein I have sinned against Thee today as a man, and not only as a man, but even worse than a beast, my sins voluntary and involuntary, known and unknown, whether from youth, and from evil suggestion, or whether from brazenness and despondency. If I have sworn by Thy name, or blasphemed it in my thought; or reproached anyone, or slandered anyone in mine anger, or grieved anyone, or have become angry about anything; or have lied, or slept needlessly, or if a beggar hath come to me and I disdained him; or if I have grieved my brother, or have quarreled, or have condemned anyone; or if I have been boastful, or prideful, or angry; if, as I stood at prayer, my mind hath been distracted by the wiles of this world, or by thoughts of depravity; if I have over-eaten, or have drunk excessively, or laughed frivolously; if I have thought evil, or seen the beauty of another and been wounded thereby in my heart; if I have said improper things, or derided my brother's sin when mine own sins are countless; if I have been neglectful of prayer, or have done some other wrong that I do not remember, for all of this and more than this have I done: have mercy, O Master my Creator, on me Thy downcast and unworthy servant, and loose me, and remit, and forgive me, for Thou art good and the Lover of mankind, so that, lustful, sinful, and wretched as I am, I may lie down and sleep and rest in peace. And I shall worship, and hymn, and glorify Thy most honourable name, together with the Father and His Only-begotten Son, now and ever, and unto the ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-iv-of-st-macarius-the-great",
            title: "Prayer IV, of St. Macarius the Great",
            paragraphs: [
                "What shall I offer Thee, or what shall I give Thee, O greatly-gifted, immortal King, O compassionate Lord Who lovest mankind? For though I have been slothful in pleasing Thee, and have done nothing good, Thou hast led me to the close of this day that is past, establishing the conversion and salvation of my soul. Be merciful to me a sinner, bereft of every good deed, raise up my fallen soul which hath become defiled by countless sins, and take away from me every evil thought of this visible life. Forgive my sins, O Only Sinless One, in which I have sinned against Thee this day, known or unknown, in word, and deed, and thought, and in all my senses. Do Thou Thyself protect and guard me from every opposing circumstance, by Thy Divine authority and power and inexpressible love for mankind. Blot out, O God, blot out the multitude of my sins. Be pleased, O Lord, to deliver me from the net of the evil one, and save my passionate soul, and overshadow me with the light of Thy countenance when Thou shalt come in glory; and cause me, uncondemned now, to sleep a dreamless sleep, and keep Thy servant untroubled by thoughts, and drive away from me all satanic deeds; and enlighten for me the eyes of my heart with understanding, lest I sleep unto death. And send me an angel of peace, a guardian and guide ofmy soul and body, that he may deliver me from mine enemies; that, rising from my bed, I may offer Thee prayers of thanksgiving. Yea, O Lord, hearken unto me, Thy sinful and wretched servant, in confession and conscience; grant me, when I arise, to be instructed by Thy sayings; and through Thine angels cause demonic despondency to be driven far from me: that I may bless Thy holy name, and glorify and extol the most pure Theotokos Mary, whom Thou hast given to us sinners as a protectress, and accept her who prayeth for us. For I know that she exemplifieth Thy love for mankind and prayeth for us without ceasing.",
                "Through her protection, and the sign of the precious Cross, and for the sake of all Thy saints, preserve my wretched soul, O Jesus Christ our God: for holy art Thou, and most glorious for ever.",
                "Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-v",
            title: "Prayer V",
            paragraphs: [
                "O Lord our God, as Thou art good and the Lover of mankind, forgive me wherein I have sinned today in vmrd, deed, and thought. Grant me peaceful and undisturbed sleep; send Thy guardian angel to protect and keep me from all evil. For Thou art lhe Guardian of our souls and bodies, and unto Thee do we send up glory: to lhe Father, and to the Son, and to the Holy Spirit, now and ever, and unto lhe ages of ages. Ai?en."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-vi",
            title: "Prayer VI",
            paragraphs: [
                "O Lord our God, in Whom we believe and Whose name we invoke above every name, grant us, as we go to sleep, relaxation of soul and body, and keep us from all dreams, and dark pleasures; stop the onslaught of the passions and quench the burnings that arise in the flesh. Grant us to live chastely in deed and word, that we may obtain a virtuous life, and not fall away from Thy promised blessings; for blessed art Thou for ever. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-vii-of-st-john-chrysostom-according-t",
            title: "Prayer VII, of St. John Chrysostom, according to the number of hours of day and night",
            paragraphs: [
                "O Lord, deprive me not of Thy heavenly good things. O Lord, deliver me from the eternal torments.",
                "O Lord, if I have sinned in mind or thought, in word or deed, forgive me.",
                "O Lord, deliver me from all ignorance, forgetfulness, faintheartedness, and stony insensibility. O Lord, deliver me from every temptation. O Lord, enlighten my heart which evil desire hath darkened. O Lord, as a man I have sinned, but do Thou, as the compassionate God, have mercy on me, seeing the infirmity of my soul. O Lord, send Thy grace to my help, that I may glorify Thy holy name. O Lord Jesus Christ, write me Thy servant in the Book of Life, and grant me a good end. O Lord my God, even though I have done nothing good in Thy sight, yet grant me by Thy grace to make a good beginning. O Lord, sprinkle into my heart the dew of Thy grace. O Lord of heaven and earth, remember me Thy sinful servant, shameful and unclean, in Thy kingdom. Amen.",
                "O Lord, accept me in penitence. O Lord, forsake me pot. O Lord, lead me not into temptation. O Lord, grant me good thoughts. O Lord, grant me tears, and remembrance of death, and compunction. O Lord, grant me the thought of confessing my sins.",
                "O Lord, grant me humility, chastity, and obedience. O Lord, grant me patience, courage, and meekness. O Lord, implant in me the root of good, Thy fear in my heart. O Lord, vouchsafe me to love Thee with all my soul and thoughts, and in all things to do Thy will. O Lord, protect me from evil men, and demons, and passions, and from every other unseemly thing. O Lord, Thou knowest that Thou doest as Thou wilt: Thy will be done also in me a sinner; for blessed art Thou unto the ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "sleep-prayer-viii-to-our-lord-jesus-christ",
            title: "Prayer VIII, to our Lord Jesus Christ",
            paragraphs: [
                "O Lord Jesus Christ, Son of God, for the sake of Thy most honourable Mother, and Thy bodiless angels, Thy Prophet and Forerunner and Baptist, the God-inspired apostles, the radiant and victorious martyrs, the holy and God-bearing fathers, and through the intercessions of all the saints, deliver me from the besetting presence of the demons. Yea, my Lord and Creator, Who desirest not the death of a sinner, but rather that he be converted and live, grant conversion also to me, wretched and unworthy; rescue me from the mouth of the pernicious serpent, who is yawning to devour me and take me down to hades alive. Yea, my Lord, my Comfort, Who for my miserable sake wast clothed in corruptible flesh, draw me out of misery, and grant comfort to my miserable soul. Implant in my heart to fulfill Thy commandments, and to forsake eil deeds, and to obtain Thy blessings; for in Thee, O Lord, have I hoped, save me."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-ix-to-the-most-holy-theotokos",
            title: "Prayer IX, to the Most Holy Theotokos",
            paragraphs: [
                "O good Mother of the Good King, most pure and blessed Theotokos Mary, do thou pour out the mercy of thy Son and our God upon my passionate soul, and by thine intercessions guide me unto good works, that I may pass the remaining time of my life without blemish, and attain paradise through thee, O Virgin Theotokos, who alone art pure and blessed.",
                "Prayer :X, to the Holy Guardian Angel: O Angel of Christ, my holy guardian and protector of my soul and body, forgive me all wherein I have sinned this day, and deliver me from all opposing evil of mine enemy, lest I anger my God by any sin. Pray for me, a sinful and unworthy servant, that thou mayest show me forth worthy of the kindness and mercy of the All-holy Trinity, and of the Mother of my Lord .Jesus Christ, and of all the saints. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "ioannikios",
            title: "The Prayer of Saint Ioannikios",
            paragraphs: [
                "My hope is the Father, my refuge is the Son, my protection is the Holy Spirit: O Holy Trinity, glory to Thee."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "kontakion-to-the-theotokos",
            title: "Kontakion to the Theotokos",
            paragraphs: [
                "To thee, the Champion Leader, we thy servants dedicate a feast of victory and of thanksgiving as ones rescued out of sufferings, O Theotokos; but as lhou art one with might which is invincible, from all dangers that can be do lhou deliver us, that we may cry to thee: Rejoice, thou Bride Unwedded!",
                "Most glorious, Ever-Virgin, Mother of Christ God, present our prayer to lhy Son and our God, that through thee He may save our souls.",
                "All my hope I place in thee, O Mother of God: keep me under thy protection.",
                "O Virgin Theotokos, disdain not me a sinner, needing thy help and thy protection, and have mercy on me, for my soul hath hoped in thee.",
                "It is truly meet to bless thee, the Theotokos, ever-blessed and most blameless, and Mother of our God.",
                "More honourable than the Cherubim, and beyond compare more glorious than the Seraphim, who without corruption gavest birth to God the Word, the very Theotokos, thee do we magnify.",
                "Glory to the Father, and to the Son, and to the Holy Spirit, both now and ever, and unto the ages of ages. Amen.",
                "Lord, have mercy. Thrice.",
                "O Lord, bless. And the dismissal: O Lord Jesus Christ, Son of God, for the sake of the prayers of Thy most pure Mother, our holy and God-bearing fathers, and all the saints, have mercy on us. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer-of-saint-john-damascene-which-is-to-b",
            title: "Prayer of Saint John Damascene, which is to be said while pointing at thy bed",
            paragraphs: [
                "O Master, Lover of mankind, is this bed to be my coffin, or wilt Thou enlighten my wretched soul with another day? Behold, the coffin lieth before me; behold, death confronteth me. I fear, O Lord, Thy judgment and the endless torments, et I cease not to do evil. My Lord God, I continually anger Thee, and Thy most pure Mother, and all the Heavenly Hosts, and my holy guardian angel. I know, O Lord, that I am unworthy of Thy love for mankind, but am worthy of every condemnation and torment. But, O Lord, whether I will it or not, save me. For to save a righteous man is no great thing, and to have mercy on the pure is nothing wonderful, for they are worthy of Thy mercy. But on me, a sinner, show the wonder of Thy mercy; in this reveal Thy love for mankind, lest my wickedness prevail over Thine ineffable goodness and merciful kindness; and order my life as Thou wilt."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "and-when-about-to-lie-down-in-bed-say-this",
            title: "And when about to lie down in bed, say this",
            paragraphs: [
                "Enlighten mine eyes, O Christ God, lest at any time I sleep unto death, lest at any time mine enemy say: I have prevailed against him.",
                "Glory to the Father, and to the Son, and to the Holy Spirit.",
                "Be my soul's helper, O God, for I pass through the midst of many snares; deliver me out of them, and save me, O Good One, for Thou art the Lover of mankind.",
                "Both now and ever, and unto the ages of ages. Amen.",
                "The most glorious Mother of God, more holy than the holy angels, let us hymn unceasingly with our hearts and mouths, confessing her to be the Theotokos, for truly she gaveth birth to God incarnate for us, and prayeth unceasingly for our souls.",
                "Then kiss thy Cross, and make the sign of the Cross [with the Cross] from the head to the foot of the bed, and likewise from side to side, while saying the Prayer to the Venerable Cross: T et God arise and let His enemies be L scattered, and let them that hate Him flee from before His face. As smoke vanisheth, so let them vanish; as wax melteth before the fire, so let the demons perish from the presence of them that love God and who sign themselves with the sign of the Cross and say in gladness: Rejoice, most venerable and life-giving Cross of the Lord, for Thou drivest away the demons by the power of our Lord Jesus Christ Who was crucified on thee, Who went down to hades and trampled on the power of the devil, and gave us thee, His venerable Cross, for the driving away of every adversary. O most venerable and life-giving Cross of the Lord, help me together with the holy Lady Virgin Theotokos, and with all the saints, unto the ages.",
                "Amen.",
                "Or: Compass me about, O Lord, with the power of Thy precious and life-giving Cross and preserve me from every evil."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "then-instead-of-forgiveness",
            title: "Then, instead of [asking] forgiveness [of anyone else]",
            paragraphs: [
                "Remit, pardon, forgive, O God, our offences, both voluntary and involuntary, in word and deed, in knowledge and ignorance, by day and by night, in mind and thought; forgive us all things, for Thou art good and the Lover of mankind."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "prayer",
            title: "Prayer",
            paragraphs: [
                "O Lord, Lover of mankind, forgive them that hate and wrong us.",
                "Do good to them that do good. Grant our brethren and kindred their saving petitions and life eternal; visit the infirm and grant them healing.",
                "Guide those at sea. Journey with them that travel. Help Orthodox Christians to struggle. To them that serve and are kind to us grant remission of sins. On them that have charged us, the unworthy, to pray for them, have mercy according to Thy great mercy. Remember, O Lord, our fathers and brethren departed before us, and grant them rest where the light of Thy countenance shall visit them. Remember, O Lord, our brethren in captivity, and deliver them from every misfortune.",
                "Remember, O Lord, those that bear fruit and do good works in Thy holy churches, and grant them their saving petitions and life eternal. Remember also, O Lord, us Thy lowly and sinful and unworthy servants, and enlighten our minds with the light of Thy knowledge, and guide us in the way of Thy commandments; through the intercessions of our most pure Lady, the Theotokos and Ever-Virgin Mary, and of all Thy saints, for blessed art Thou unto the ages of ages. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "daily-confession-of-sins",
            title: "Daily Confession of Sins",
            paragraphs: [
                "I confess to Thee, my Lord God and Creator, in one Holy Trinity glorified and worshipped, to the Father, Son, and Holy Spirit, all my sins which I have committed in all the days of my life, and at every hour, at the present time and in the past, day and night, by deed, word, thought, gluttony, drunkenness, secret eating, idle talking, despondency, indolence, contradiction, disobedience, slandering, condemning, negligence, self-love, acquisitiveness, extortion, lying, dishonesty, mercenariness, jealousy, envy, anger, remembrance of wrongs, hatred, bribery; and by all my senses: sight, hearing, smell, taste, touch; and by the rest of my sins, of the soul together with the bodily, through which I have angered Thee, my God and Creator, and dealt unjustly with my neighbour. Sorrowing for these, I stand guilty before Thee, my God, but I have the will to repent. Only help me, O Lord my God, with tears I humbly entreat Thee. Forgive my past sins through Thy compassion, and absolve from all these which I have said in Thy presence, for Thou art good and the Lover of mankind."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        ),
        Prayer(
            id: "when-giving-thyself-up-to-sleep-say",
            title: "When giving thyself up to sleep, say",
            paragraphs: [
                "Into Thy hands, O Lord Jesus Christ my God, I commit my spirit.",
                "Do Thou bless me, do Thou have mercy on me, and grant me life eternal. Amen."
            ],
            source: "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery",
            sourceURL: "https://holytrinitypublications.com/product/prayer-book/"
        )
    ]
}
