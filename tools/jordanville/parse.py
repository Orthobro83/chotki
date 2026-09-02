"""Turns a cleaned section into titled prayers with paragraphs.

The book marks a prayer with a heading ending in a colon; a heading sometimes
wraps onto a second line, which is rejoined first. Everything between headings
is the prayer, wrapped lines rejoined into paragraphs.
"""
import json, re, sys

# Short directions the book sets in italics. The scan loses the italics, so
# they are recognised by being exactly these words on a line of their own.
RUBRIC_WORDS = re.compile(
    r'^(Thrice|Twice|Twelve|Forty|Three bows|Bow|A bow|Then|And the dismissal)\.?$', re.I)

def parse(text):
    lines = [l.rstrip() for l in text.split("\n")]

    # Rejoin a heading that wrapped: "Prayer VII," then "to the Theotokos:"
    joined, i = [], 0
    while i < len(lines):
        line = lines[i]
        # A heading can run to three lines — "Prayer VII, of St. John
        # Chrysostom, / according to the number of hours of / day and night:"
        # so gather until one ends in a colon rather than assuming two.
        if (
            not re.match(r'^[A-Z][A-Z \'0-9,.-]{5,}$', line)      # not a banner
            and re.match(r'^[A-Z][A-Za-z .,\[\]\'-]{2,60}$', line)
            and not line.rstrip().endswith((".", ":", "!", "?"))
        ):
            run, j = [line], i + 1
            while j < len(lines) and len(run) < 3:
                run.append(lines[j])
                if lines[j].rstrip().endswith(":"):
                    break
                if lines[j].rstrip().endswith((".", "!", "?")) or not lines[j].strip():
                    run = None
                    break
                j += 1
            if run and run[-1].rstrip().endswith(":") and len(" ".join(run)) < 110:
                joined.append(" ".join(x.strip().rstrip(",") + ("," if x.strip().endswith(",") else "")
                                       for x in run))
                i = j + 1
                continue

        joined.append(line)
        i += 1

    prayers, current = [], None
    for line in joined:
        if not line.strip():
            continue
        # A heading is a phrase ending in a colon. A line of prayer that ends
        # in one — "O Lord, bless. Or:" — is not, and is told apart by holding
        # a finished sentence: a word, a stop, a space, a capital. "St." and
        # its like are abbreviations, not sentence ends, so they are exempt.
        sentence = re.search(r'\b(?!St|Ss|Fr|Mt|Mk|Lk|Jn)[A-Za-z]{2,}\. [A-Z]', line)
        heading = re.match(r'^[A-Z][^:]{2,90}:$', line) and not sentence
        if heading:
            if current: prayers.append(current)
            current = {"title": line[:-1].strip(), "lines": []}
        elif re.match(r'^[A-Z][A-Z \'0-9,.-]{5,}$', line):  # a section banner
            if current: prayers.append(current)
            current = {"title": line.title().strip(), "lines": [], "banner": True}
        else:
            if current is None:
                current = {"title": None, "lines": []}
            current["lines"].append(line)
    if current: prayers.append(current)

    # Wrapped lines become paragraphs. A line ending in a sentence stop, or a
    # short direction on its own, closes one.
    for p in prayers:
        paras, buf = [], []
        for line in p.pop("lines"):
            if RUBRIC_WORDS.match(line.strip()):
                if buf: paras.append(" ".join(buf)); buf = []
                paras.append(line.strip())
                continue
            buf.append(line)
            if re.search(r'[.!?]"?$', line):
                paras.append(" ".join(buf)); buf = []
        if buf: paras.append(" ".join(buf))
        p["paragraphs"] = [re.sub(r'\s+', ' ', x).strip() for x in paras if x.strip()]
    return [p for p in prayers if p.get("paragraphs")]

if __name__ == "__main__":
    out = parse(open(sys.argv[1], encoding="utf-8").read())
    json.dump(out, open(sys.argv[2], "w"), indent=1, ensure_ascii=False)
    print(f"{sys.argv[1]}: {len(out)} blocks")
    for p in out[:40]:
        print(f"   {(p['title'] or '(untitled)')[:60]:62} {len(p['paragraphs'])} paras")
