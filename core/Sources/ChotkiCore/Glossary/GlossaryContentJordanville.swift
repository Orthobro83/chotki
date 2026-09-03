import Foundation

// Words the Jordanville prayer book brought with it.
//
// Mostly compound epithets — "All-holy", "Life-giver", "Bride Unwedded" —
// which are Greek titles carried into English almost word for word. They read
// as strange because they *are* strange: English does not usually build words
// that way, and a newcomer meets four of them in the first page.
//
// These explain what a word means so that someone can say it knowing what they
// are saying. They are not doctrine and do not try to be; where a term carries
// more weight than a sentence can hold, the entry says so and points at a
// priest rather than pretending otherwise.
extension Glossary {

    static let jordanvilleWords: [GlossaryEntry] = [

        GlossaryEntry(
            slug: "all-holy", term: "All-holy",
            short: "Wholly holy — a title given to the Theotokos and to the Holy Spirit.",
            full: """
            English would say "most holy". The Greek builds one word, panagia, and the \
            translators kept the shape of it.

            Used of the Theotokos above all — in Greek she is simply "the Panagia" — and of \
            the Holy Spirit. It is not a comparison with anyone else. It says the holiness \
            goes all the way through.
            """,
            category: .prayer
        ),

        GlossaryEntry(
            slug: "most-holy", term: "Most-holy",
            short: "The same title as All-holy, spelt the other way in English.",
            full: """
            "Most-holy Theotokos, save us" and "O my most holy lady Theotokos" render the same \
            Greek word the prayers elsewhere give as All-holy. The hyphen is a sign that one \
            Greek word stands behind two English ones.
            """,
            category: .prayer
        ),

        GlossaryEntry(
            slug: "most-good", term: "Most-good",
            short: "Wholly good. Addressed to God, in the same shape as All-holy.",
            full: """
            "O Most-good Lord" — another compound built the Greek way. It is not "quite good" \
            or "better than others"; it says goodness with nothing else mixed in.
            """,
            category: .prayer
        ),

        GlossaryEntry(
            slug: "forerunner", term: "Forerunner",
            short: "Saint John the Baptist — the one who went ahead of Christ.",
            full: """
            The usual Orthodox name for John the Baptist. Prodromos in Greek: the one who runs \
            in front. He came before Christ, announced him, and baptised him.

            You will meet him under three names in the same book — the Forerunner, the Baptist, \
            and John — and they are one man.
            """,
            category: .saints,
            related: ["baptist"]
        ),

        GlossaryEntry(
            slug: "baptist", term: "Baptist",
            short: "Saint John, who baptised Christ in the Jordan.",
            full: """
            Not a denomination. In Orthodox prayers "the Baptist" is always Saint John, cousin \
            of Christ, who preached repentance in the desert and baptised him in the river \
            Jordan.

            Usually named alongside the Theotokos when the prayers ask the saints to pray for \
            us, because the two of them stand nearest Christ.
            """,
            category: .saints,
            related: ["forerunner"]
        ),

        GlossaryEntry(
            slug: "ever-virgin", term: "Ever-Virgin",
            short: "A title of the Theotokos: virgin before, during and after the Nativity.",
            full: """
            Aeiparthenos in Greek. The Church has held from early on that the Virgin Mary \
            remained a virgin, and the title says so in one word.

            It is a point where Orthodox teaching differs from much of Western Christianity, \
            and it carries more than a glossary line can hold. Your priest or spiritual father \
            is the person to ask.
            """,
            category: .faith
        ),

        GlossaryEntry(
            slug: "bride-unwedded", term: "Bride", aliases: ["Unwedded", "Bride Unwedded"],
            short: "A title of the Theotokos — a bride who was never wed.",
            full: """
            "Rejoice, O Bride Unwedded" ends the Akathist to the Theotokos and turns up through \
            the prayers. Nymphe anymphefte in Greek, which sounds like a riddle in that language \
            too.

            It holds two things at once: she is the bride — the one wholly given to God — and \
            she was never married. The strangeness of the phrase is the point of it.
            """,
            category: .prayer,
            related: ["ever-virgin"]
        ),

        GlossaryEntry(
            slug: "champion-leader", term: "Champion", aliases: ["Champion Leader"],
            short: "The Theotokos as defender — the one who fights on our side.",
            full: """
            "To thee, the Champion Leader, we thy servants dedicate a feast of victory" opens \
            the Kontakion sung at the end of the evening prayers.

            A champion here is what the word once meant in English: not a winner, but the one \
            who goes out to fight for you. The hymn was written after Constantinople survived a \
            siege, and it thanks her as the city's defender.
            """,
            category: .prayer
        ),

        GlossaryEntry(
            slug: "god-bearing", term: "God-bearing",
            short: "Carrying God within — said of the saints and the holy fathers.",
            full: """
            Theophoros in Greek. Said of someone in whom God plainly dwells, and used almost as \
            a surname for the fathers of the Church: "our holy and God-bearing fathers".

            Not the same as Theotokos, which means God-bearer in the sense of giving birth to \
            him, and belongs to the Virgin alone.
            """,
            category: .saints,
            related: ["theotokos"]
        ),

        GlossaryEntry(
            slug: "god-pleaser", term: "God-pleaser",
            short: "A saint — someone whose life was pleasing to God.",
            full: """
            "Pray unto God for me, O holy God-pleaser N." — the prayer to the saint whose name \
            you bear, where N. stands for that saint's name.

            Ugodnik Bozhiy in Slavonic. It is simply what a saint is: not a perfect person, but \
            one who pleased God.
            """,
            category: .saints
        ),

        GlossaryEntry(
            slug: "god-inspired", term: "God-inspired",
            short: "Breathed into by God — said of scripture and of the fathers who wrote it down.",
            full: """
            Theopneustos, literally God-breathed. Saint Paul uses it of the scriptures; the \
            prayers use it of the fathers and their writings.

            It says where the words came from, not that the person who wrote them stopped being \
            themselves.
            """,
            category: .scripture
        ),

        GlossaryEntry(
            slug: "life-giver", term: "Life-giver", aliases: ["life-creating"],
            short: "The one who gives life — Christ, and the Holy Spirit.",
            full: """
            "O bearer of God the Life-giver" addresses the Theotokos and calls her son the \
            Life-giver. "Thine All-holy and good and life-creating Spirit" says the same of the \
            Holy Spirit.

            Life here is not only being alive. It is the life the Church means when it speaks of \
            eternal life, which begins now.
            """,
            category: .faith
        ),

        GlossaryEntry(
            slug: "light-bearing", term: "Light-bearing",
            short: "Carrying light. Said of angels, of Pascha, and of the life to come.",
            full: """
            Light runs through Orthodox prayer as the plainest word available for God's presence \
            — so an angel is light-bearing, the night of Pascha is light-bearing, and so is the \
            day the prayers hope for.
            """,
            category: .prayer,
            related: ["unwaning"]
        ),

        GlossaryEntry(
            slug: "unwaning", term: "Unwaning",
            short: "Never fading. Said of light that does not dim, unlike the moon's.",
            full: """
            "O bearer of the Unwaning Light" — the Theotokos, and the light is Christ.

            To wane is what the moon does as it shrinks night by night. Unwaning light is light \
            that never does: it does not rise, set, or grow less.
            """,
            category: .prayer,
            related: ["light-bearing"]
        ),

        GlossaryEntry(
            slug: "cross", term: "Cross",
            short: "The Cross of Christ, and the sign made with the hand.",
            full: """
            Both things at once. The Cross Christ died on, and the sign a person makes over \
            themselves — right hand, three fingers joined for the Trinity and two folded for \
            Christ's divinity and humanity, touching forehead, stomach, right shoulder, left \
            shoulder.

            Orthodox Christians cross from right to left, which is one of the visible \
            differences from Western practice.
            """,
            category: .things
        ),

        GlossaryEntry(
            slug: "prophet", term: "Prophet",
            short: "One who speaks for God — usually the Old Testament figures.",
            full: """
            Not primarily someone who predicts the future. A prophet is someone God speaks \
            through: Moses, Elijah, Isaiah, David.

            The prayers name them alongside the apostles and martyrs when they ask the whole \
            Church, living and departed, to pray with us.
            """,
            category: .scripture
        ),

        GlossaryEntry(
            slug: "orthodox", term: "Orthodox",
            short: "Right belief, or right worship — the Church this book belongs to.",
            full: """
            From two Greek words: orthos, straight or right, and doxa, which means both belief \
            and glory. So it is read either way — believing rightly, or glorifying rightly — and \
            the Church has never much minded which.

            Used in these prayers of the Church itself, and of its people: "Orthodox Christians", \
            "the Orthodox faith".
            """,
            category: .faith
        ),

        GlossaryEntry(
            slug: "satan", term: "Satan",
            short: "The adversary. The evil one the prayers ask to be delivered from.",
            full: """
            A Hebrew word meaning the accuser or adversary. The prayers name him plainly and ask \
            for deliverance, and then move on — Orthodox prayer spends very little time on him.

            "Deliver us from the evil one" at the end of the Our Father is the same request.
            """,
            category: .faith
        ),

        GlossaryEntry(
            slug: "tartarus", term: "Tartarus",
            short: "The lowest depths — a word the prayers borrow for hell.",
            full: """
            Greek, and older than Christianity: in the poets it is the pit beneath the \
            underworld. The prayers use it for the depths a soul fears falling to.

            What the Church actually teaches about hell is not settled by a word borrowed from \
            Homer, and is a question for your priest or spiritual father.
            """,
            category: .faith
        ),
    ]
}
