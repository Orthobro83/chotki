#!/usr/bin/env python3
"""Print readable Russian headings and paragraphs from a cached daily source."""

import argparse
import json
import re
from html.parser import HTMLParser
from pathlib import Path

CACHE = Path(__file__).resolve().parent / "source-cache"


class Prose(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.capture = None
        self.capture_depth = 0
        self.suppress = 0
        self.parts = []
        self.lines = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.depth += 1
        if tag == "span" and re.fullmatch(r"m\d+", attrs.get("id", "")):
            self.lines.append(("marker", attrs["id"]))
        if self.capture is None and (
            tag == "p" or (tag == "div" and attrs.get("role") == "heading")
        ):
            self.capture = "heading" if tag == "div" else "paragraph"
            self.capture_depth = self.depth
            self.parts = []
        if tag in ("sup", "style", "script"):
            self.suppress += 1
        if self.capture and tag == "img":
            alt = attrs.get("alt", "")
            if len(alt) == 1 and "А" <= alt.upper() <= "Я":
                self.parts.append(alt)
        if self.capture and tag == "br":
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in ("sup", "style", "script") and self.suppress:
            self.suppress -= 1
        if self.capture and self.depth == self.capture_depth:
            value = re.sub(r"[ \t\xa0]+", " ", "".join(self.parts)).strip()
            if value:
                self.lines.append((self.capture, value))
            self.capture = None
        self.depth -= 1

    def handle_data(self, data):
        if self.capture and not self.suppress:
            self.parts.append(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("date", help="church date as MM-DD")
    parser.add_argument("--outline", action="store_true", help="list sections and their lengths")
    parser.add_argument("--section", type=int, help="print one numbered section only")
    args = parser.parse_args()
    if not re.fullmatch(r"\d\d-\d\d", args.date):
        parser.error("date must be MM-DD")
    payload = json.loads((CACHE / f"{args.date}.json").read_text())
    prose = Prose()
    prose.feed(payload["html"])
    started = False
    sections = {}
    current = 0
    for kind, value in prose.lines:
        if kind == "heading" and value.startswith("День "):
            started = True
        if not started:
            continue
        if kind == "marker":
            current = int(value[1:])
            sections.setdefault(current, [])
        elif current:
            sections[current].append((kind, value))
    if args.outline:
        for number, items in sections.items():
            headings = " / ".join(value for kind, value in items if kind == "heading")
            size = sum(len(value) for kind, value in items if kind == "paragraph")
            print(f"{number}: {size:,} Russian characters — {headings[:130]}")
        return
    print(payload["sourceURL"])
    print()
    chosen = sections.items() if args.section is None else [(args.section, sections[args.section])]
    for number, items in chosen:
        print(f"=== Section {number} ===\n")
        for kind, value in items:
            print(f"## {value}" if kind == "heading" else value)
            print()


if __name__ == "__main__":
    main()
