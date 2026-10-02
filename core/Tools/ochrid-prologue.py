#!/usr/bin/env python3
"""Bundles the Prologue from Ochrid for every day of the year.

The text is the English reading published at
https://app.ochrid.com/prologue?day=MM-DD under CC BY-SA 4.0. Nothing in it
is rewritten. Markdown emphasis is stored as italic or bold so the asterisks,
which are markup and not words, are not shown.

Each page is one civil date and carries two readings:

- the Old Calendar reading, titled "December 19 / January 1"
- the New Calendar reading for that same civil date

Both name the church day they belong to. The app looks a life up by that
church day (the observed date). Old Calendar and New Calendar therefore show
different lives on the same wall-calendar day, because those settings observe
different church days. The second date is kept so the distinction is in the
data, not only in the lookup.

    python3 core/Tools/ochrid-prologue.py

Cached pages stay in /tmp/ochrid-cache. The two JSON copies are written together.
"""

from __future__ import annotations

import datetime as dt
import json
import re
import ssl
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SWIFT_JSON = ROOT / "core/Sources/ChotkiCore/Resources/saint-lives.json"
ANDROID_JSON = ROOT / "android/core/src/main/resources/content/saint-lives.json"
CACHE = Path("/tmp/ochrid-cache")
ORIGIN = "https://app.ochrid.com/prologue?day="
LICENSE_URL = "https://creativecommons.org/licenses/by-sa/4.0/"
SOURCE = "St. Nikolai Velimirovic, Prologue from Ochrid"
LICENSE_NOTE = "Prologue translation available under CC BY-SA 4.0. The text is unchanged."
UA = "Chotki/ochrid-prologue (CC BY-SA 4.0; text stored unchanged)"

MONTHS = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)

# React flight chunks announce a UTF-8 byte length, not a character length.
CHUNK = re.compile(br"([0-9a-f]+):T([0-9a-f]+),")
PROPS = re.compile(
    r'"gregorianDate":"(\d{2}-\d{2})","julianDate":"(\d{2}-\d{2})"'
    r',"julianEnglish":"\$([0-9a-f]+)","julianSerbian":"\$([0-9a-f]+)"'
    r',"gregorianEnglish":"\$([0-9a-f]+)"'
)
TITLE = re.compile(r"<title>(.*?)</title>", re.S)


def civil_days() -> list[str]:
    """Every month and day the site can be asked for, including February 29."""
    days = []
    cursor = dt.date(2024, 1, 1)
    while cursor.year == 2024:
        days.append(f"{cursor.month:02d}-{cursor.day:02d}")
        cursor += dt.timedelta(days=1)
    return days


def fetch(key: str) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    dest = CACHE / f"{key}.html"
    if dest.exists() and dest.stat().st_size > 1000:
        return
    url = ORIGIN + key
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    last = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=40, context=ssl.create_default_context()) as response:
                dest.write_bytes(response.read())
            return
        except Exception as error:  # noqa: BLE001 — retry any transport failure
            last = error
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"{key}: {last}")


def decode_pushes(html: str) -> str:
    token = 'self.__next_f.push([1,"'
    parts = []
    cursor = 0
    while True:
        start = html.find(token, cursor)
        if start < 0:
            break
        start += len(token)
        chars = []
        index = start
        while index < len(html):
            char = html[index]
            if char == "\\":
                nxt = html[index + 1]
                if nxt == "u":
                    chars.append(chr(int(html[index + 2:index + 6], 16)))
                    index += 6
                    continue
                chars.append({"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, nxt))
                index += 2
                continue
            if char == '"':
                break
            chars.append(char)
            index += 1
        parts.append("".join(chars))
        cursor = index + 1
    return "".join(parts)


def flight_chunks(stream: str) -> dict[str, str]:
    data = stream.encode("utf-8")
    chunks = {}
    cursor = 0
    while True:
        match = CHUNK.search(data, cursor)
        if not match:
            break
        ident = match.group(1).decode()
        length = int(match.group(2), 16)
        start = match.end()
        body = data[start:start + length]
        if len(body) != length:
            raise RuntimeError(f"chunk {ident} ended early")
        chunks[ident] = body.decode("utf-8")
        cursor = start + length
        # The next record follows immediately. A miss here means the length was wrong.
        if cursor < len(data) and not re.match(br"[0-9a-f]+:", data[cursor:]):
            raise RuntimeError(f"chunk {ident} did not end on a record boundary")
    return chunks


def unescape(text: str) -> str:
    return (
        text.replace("&#x27;", "'")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", '"')
    )


def parse_inlines(text: str) -> list[dict]:
    """Turns markdown emphasis into spans. The asterisks are not part of the text."""
    spans: list[dict] = []
    buf: list[str] = []
    italic = False
    bold = False

    def flush() -> None:
        if not buf:
            return
        span = {"text": "".join(buf)}
        if italic:
            span["italic"] = True
        if bold:
            span["bold"] = True
        spans.append(span)
        buf.clear()

    index = 0
    while index < len(text):
        if text.startswith("**", index):
            flush()
            bold = not bold
            index += 2
            continue
        if text[index] == "*":
            flush()
            italic = not italic
            index += 1
            continue
        buf.append(text[index])
        index += 1
    flush()
    if italic or bold:
        raise RuntimeError(f"unbalanced emphasis: {text[:80]!r}")
    return spans


def blocks_of(markdown: str) -> list[dict]:
    """One section of the prologue, split where the page splits it."""
    body = markdown.strip("\n")
    if body.startswith("## "):
        body = body.split("\n", 1)[1]
    blocks = []

    def consume(piece: str) -> None:
        if piece.startswith("### "):
            first, _, rest = piece.partition("\n")
            heading = first[4:].strip()
            if "*" in heading or "\n" in heading:
                raise RuntimeError(f"emphasis in a heading: {heading}")
            blocks.append({"kind": "heading", "text": heading})
            if rest.strip():
                consume(rest.strip("\n"))
            return
        lines = [line.rstrip() for line in piece.split("\n")]
        if len(lines) > 1:
            blocks.append({"kind": "lines", "rows": [parse_inlines(line) for line in lines if line.strip()]})
        else:
            blocks.append({"kind": "prose", "spans": parse_inlines(lines[0].rstrip())})

    for raw in re.split(r"\n\s*\n", body.strip()):
        piece = raw.strip("\n")
        if piece.strip():
            consume(piece)
    return blocks


def split_reading(markdown: str) -> tuple[str | None, list[dict]]:
    """A few days begin with a plain title line, `# 22. April`, before the sections."""
    text = markdown.strip()
    preface = None
    if text.startswith("# ") and not text.startswith("## "):
        first, _, text = text.partition("\n")
        preface = first[2:].strip()
        if "*" in preface:
            raise RuntimeError(f"emphasis in a preface: {preface}")
        text = text.lstrip("\n")
    if not text.startswith("## "):
        raise RuntimeError(f"reading does not start with a section heading: {text[:80]!r}")
    return preface, sections_of(text)


def sections_of(markdown: str) -> list[dict]:
    if not markdown.startswith("## "):
        raise RuntimeError(f"reading does not start with a section heading: {markdown[:80]!r}")
    parts = re.split(r"\n(?=## )", markdown.strip())
    sections = []
    for part in parts:
        heading = part.split("\n", 1)[0][3:].strip()
        if "*" in heading:
            raise RuntimeError(f"emphasis in a section heading: {heading}")
        sections.append({"heading": heading, "blocks": blocks_of(part)})
    if not sections:
        raise RuntimeError("reading has no sections")
    return sections


def words_only(markdown: str) -> str:
    """The reading with markup removed and line breaks collapsed.

    Hymn lines end in two spaces so Markdown will break them. Those spaces
    are not printed. Spaces between words are kept.
    """
    text = re.sub(r"^#{1,6} ", "", markdown, flags=re.M)
    text = text.replace("**", "").replace("*", "")
    text = re.sub(r"[ \t]+$", "", text, flags=re.M)
    return text.replace("\n", "")


def visible(sections: list[dict]) -> str:
    words = []
    for section in sections:
        words.append(section["heading"])
        for block in section["blocks"]:
            if block["kind"] == "heading":
                words.append(block["text"])
            elif block["kind"] == "prose":
                words.append("".join(span["text"] for span in block["spans"]))
            else:
                for row in block["rows"]:
                    words.append("".join(span["text"] for span in row))
    return "".join(words)


def parse_page(key: str) -> dict | None:
    html = (CACHE / f"{key}.html").read_text(encoding="utf-8")
    stream = decode_pushes(html)
    props = PROPS.search(stream)
    # day=02-29 answers with a title and then "This reading could not be found."
    # The Prologue, as published here, has no February 29 entry.
    if not props:
        if "This reading could not be found." in html:
            return None
        raise RuntimeError(f"{key}: calendar payload not found")
    chunks = flight_chunks(stream)
    title = unescape(TITLE.search(html).group(1))
    # The document title is "<old date> / <new date> - <saints> | Prologue..."
    date_and_saints = title.split(" | ", 1)[0]
    published_line, _, _saints = date_and_saints.partition(" - ")
    gregorian_key, julian_key, julian_id, _serbian, gregorian_id = props.groups()
    if gregorian_key != key:
        raise RuntimeError(f"{key}: page says gregorian {gregorian_key}")
    return {
        "julian": parse_md_date(julian_key),
        "gregorian": parse_md_date(gregorian_key),
        "julian_text": chunks[julian_id],
        "gregorian_text": chunks[gregorian_id],
        "published_line": published_line.strip(),
    }


def parse_md_date(value: str) -> tuple[int, int]:
    month, day = value.split("-")
    return int(month), int(day)


def plain_from_markdown(markdown: str) -> str:
    """The words, with markup removed, for the equality check between calendars."""
    return markdown.replace("**", "").replace("*", "")


def church_days() -> set[tuple[int, int]]:
    """Every month and day except February 29.

    The published prologue has no February 29 reading: asking for that day
    returns "This reading could not be found." A leap day's Old Calendar
    observance is February 16, which does have a reading.
    """
    days = set()
    cursor = dt.date(2023, 1, 1)
    while cursor.year == 2023:
        days.add((cursor.month, cursor.day))
        cursor += dt.timedelta(days=1)
    return days


def build() -> list[dict]:
    keys = civil_days()
    print(f"fetching {len(keys)} days", flush=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(fetch, key): key for key in keys}
        done = 0
        for future in as_completed(futures):
            future.result()
            done += 1
            if done % 40 == 0 or done == len(keys):
                print(f"  {done}/{len(keys)}", flush=True)

    by_church: dict[tuple[int, int], dict] = {}
    gregorian_copy: dict[tuple[int, int], str] = {}
    missing = []
    for key in keys:
        page = parse_page(key)
        if page is None:
            missing.append(key)
            continue
        julian = page["julian"]
        gregorian = page["gregorian"]
        julian_name = f"{MONTHS[julian[0] - 1]} {julian[1]}"
        gregorian_name = f"{MONTHS[gregorian[0] - 1]} {gregorian[1]}"
        if page["published_line"] != f"{julian_name} / {gregorian_name}":
            raise RuntimeError(
                f"{key}: title {page['published_line']!r} does not match {julian_name} / {gregorian_name}"
            )
        if julian in by_church:
            raise RuntimeError(f"duplicate church day {julian} on {key}")
        by_church[julian] = page
        gregorian_copy[gregorian] = page["gregorian_text"]

    if missing != ["02-29"]:
        raise RuntimeError(f"unexpected pages without a reading: {missing}")
    if set(by_church) != church_days():
        missing_days = sorted(church_days() - set(by_church))
        extra = sorted(set(by_church) - church_days())
        raise RuntimeError(f"church days missing {missing_days[:8]} extra {extra[:8]}")
    if set(gregorian_copy) != set(by_church):
        raise RuntimeError("old-calendar and new-calendar days do not cover the same church dates")

    entries = []
    headings = {}
    for (month, day), page in sorted(by_church.items()):
        other = plain_from_markdown(gregorian_copy[(month, day)])
        own = plain_from_markdown(page["julian_text"])
        if own != other:
            raise RuntimeError(
                f"{month:02d}-{day:02d}: old-calendar text and new-calendar text differ"
            )
        preface, sections = split_reading(page["julian_text"])
        shown = (preface or "") + visible(sections)
        if shown != words_only(page["julian_text"]):
            raise RuntimeError(f"{month:02d}-{day:02d}: visible text does not match the source")
        if "\u00ad" in shown or "&#" in shown:
            raise RuntimeError(f"{month:02d}-{day:02d}: leftover markup or a soft hyphen")
        signature = tuple(section["heading"] for section in sections)
        headings[signature] = headings.get(signature, 0) + 1
        civil_month, civil_day = page["gregorian"]
        entries.append({
            "month": month,
            "day": day,
            "gregorianMonth": civil_month,
            "gregorianDay": civil_day,
            "dates": page["published_line"],
            **({"preface": preface} if preface else {}),
            "sections": sections,
            "source": SOURCE,
            "sourceURL": f"{ORIGIN}{civil_month:02d}-{civil_day:02d}",
            "license": "CC BY-SA 4.0",
            "licenseURL": LICENSE_URL,
            "licenseNote": LICENSE_NOTE,
        })
    print("section headings:")
    for signature, count in sorted(headings.items(), key=lambda item: -item[1]):
        print(f"  {count}: {signature}")
    if len(entries) != 365:
        raise RuntimeError(f"expected 365 church days, got {len(entries)}")
    return entries


def main() -> None:
    entries = build()
    payload = json.dumps(entries, ensure_ascii=False, indent=2) + "\n"
    for path in (SWIFT_JSON, ANDROID_JSON):
        path.write_text(payload, encoding="utf-8")
        print(f"wrote {path} ({len(payload)} bytes)")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # noqa: BLE001
        print(f"FAILED: {error}", file=sys.stderr)
        sys.exit(1)
