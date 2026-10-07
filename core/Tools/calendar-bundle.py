#!/usr/bin/env python3
"""Build the bundled church calendar from audited Orthocal output.

Reads the *sanitised* day files (every verse public-domain KJV, Lash composites already
replaced; see the audit that produced them) and writes, under
core/Sources/ChotkiCore/Resources/calendar/:

  manifest.json         what the bundle covers and where it came from
  strings.json          every distinct phrase once; day records point into it
  <reckoning>-<year>.json   one file per reckoning-year; days in date order
  kjv.json              the whole KJV (with Apocrypha) the readings are resolved from,
                        each verse once, with the verses that open a paragraph
  composites.json       citation of each of Orthocal's Composite readings, as verse runs

Readings are stored as verse *runs* (book, chapter, first, last), never as text. The app
resolves them from kjv.json, so the licence audit is one file and a year of the calendar
costs very little.

Nothing here talks to a network. Stdlib only.

  calendar-bundle.py --sanitised DIR --db orthocal.sqlite --composites composites.json \
                     --commit SHA --generated-at 2026-10-06 [--out DIR]
"""
import argparse, json, sqlite3, sys
from collections import OrderedDict
from pathlib import Path

RECKONING = {"julian": "julian", "gregorian": "revisedJulian"}   # Orthocal's endpoint -> the app's name
HERE = Path(__file__).resolve().parent


def fnv1a64(data: bytes, h: int = 0xcbf29ce484222325) -> int:
    for b in data:
        h ^= b
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


def contiguous(prev, cur):
    """Do two verses read on from each other (same chapter, or into verse 1 of the next)?"""
    if prev is None:
        return True
    if prev[0] != cur[0]:
        return False
    if prev[1] == cur[1]:
        return cur[2] == prev[2] + 1
    return cur[1] == prev[1] + 1 and cur[2] == 1


def join(verses):
    """verses: [(book, chapter, verse, text, opensParagraph)] -> one string.

    A paragraph break (blank line) comes before a verse that opens a paragraph, and before a
    verse that does not follow on from the one before it (separate passages must not run
    together). Otherwise verses are joined by a single space. The first verse never gets one.
    """
    out, prev = [], None
    for book, ch, v, text, para in verses:
        key = (book, ch, v)
        if out:
            out.append("\n\n" if (para or not contiguous(prev, key)) else " ")
        out.append(text)
        prev = key
    return "".join(out)


def runs_of(verses):
    runs = []
    for book, ch, v in verses:
        if runs and runs[-1][0] == book and runs[-1][1] == ch and runs[-1][3] + 1 == v:
            runs[-1][3] = v
        else:
            runs.append([book, ch, v, v])
    return runs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sanitised", required=True)
    ap.add_argument("--db", required=True, help="the local Orthocal sqlite database (for the KJV table)")
    ap.add_argument("--composites", required=True)
    ap.add_argument("--commit", required=True, help="Orthocal commit the data came from")
    ap.add_argument("--generated-at", required=True, help="YYYY-MM-DD, written into the manifest")
    ap.add_argument("--out", default=str(HERE.parent / "Sources/ChotkiCore/Resources/calendar"))
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for old in out.glob("*.json"):
        old.unlink()

    # ---- the Bible: every KJV verse once, with paragraph openers --------------------------
    con = sqlite3.connect(args.db)
    rows = con.execute(
        "select book, chapter, verse, content, paragraph_start from bible_verse "
        "where language='en' and translation='kjv' order by book, chapter, verse").fetchall()
    bible, text_of, para_of = OrderedDict(), {}, {}
    for book, ch, v, content, para in rows:
        text_of[(book, ch, v)] = content
        para_of[(book, ch, v)] = bool(para)
        chapters = bible.setdefault(book, OrderedDict())
        chapters.setdefault(ch, {"v": {}, "p": []})
        chapters[ch]["v"][v] = content
        if para:
            chapters[ch]["p"].append(v)
    kjv = {}
    for book, chapters in bible.items():
        last = max(chapters)
        arr = []
        for ch in range(1, last + 1):
            c = chapters.get(ch)
            if c is None:
                arr.append({"v": [], "p": []})
                continue
            top = max(c["v"])
            arr.append({"v": [c["v"].get(i) for i in range(1, top + 1)], "p": sorted(c["p"])})
        kjv[book] = arr
    (out / "kjv.json").write_text(json.dumps(kjv, ensure_ascii=False, separators=(",", ":"), sort_keys=True), encoding="utf-8")

    # ---- strings ---------------------------------------------------------------------------
    strings, index = [], {}

    def s_idx(text):
        if text not in index:
            index[text] = len(strings)
            strings.append(text)
        return index[text]

    # ---- days ----------------------------------------------------------------------------------
    root = Path(args.sanitised) / "slavic"
    digest = 0xcbf29ce484222325
    fields_digest = 0xcbf29ce484222325
    files, first, last, per_file = [], None, None, {}
    composite_runs = {}

    for cal, app_name in RECKONING.items():
        for path in sorted((root / cal).glob("*.json")):
            iso = path.stem
            year = int(iso[:4])
            d = json.loads(path.read_text(encoding="utf-8"))
            titles = d.get("titles") or []
            fx = d.get("fast_exception_desc")
            # Everything the app shows except reading text (which has its own digest), taken from the
            # audited day itself and not from the records below, so the records' encoding and the
            # app's decoding are both held to the source.
            fields = "\x1e".join([
                f"{d['year']:04d}-{d['month']:02d}-{d['day']:02d}",
                "-" if d.get("tone") is None else str(d["tone"]),
                titles[0] if titles else "-",
                d.get("summary_title") or "",
                "|".join(d.get("saints") or []), "|".join(d.get("feasts") or []),
                str(d["fast_level"]), d["fast_level_desc"], str(d["fast_exception"]), fx if fx else "-",
                "|".join(d.get("fast_abstentions") or []),
                str(d["feast_level"]), d["feast_level_description"], str(d["pascha_distance"]),
            ] + [f"{r['source']}\x1d{r['display']}\x1d{r['short_display']}" for r in d.get("readings") or []])
            fields_digest = fnv1a64(fields.encode("utf-8"), fields_digest)
            fields_digest = fnv1a64(b"\x1f", fields_digest)
            readings = []
            for r in d.get("readings") or []:
                verses = [(p["book"], p["chapter"], p["verse"]) for p in r["passage"]]
                runs = runs_of(verses)
                # The text this reading will resolve to must be exactly what the app builds.
                joined = join([(b, c, v, p["content"], p["paragraph_start"])
                               for (b, c, v), p in zip(verses, r["passage"])])
                for (b, c, v), p in zip(verses, r["passage"]):
                    assert text_of[(b, c, v)] == p["content"], (iso, r["display"], b, c, v)
                    assert para_of[(b, c, v)] == p["paragraph_start"], (iso, r["display"], b, c, v)
                resolved = join([(b, c, v, text_of[(b, c, v)], para_of[(b, c, v)]) for b, c, v in verses])
                assert resolved == joined
                digest = fnv1a64(resolved.encode("utf-8"), digest)
                digest = fnv1a64(b"\x1f", digest)
                readings.append({"s": s_idx(r["source"]), "d": s_idx(r["display"]),
                                 "h": s_idx(r["short_display"]), "r": runs})
                if r["display"].startswith("Composite"):
                    composite_runs[r["display"]] = runs
            rec = {
                "o": [d["year"], d["month"], d["day"]],
                "t": d.get("tone"),
                "ti": s_idx(titles[0]) if titles else None,
                "su": s_idx(d.get("summary_title") or ""),
                "sa": [s_idx(x) for x in d.get("saints") or []],
                "fe": [s_idx(x) for x in d.get("feasts") or []],
                "fl": d["fast_level"],
                "fd": s_idx(d["fast_level_desc"]),
                "fx": d["fast_exception"],
                "fxd": s_idx(fx) if fx else None,
                "ab": [s_idx(x) for x in d.get("fast_abstentions") or []],
                "el": d["feast_level"],
                "ed": s_idx(d["feast_level_description"]),
                "pd": d["pascha_distance"],
                "r": readings,
            }
            per_file.setdefault((app_name, year), []).append((iso, rec))
            first = iso if first is None or iso < first else first
            last = iso if last is None or iso > last else last

    for (app_name, year), days in sorted(per_file.items()):
        days.sort(key=lambda x: x[0])
        # Index in the file is the day of the year; a gap would silently shift every later day.
        for n, (iso, _) in enumerate(days):
            expected = (__import__("datetime").date(year, 1, 1) + __import__("datetime").timedelta(days=n)).isoformat()
            assert iso == expected, f"{app_name} {year}: day {n} is {iso}, expected {expected}"
        name = f"{app_name}-{year}.json"
        (out / name).write_text(json.dumps({"y": year, "days": [r for _, r in days]},
                                           ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        files.append(name)

    (out / "strings.json").write_text(json.dumps(strings, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    # The composites the network path may meet beyond the bundle: citation -> runs, resolved locally.
    expected = json.loads(Path(args.composites).read_text(encoding="utf-8"))
    assert set(composite_runs) == set(expected), "composites in the days differ from composites.json"
    (out / "composites.json").write_text(json.dumps(composite_runs, ensure_ascii=False, separators=(",", ":"), sort_keys=True),
                                         encoding="utf-8")

    manifest = {
        "schema": 1,
        "tradition": "slavic",
        "first": first, "last": last,
        "generatedAt": args.generated_at,
        "orthocalCommit": args.commit,
        "scripture": {"translation": "kjv", "text": "King James Version with Apocrypha, public domain, eBible.org"},
        "textDigest": format(digest, "016x"),
        "fieldsDigest": format(fields_digest, "016x"),
        "files": sorted(files),
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, sort_keys=True), encoding="utf-8")
    total = sum(p.stat().st_size for p in out.glob("*.json"))
    print(f"wrote {len(files)} calendar files, {len(strings)} strings, {len(rows)} verses, "
          f"{len(composite_runs)} composites to {out} ({total/1e6:.1f} MB); digest {manifest['textDigest']}, fields digest {manifest['fieldsDigest']}", file=sys.stderr)


if __name__ == "__main__":
    main()
