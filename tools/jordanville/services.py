"""Cuts the service sections out of the cleaned book.

The list is the book's own table of contents, in the book's order, with the
line each section starts on. Written down rather than detected: the banners are
inconsistently cased and sometimes split across lines, and a section boundary
guessed wrong silently moves text from one service into another.
"""
import json, re, sys
from clean import clean

SECTIONS = [
    (1401, "vespers", "Selections from Vespers"),
    (1545, "matins", "Selections from Matins"),
    (2127, "divine-liturgy", "The Divine Liturgy of Saint John Chrysostom"),
    (3240, "sunday-troparia", "Sunday Troparia and Kontakia"),
    (3394, "daily-troparia", "Daily Troparia and Kontakia"),
    (3528, "twelve-feasts", "Troparia and Kontakia of the Twelve Feasts"),
    (3729, "triodion", "Troparia, Kontakia, Prayers and Stichera from the Triodion"),
    (4100, "passion-week", "Passion Week Troparia"),
    (4223, "pascha", "Pascha"),
    (4644, "paschal-hours", "The Hours of Holy Pascha"),
    (4742, "pentecostarion", "Troparia and Kontakia from the Pentecostarion"),
    (4963, "canon-to-jesus", "A Supplicatory Canon to our Lord Jesus Christ"),
    (5312, "canon-to-theotokos", "Supplicatory Canon to the Most Holy Theotokos"),
    (5673, "canon-to-guardian-angel", "Canon to the Guardian Angel"),
    (6061, "akathist-to-jesus", "Akathist to Our Sweetest Lord Jesus"),
    (6609, "akathist-to-theotokos", "Akathist to Our Most Holy Lady the Theotokos"),
    (7216, "canon-of-repentance", "Canon of Repentance to Our Lord Jesus Christ"),
    (7588, "preparation-for-communion", "The Order of Preparation for Holy Communion"),
    (8687, "after-communion", "Prayers after Holy Communion"),
    (8973, "praying-in-church", "How One Should Pray in Church"),
    (9100, "bows-and-the-cross", "Rules for Bows and the Sign of the Cross"),
    (9199, "canons-when-alone", "The Order for Reading Canons and Akathists When Alone"),
    (9299, "the-jesus-prayer", "Concerning the Jesus Prayer"),
]

SOURCE = "Jordanville Prayer Book, 4th ed. rev., Holy Trinity Monastery"
SOURCE_URL = "https://holytrinitypublications.com/product/prayer-book/"

def paragraphs(text):
    """Wrapped lines become paragraphs; a line ending in a stop closes one."""
    out, buf = [], []
    for line in text.split("\n"):
        line = line.strip()
        if not line:
            continue
        if re.match(r'^[A-Z][A-Z \'0-9,.:-]{4,}$', line):     # a banner or a tone
            if buf: out.append(" ".join(buf)); buf = []
            out.append(line)
            continue
        buf.append(line)
        if re.search(r'[.!?]["\']?$', line):
            out.append(" ".join(buf)); buf = []
    if buf: out.append(" ".join(buf))
    return [re.sub(r'\s+', ' ', p).strip() for p in out if p.strip()]

def main(raw_path, out_path):
    lines = open(raw_path, encoding="utf-8", errors="ignore").read().split("\n")
    texts = []
    for i, (start, slug, title) in enumerate(SECTIONS):
        end = SECTIONS[i + 1][0] - 1 if i + 1 < len(SECTIONS) else len(lines)
        body = clean("\n".join(lines[start:end]))          # start: drop the banner
        texts.append({"id": slug, "title": title, "paragraphs": paragraphs(body)})
    json.dump({"source": SOURCE, "sourceURL": SOURCE_URL, "texts": texts},
              open(out_path, "w"), indent=1, ensure_ascii=False)
    for t in texts:
        print(f"  {t['title'][:52]:54} {len(t['paragraphs']):4} paragraphs")

main(sys.argv[1], sys.argv[2])
