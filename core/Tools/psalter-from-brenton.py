#!/usr/bin/env python3
"""Turns Brenton's Septuagint Psalms into the Psalter the app carries.

Brenton's translation was published in 1851 and is in the public domain. The
machine-readable USFM comes from eBible.org, proofread rather than scanned —
which matters, because the alternative for liturgical text is OCR, and an OCR
error in a psalm is an error in a psalm, not a typo.

    curl -O https://ebible.org/Scriptures/eng-Brenton_usfm.zip
    unzip eng-Brenton_usfm.zip 20-PSAeng-Brenton.usfm
    python3 core/Tools/psalter-from-brenton.py 20-PSAeng-Brenton.usfm

Septuagint numbering throughout, which is what the Orthodox Psalter uses and
what the kathisma divisions are stated in. Psalm 151 is included and belongs to
no kathisma.

Nothing here is retyped. If the wording is wrong, it is wrong in Brenton, and
that can be checked against the source rather than argued about.
"""
import json
import re
import sys
from pathlib import Path


def clean(text: str) -> str:
    """Strips USFM markup, keeping the words and nothing else."""
    # Footnotes and cross-references sit inline and are apparatus, not psalm.
    text = re.sub(r"\\f\s.*?\\f\*", "", text)
    text = re.sub(r"\\x\s.*?\\x\*", "", text)
    # Character styles: \add supplied\add*, \sc Blessed\sc*. The words stay;
    # the typography does not survive the trip and never needed to.
    text = re.sub(r"\\\+?[a-z0-9]+\*", "", text)
    text = re.sub(r"\\\+?[a-z0-9]+\s?", "", text)
    return re.sub(r"\s+", " ", text).strip()


def parse(usfm: str) -> list[dict]:
    psalms: list[dict] = []
    current: dict | None = None
    titled = False

    for line in usfm.splitlines():
        line = line.rstrip()
        if line.startswith("\\c "):
            current = {"number": int(line.split()[1]), "superscription": None, "verses": []}
            psalms.append(current)
            titled = False
        elif line.startswith("\\d"):
            # A superscription opens here and runs until the first \p. In
            # Septuagint numbering the title is counted as verse 1, which is why
            # the psalms that have one begin their body at verse 2 — and Psalm
            # 50, whose title runs to two verses, begins at verse 3. Taking only
            # the first verse silently cut that one in half.
            titled = True
        elif line.startswith("\\p") and titled:
            titled = False
        elif line.startswith("\\v ") and current is not None:
            rest = line[3:].lstrip()
            number, _, body = rest.partition(" ")
            words = clean(body)
            if not words:
                continue
            if titled:
                current["superscription"] = (
                    f"{current['superscription']} {words}"
                    if current["superscription"]
                    else words
                )
            else:
                # Kept as written: Brenton splits some verses, "4a" and "4b".
                current["verses"].append({"number": number, "text": words})
    return psalms


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    psalms = parse(Path(sys.argv[1]).read_text(encoding="utf-8"))

    if len(psalms) != 151:
        print(f"expected 151 psalms, parsed {len(psalms)}", file=sys.stderr)
        return 1
    for psalm in psalms:
        if not psalm["verses"]:
            print(f"psalm {psalm['number']} has no verses", file=sys.stderr)
            return 1

    document = {
        "source": "Brenton, The Septuagint Version of the Old Testament, 1851",
        "sourceURL": "https://ebible.org/find/show.php?id=eng-Brenton",
        "numbering": "septuagint",
        "psalms": psalms,
    }
    text = json.dumps(document, ensure_ascii=False, indent=2, sort_keys=False) + "\n"

    here = Path(__file__).resolve().parent.parent.parent
    for destination in (
        here / "core/Sources/ChotkiCore/Resources/psalter.json",
        here / "android/core/src/main/resources/content/psalter.json",
    ):
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text, encoding="utf-8")
        print(f"wrote {destination.relative_to(here)}")

    verses = sum(len(p["verses"]) for p in psalms)
    titles = sum(1 for p in psalms if p["superscription"])
    print(f"{len(psalms)} psalms, {titles} superscriptions, {verses} verses")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
