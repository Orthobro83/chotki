import Foundation

// The seven reflections, from the Brotherhood of the Narrow Path.
//
// Transcribed verbatim from the source and **not to be reworded**. Sunday is
// the first, running through to Saturday, which is the order they were given in
// and the order the week is read in. Saturday's directs the reader to liturgy
// and confession; its `notice` is longer than the rest and that is expected.
//
// These are seeded on installation and are editable afterwards. Seeding them is
// not the same as enabling anything: the seven *questions* are the section's
// content, while the seven *rules* that answer them stay opt-in from the
// library, because nothing in this app is enabled by default.
extension Reflection {

    /// The wording as it shipped. `Store` seeds from this, and
    /// `matchesBundled` compares against it.
    public static let bundled: [Reflection] = [
        Reflection(
            weekday: .sunday,
            question: ReflectionQuestion(
                title: "Notice the Resistance",
                notice:
                    "Pay attention today to the moments where you feel resistance, irritation, or quiet refusal. Not the big things. The small ones. The conversation you avoided. The prayer you skipped. The moment you reached for your phone instead of sitting with a thought.",
                task:
                    "Write down two or three moments where you felt resistance. Do not analyze them yet. Just notice."
            )
        ),
        Reflection(
            weekday: .monday,
            question: ReflectionQuestion(
                title: "Notice the Quiet",
                notice:
                    "Pay attention to where your inner life has gone silent. Where have you stopped praying about something you used to pray about? Where have you stopped caring about something you used to care about?",
                task:
                    "At the end of the day, write down one area of your life that has quietly gone silent."
            )
        ),
        Reflection(
            weekday: .tuesday,
            question: ReflectionQuestion(
                title: "Notice the Comfort",
                notice:
                    "Pay attention to the things you reach for to soothe yourself. Phone. Food. Music. Distraction. Not to judge them. Just to see them.",
                task:
                    "At the end of the day, write down what you reach for when you do not want to feel something."
            )
        ),
        Reflection(
            weekday: .wednesday,
            question: ReflectionQuestion(
                title: "Notice the Avoidance",
                notice:
                    "Pay attention to what you are avoiding. The conversation you keep putting off. The confession you have not scheduled. The relationship you are letting drift. The thought you keep pushing away.",
                task:
                    "At the end of the day, write down one thing you have been avoiding."
            )
        ),
        Reflection(
            weekday: .thursday,
            question: ReflectionQuestion(
                title: "Notice the Pattern",
                notice:
                    "Look back at what you have written so far this week. What is the pattern? What keeps showing up?",
                task:
                    "At the end of the day, write down what you are starting to see about yourself."
            )
        ),
        Reflection(
            weekday: .friday,
            question: ReflectionQuestion(
                title: "Notice the Cost",
                notice:
                    "If you keep going the way you have been going, where does it lead? Look at the patterns honestly. What is this costing you spiritually? What is it costing the people around you?",
                task:
                    "At the end of the day, write down what you are putting at risk by staying where you are."
            )
        ),
        Reflection(
            weekday: .saturday,
            question: ReflectionQuestion(
                title: "Bring It Forward",
                notice:
                    "Look at everything you have written this week. This is the honest picture of where you are. Identify one thing from this week's noticing that you need to bring to confession. Identify one thing you want to talk to your spiritual father about. Go to liturgy. Stand. Pay attention. Receive communion if you are prepared and have your priest's blessing.",
                task:
                    "At the end of the day, write down what you are taking forward from this week and what changes when you do."
            )
        )
    ]

    /// What the section is for, behind the help mark beside its title.
    ///
    /// Ryan's words. In `core` for the same reason `Welcome` is: the
    /// alternative is the same paragraph typed into three languages, which is
    /// how the Mac and Android came to disagree about several other things.
    ///
    /// The link is `Welcome.brotherhoodURL`, already in the app and already
    /// his — not a second address for the same place.
    public static let explainer: [WelcomeParagraph] = [
        WelcomeParagraph([
            WelcomeSpan(
                "Most people walk into Christianity expecting peace and comfort. But a "
                + "spiritual life that feels peaceful isn't always one that's making "
                + "progress. This section gives you the opportunity to reflect on your "
                + "spiritual life every day, to track your progress week to week, month "
                + "to month, year to year.")
        ]),
        WelcomeParagraph([
            WelcomeSpan(
                "It is a journal for you to engage with every day. Each day has a "
                + "question which presents you with an opportunity to reflect on aspects "
                + "of your spiritual life. The default questions come from Father Moses' "),
            WelcomeSpan("Brotherhood of the Narrow Path", url: Welcome.brotherhoodURL),
            WelcomeSpan(
                ", but you can customize them as needed. It is strongly recommended that "
                + "you make these customizations in consultation with your priest or "
                + "spiritual father.")
        ]),
        WelcomeParagraph([
            WelcomeSpan("Click \"\(addAsRuleLabel)\" to put Reflection into your daily routine.")
        ])
    ]

    /// The button that puts the seven on the rule, named once so the explainer
    /// and the control it names cannot drift apart.
    public static let addAsRuleLabel = "Add this as a daily rule"

    /// What the library says about it. Short on purpose: the long version is
    /// one click away and repeating it in a list is how the library came to
    /// have seven near-identical paragraphs in it.
    public static let libraryNote =
        "Taking it on puts one item on every day. What you write is kept against the date "
        + "and can be read back over months.\n\nClick on the Reflections tab to learn more."

    /// What closes the week, shown at the foot of the section.
    ///
    /// Verbatim from the source and **not to be reworded**. This is the one
    /// piece of fixed copy in the app that tells the reader to do something; it
    /// is kept because it names who to ask — a priest, confession — which is
    /// what the app is meant to do instead of instructing, and because it is
    /// quoted material rather than the app's own voice.
    public static let closingText: [String] = [
        "If this week showed you something uncomfortable, that is the point. You cannot fight what you cannot see. Now you can see it.",
        "Take what you noticed to your priest. Bring it to confession. Pray about it. Do not try to fix everything yourself. The point of this week was not to become a different person in seven days. The point was to stop pretending you do not need to change."
    ]

    /// The bundled wording for one weekday.
    ///
    /// Total by construction: `bundled` holds all seven and a `Weekday` has no
    /// eighth case, so the lookup cannot fail. The precondition guards against
    /// someone later shortening the list rather than against a bad argument.
    public static func bundled(for weekday: Weekday) -> Reflection {
        guard let found = bundled.first(where: { $0.weekday == weekday }) else {
            preconditionFailure("no bundled reflection for \(weekday) — the seven are incomplete")
        }
        return found
    }
}
