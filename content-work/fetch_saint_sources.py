#!/usr/bin/env python3
"""Cache St. Dimitry of Rostov's public-domain Russian daily source pages.

This is editorial source material, never an app resource. Re-run safely: already
downloaded days are skipped. Keep requests gentle and stop on persistent errors.
"""

import argparse
import datetime as dt
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

MONTHS = (
    "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
    "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь",
)
ROOT = Path(__file__).resolve().parent / "source-cache"
USER_AGENT = "Chotki/0.2 (https://github.com/rjmac83/chotki; public-domain saint-life translation research)"


def days():
    day = dt.date(2024, 1, 1)  # leap year: includes February 29
    while day.year == 2024:
        yield day
        day += dt.timedelta(days=1)


def source(day):
    title = (
        "Жития святых по изложению свт. Димитрия Ростовского/"
        f"{MONTHS[day.month - 1]}/{day.day}"
    )
    page_url = "https://ru.wikisource.org/wiki/" + urllib.parse.quote(title.replace(" ", "_"))
    api_url = "https://ru.wikisource.org/w/api.php?" + urllib.parse.urlencode(
        {"action": "parse", "page": title, "prop": "text", "format": "json"}
    )
    return page_url, api_url


def fetch(day):
    page_url, api_url = source(day)
    request = urllib.request.Request(api_url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        parsed = json.load(response)
    if "error" in parsed:
        raise ValueError(parsed["error"])
    html = parsed["parse"]["text"]["*"]
    if len(html) < 1000:
        raise ValueError("unexpectedly short page")
    return {"month": day.month, "day": day.day, "sourceURL": page_url, "html": html}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=366, help="maximum uncached days to request")
    parser.add_argument("--delay", type=float, default=1.5, help="seconds between requests")
    parser.add_argument("--date", action="append", help="fetch only this MM-DD date; may repeat")
    args = parser.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    fetched = 0
    selected_days = list(days())
    if args.date:
        selected_days = [day for day in selected_days if day.strftime("%m-%d") in args.date]
        if len(selected_days) != len(set(args.date)):
            parser.error("one or more --date values are invalid or duplicated")
    for day in selected_days:
        path = ROOT / f"{day.month:02d}-{day.day:02d}.json"
        if path.exists():
            continue
        if fetched >= args.limit:
            break
        for retry in range(4):
            try:
                payload = fetch(day)
                path.write_text(json.dumps(payload, ensure_ascii=False) + "\n")
                print(f"cached {day.month:02d}-{day.day:02d}", flush=True)
                fetched += 1
                break
            except urllib.error.HTTPError as exc:
                if exc.code != 429 or retry == 3:
                    print(f"stopped at {day.month:02d}-{day.day:02d}: HTTP {exc.code}", flush=True)
                    return 1
                time.sleep(30 * (retry + 1))
            except (urllib.error.URLError, TimeoutError, ValueError) as exc:
                print(f"stopped at {day.month:02d}-{day.day:02d}: {exc}", flush=True)
                return 1
        time.sleep(args.delay)
    print(f"cached total: {len(list(ROOT.glob('??-??.json')))}/366", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
