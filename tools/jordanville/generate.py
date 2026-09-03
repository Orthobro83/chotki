"""Writes PrayerContent.swift from the parsed sections.

Generated rather than typed: 48 prayers is too many to retype without
introducing exactly the errors the cleaning was for. What is *not* generated is
the judgement — which blocks are prayers, which belong on the rope, and what
each is called. That is the table below, and it is meant to be read.
"""
import json, re, sys

SOURCE = "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery"
SOURCE_URL = "https://holytrinitypublications.com/product/prayer-book/"

# Blocks that are the book's own directions rather than prayers. They are the
# rubric of what follows, not something anyone says.
SKIP = {
    ("morning", "Morning Prayers"),          # the book's opening direction
    ("sleep", "Prayers Before Sleep"),       # the same opening prayers again
}

# Said on the rope. Short, repeated, and traditionally counted — which is the
# whole test. Everything else is read once.
ON_THE_ROPE = {"publican", "jesus-prayer", "jesus-prayer-short", "lord-have-mercy",
               "rejoice-o-virgin"}

# Jordanville runs the opening of the Morning Prayers together under one
# heading, but they are five prayers with five names, and the app has always
# let someone choose "O Heavenly King" on its own. Splitting them keeps that,
# keeps the ids a rule already on someone's phone is pointing at, and takes
# nothing from the book but its wording.
#
# Written out rather than inferred: where the divisions fall is a judgement,
# and a judgement belongs somewhere it can be read and argued with.
OPENING = ["opening-prayer", "beginning", "heavenly-king", "trisagion",
           "all-holy-trinity", "our-father"]

SPLIT = {
    ("morning", "The Beginning Prayer"): [
        ("opening-prayer", "The Opening Prayer", "Said first of all.", [0]),
        ("beginning", "The Beginning", "How every rule opens.", [1]),
        ("heavenly-king", "O Heavenly King",
         "To the Holy Spirit. Not said between Pascha and Pentecost.", [2]),
        ("trisagion", "The Trisagion", "Said three times.", [3, 4]),
        ("all-holy-trinity", "O Most Holy Trinity", None, [5, 6, 7]),
        ("our-father", "Our Father", None, [8]),
    ],
}

# Slugs, so a rule taken on before this change still finds its prayers where
# the ids match the old ones.
RENAME = {
    "The Prayer of the Publican": "publican",
    "The Beginning Prayer": "beginning-prayer",
    "Song to the Most Holy Theotokos": "rejoice-o-virgin",
    "The Symbol of the Orthodox Faith": "creed",
    "Psalm 50": "psalm-50",
    # The book heads this "Final Prayer"; everyone knows it by its first words,
    # and the app has always called it that.
    "Final Prayer": "it-is-truly-meet",
}

# The book prints these inside a longer block, but they are prayers in their
# own right and the app already names them — St Ioannikios' is buried in the
# Kontakion at the end of the Before Sleep prayers.
LIFT = {
    ("sleep", "Kontakion to the Theotokos", 4):
        ("ioannikios", "The Prayer of Saint Ioannikios", None),
}

def slug(title):
    if title in RENAME: return RENAME[title]
    s = title.lower()
    s = s.replace("[breakfast and] ", "").replace("[asking] ", "").replace("[of anyone else]", "")
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return re.sub(r"-+", "-", s)[:44].rstrip("-")

def swift(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def main():
    out, ids = [], {}
    for section in ["morning", "day", "sleep"]:
        blocks = json.load(open(f"out/{section}.json"))
        section_ids = []
        for b in blocks:
            title = (b["title"] or "").strip()
            if not title or (section, title) in SKIP: continue
            if (section, title) in SPLIT:
                for pid, ptitle, rubric, which in SPLIT[(section, title)]:
                    ids[pid] = True
                    section_ids.append(pid)
                    paras = ",\n".join(
                        f'                "{swift(b["paragraphs"][i])}"' for i in which)
                    rub = f'\n            rubric: "{swift(rubric)}",' if rubric else ""
                    out.append(f'''        Prayer(
            id: "{pid}",
            title: "{swift(ptitle)}",{rub}
            paragraphs: [
{paras}
            ],
            source: "{SOURCE}",
            sourceURL: "{SOURCE_URL}"
        )''')
                continue

            pid = f"{slug(title)}"
            if pid in ids: pid = f"{section}-{pid}"
            body = []
            for idx, para in enumerate(b["paragraphs"]):
                key = (section, title, idx)
                if key in LIFT:
                    lid, ltitle, lrubric = LIFT[key]
                    ids[lid] = True
                    section_ids.append(lid)
                    rub = f'\n            rubric: "{swift(lrubric)}",' if lrubric else ""
                    out.append(f'''        Prayer(
            id: "{lid}",
            title: "{swift(ltitle)}",{rub}
            paragraphs: [
                "{swift(para)}"
            ],
            source: "{SOURCE}",
            sourceURL: "{SOURCE_URL}"
        )''')
                    continue
                body.append(para)
            if not body: continue
            ids[pid] = True
            section_ids.append(pid)
            paras = ",\n".join(f'                "{swift(x)}"' for x in body)
            rope = ",\n            isForRope: true" if pid in ON_THE_ROPE else ""
            out.append(f'''        Prayer(
            id: "{pid}",
            title: "{swift(title)}",
            paragraphs: [
{paras}
            ],
            source: "{SOURCE}",
            sourceURL: "{SOURCE_URL}"{rope}
        )''')
        print(f"// {section}: {len(section_ids)} prayers", file=sys.stderr)
        # Before Sleep opens with the same Trisagion prayers as the morning.
        # The book prints them twice; the app names them once and both rules
        # point at them, so a correction to "O Heavenly King" cannot land in
        # one rule and miss the other.
        if section == "sleep":
            section_ids = OPENING + section_ids
        print(f'    static let {section}IDs = [' +
              ", ".join(f'"{i}"' for i in section_ids) + "]", file=sys.stderr)
    print(",\n".join(out))

main()
