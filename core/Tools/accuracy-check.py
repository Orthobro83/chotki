#!/usr/bin/env python3
"""Spot-check the bundled calendar against orthocal.info, politely.

Run before a release, and whenever the bundle is regenerated. It is a courtesy-bounded
check, not a crawl: a few dozen requests, two seconds apart, a User-Agent that says who is
asking, and it stops at the first 429 or server error.

  accuracy-check.py --dry-run                   # show which dates would be asked about
  accuracy-check.py                             # ask the live service (default: 24 dates x 2 calendars)
  accuracy-check.py --from-dir DIR              # compare against local day files instead (no network)

Compared, for each date and each calendar: the observed date, tone, title, summary title,
saints, feasts, fast and feast levels and their descriptions, abstentions, Pascha distance and
every reading's source and references. Reading *text* is compared too, except for Orthocal's
Composite readings, whose text the app deliberately never uses.

Exit status: 0 no differences, 1 differences, 2 could not complete (network, bad arguments).
A difference is either a bug in the bundle or something upstream changed since it was made;
the report says which fields, and a commemoration that upstream has since *added* is
reported separately because that is the common, harmless case.

Stdlib only.
"""
import argparse, datetime, json, random, sys, time, urllib.error, urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_BUNDLE = HERE.parent / "Sources/ChotkiCore/Resources/calendar"
USER_AGENT = "Chotki accuracy check (+https://github.com/Orthobro83/chotki)"
CAL_TO_APP = {"julian": "julian", "gregorian": "revisedJulian"}


# ---- the paragraph rule: identical to calendar-bundle.py and ScriptureText.swift -------------
def contiguous(prev, cur):
    if prev is None:
        return True
    if prev[0] != cur[0]:
        return False
    if prev[1] == cur[1]:
        return cur[2] == prev[2] + 1
    return cur[1] == prev[1] + 1 and cur[2] == 1


def join(verses):
    out, prev = [], None
    for book, ch, v, text, para in verses:
        key = (book, ch, v)
        if out:
            out.append("\n\n" if (para or not contiguous(prev, key)) else " ")
        out.append(text)
        prev = key
    return "".join(out)


# ---- the bundle -----------------------------------------------------------------------------------
class Bundle:
    def __init__(self, directory):
        self.dir = Path(directory)
        self.manifest = json.loads((self.dir / "manifest.json").read_text(encoding="utf-8"))
        self.strings = json.loads((self.dir / "strings.json").read_text(encoding="utf-8"))
        self.kjv = json.loads((self.dir / "kjv.json").read_text(encoding="utf-8"))
        self.first = datetime.date.fromisoformat(self.manifest["first"])
        self.last = datetime.date.fromisoformat(self.manifest["last"])
        self._years = {}

    def _verse(self, book, ch, v):
        chapter = self.kjv[book][ch - 1]
        text = chapter["v"][v - 1]
        return (book, ch, v, text, v in chapter["p"])

    def view(self, date, cal):
        app = CAL_TO_APP[cal]
        key = (app, date.year)
        if key not in self._years:
            path = self.dir / f"{app}-{date.year}.json"
            self._years[key] = json.loads(path.read_text(encoding="utf-8"))["days"]
        r = self._years[key][(date - datetime.date(date.year, 1, 1)).days]
        s = self.strings
        readings = []
        for e in r["r"]:
            verses = [self._verse(b, c, n) for b, c, v1, v2 in e["r"] for n in range(v1, v2 + 1)]
            readings.append((s[e["s"]], s[e["d"]], s[e["h"]], join(verses)))
        return {
            "observed": tuple(r["o"]), "tone": r["t"],
            "title": s[r["ti"]] if r["ti"] is not None else None,
            "summary": s[r["su"]], "saints": [s[i] for i in r["sa"]], "feasts": [s[i] for i in r["fe"]],
            "fast_level": r["fl"], "fast_desc": s[r["fd"]], "fast_exception": r["fx"],
            "fast_exception_desc": s[r["fxd"]] if r["fxd"] is not None else None,
            "abstentions": [s[i] for i in r["ab"]], "feast_level": r["el"], "feast_desc": s[r["ed"]],
            "pascha": r["pd"], "readings": readings,
        }

    def dates(self):
        d = self.first
        while d <= self.last:
            yield d
            d += datetime.timedelta(days=1)


def api_view(raw):
    """The same view, from an Orthocal day response."""
    titles = raw.get("titles") or []
    fx = raw.get("fast_exception_desc")
    readings = []
    for r in raw.get("readings") or []:
        passage = r.get("passage") or []
        keyed = all(isinstance(p.get("chapter"), int) and isinstance(p.get("verse"), int) and p.get("book") for p in passage)
        text = join([(p["book"], p["chapter"], p["verse"], p["content"], bool(p.get("paragraph_start")))
                     for p in passage]) if keyed else None
        readings.append((r["source"], r["display"], r["short_display"], text))
    return {
        "observed": (raw["year"], raw["month"], raw["day"]), "tone": raw.get("tone"),
        "title": titles[0] if titles else None, "summary": raw.get("summary_title") or "",
        "saints": raw.get("saints") or [], "feasts": raw.get("feasts") or [],
        "fast_level": raw["fast_level"], "fast_desc": raw["fast_level_desc"],
        "fast_exception": raw["fast_exception"], "fast_exception_desc": fx if fx else None,
        "abstentions": raw.get("fast_abstentions") or [], "feast_level": raw["feast_level"],
        "feast_desc": raw["feast_level_description"], "pascha": raw["pascha_distance"], "readings": readings,
    }


def compare(shipped, other):
    """Returns (differences, harmless): lists of strings."""
    diffs, harmless = [], []
    for k in shipped:
        if k == "readings":
            if len(shipped[k]) != len(other[k]):
                diffs.append(f"reading count {len(shipped[k])} vs {len(other[k])}")
                continue
            for (a, b) in zip(shipped[k], other[k]):
                if a[:3] != b[:3]:
                    diffs.append(f"reading references {a[:3]} vs {b[:3]}")
                elif not a[1].startswith("Composite") and a[3] != b[3]:
                    diffs.append(f"reading text of {a[1]}")
        elif shipped[k] != other[k]:
            if k in ("saints", "summary") and set(shipped["saints"]) <= set(other["saints"]):
                harmless.append(f"{k}: upstream has added commemorations")
            else:
                diffs.append(f"{k}: bundle={shipped[k]!r} other={other[k]!r}")
    return diffs, harmless


# ---- which dates --------------------------------------------------------------------------------
def choose_dates(bundle, count, seed):
    """A spread, not a priority list: groups are interleaved so that a small count still
    touches the edges, the leap day, Holy Week, the fasts, the great feasts and chance."""
    groups = {"edges": [], "holy week": [], "fasts": [], "feasts": [], "chance": []}

    def add(group, d, why):
        if bundle.first <= d <= bundle.last:
            groups[group].append((d, why))

    add("edges", bundle.first, "first day covered"); add("edges", bundle.last, "last day covered")
    add("edges", datetime.date(2028, 2, 29), "leap day")
    paschas = [d for d in bundle.dates() if bundle.view(d, "julian")["pascha"] == 0]
    for p in paschas[:3]:
        for off, why in ((0, "Pascha"), (-2, "Holy Friday"), (-3, "Holy Thursday"), (3, "Bright Wednesday"), (50, "Pentecost")):
            add("holy week", p + datetime.timedelta(days=off), f"{why} {p.year}")
    # first and last day of each fast, in the second year of the window
    year = bundle.first.year + 1
    prev = 0
    for d in (x for x in bundle.dates() if x.year == year):
        level = bundle.view(d, "julian")["fast_level"]
        if level >= 2 and level != prev:
            add("fasts", d, f"fast {level} begins {year}")
        if prev >= 2 and level != prev:
            add("fasts", d - datetime.timedelta(days=1), f"fast {prev} ends {year}")
        prev = level
    for y in (bundle.first.year + 1, bundle.first.year + 4):
        for m, dd, why in ((12, 25, "Nativity, civil"), (1, 6, "Theophany eve, civil"), (1, 7, "Nativity, Old Calendar"), (8, 15, "Dormition, civil")):
            add("feasts", datetime.date(y if m != 1 else y + 1, m, dd), f"{why} {y}")
    rng = random.Random(seed)
    quarters = [(y, q) for y in range(bundle.first.year, bundle.last.year + 1) for q in range(4)]
    rng.shuffle(quarters)
    for y, q in quarters:
        add("chance", datetime.date(y, 3 * q + 1, 1) + datetime.timedelta(days=rng.randrange(89)), f"random {y} Q{q + 1}")

    chosen, seen = [], set()
    while len(chosen) < count and any(groups.values()):
        for name in groups:
            while groups[name]:
                d, why = groups[name].pop(0)
                if d not in seen:
                    seen.add(d); chosen.append((d, why)); break
            if len(chosen) >= count:
                break
    return chosen


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bundle", default=str(DEFAULT_BUNDLE))
    ap.add_argument("--dates", type=int, default=24, help="how many dates (each asked for under both calendars)")
    ap.add_argument("--max-requests", type=int, default=60)
    ap.add_argument("--delay", type=float, default=2.0, help="seconds between requests")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--from-dir", help="compare with <dir>/slavic/<cal>/YYYY-MM-DD.json instead of the network")
    ap.add_argument("--host", default="https://orthocal.info")
    args = ap.parse_args()

    bundle = Bundle(args.bundle)
    dates = choose_dates(bundle, args.dates, args.seed)
    requests_needed = len(dates) * 2
    print(f"bundle {bundle.first} .. {bundle.last}, Orthocal commit {bundle.manifest['orthocalCommit'][:10]}; "
          f"{len(dates)} dates x 2 calendars", file=sys.stderr)
    if args.dry_run:
        for d, why in dates:
            print(f"  {d}  {why}")
        print(f"would make {requests_needed} requests, {args.delay}s apart "
              f"(~{requests_needed * args.delay / 60:.1f} min)" + (" - none: --from-dir" if args.from_dir else ""), file=sys.stderr)
        return 0
    if not args.from_dir and requests_needed > args.max_requests:
        print(f"{requests_needed} requests exceeds --max-requests {args.max_requests}; lower --dates", file=sys.stderr)
        return 2

    checked = failed = 0
    harmless_total = 0
    made = 0
    for d, why in dates:
        for cal in ("julian", "gregorian"):
            if args.from_dir:
                raw = json.loads((Path(args.from_dir) / "slavic" / cal / f"{d.isoformat()}.json").read_text(encoding="utf-8"))
            else:
                if made:
                    time.sleep(args.delay)
                url = f"{args.host}/api/{cal}/{d.year}/{d.month}/{d.day}/"
                try:
                    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": USER_AGENT}), timeout=30) as resp:
                        raw = json.loads(resp.read())
                except urllib.error.HTTPError as e:
                    print(f"stopped: HTTP {e.code} for {url}", file=sys.stderr)
                    return 2
                except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as e:
                    print(f"stopped: {e} for {url}", file=sys.stderr)
                    return 2
                made += 1
            diffs, harmless = compare(bundle.view(d, cal), api_view(raw))
            checked += 1
            harmless_total += len(harmless)
            if diffs:
                failed += 1
                print(f"DIFF {cal:9s} {d}  ({why})")
                for line in diffs:
                    print(f"      {line[:300]}")
            elif harmless:
                print(f"note {cal:9s} {d}  ({why}): {'; '.join(harmless)}")
    print(f"{checked} compared, {failed} with differences, {harmless_total} harmless notes"
          + (f", {made} requests made" if not args.from_dir else ""), file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
