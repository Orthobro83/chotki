"""Replace approved Mac review copies with Commons standard-size thumbnails.

Each source is rechecked for CC0/public-domain status. Downloads are serial
and paced to respect Commons rate limits; incomplete transfers remain in
temporary files and never replace a valid bundled image.
"""

import json
import time
import urllib.parse
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "macos/Sources/Chotki/Resources/sayings"
records_path = DEST / "approved-sources.json"
records = json.loads(records_path.read_text())
agent = "ChotkiImageLibrary/1.0 (personal Orthodox daily-image library; source attribution retained)"


class RateLimited(Exception):
    pass


def fetch(url):
    for attempt in range(5):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": agent})
            with urllib.request.urlopen(request, timeout=90) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code == 429:
                raise RateLimited("Wikimedia Commons is rate-limiting transfers; resume later") from error
            if attempt == 4:
                raise
            time.sleep([4, 10, 20, 40][attempt])
        except Exception:
            if attempt == 4:
                raise
            time.sleep([4, 10, 20, 40][attempt])


def title(record):
    return "File:" + urllib.parse.unquote(record["source"].split("/wiki/File:", 1)[1]).replace("_", " ")


def batch_info(batch):
    titles = [title(record) for record in batch]
    params = urllib.parse.urlencode({
        "action": "query", "titles": "|".join(titles), "prop": "imageinfo",
        "iiprop": "url|extmetadata|size|mime", "iiurlwidth": "1600", "format": "json",
    })
    data = json.loads(fetch("https://commons.wikimedia.org/w/api.php?" + params))
    normalized = {item["from"]: item["to"] for item in data["query"].get("normalized", [])}
    redirects = {item["from"]: item["to"] for item in data["query"].get("redirects", [])}
    pages = {page["title"]: page for page in data["query"]["pages"].values()}
    output = []
    for record, name in zip(batch, titles):
        canonical = normalized.get(name, name)
        info = pages[redirects.get(canonical, canonical)]["imageinfo"][0]
        license_name = info["extmetadata"].get("LicenseShortName", {}).get("value", "")
        if license_name not in ("CC0", "Public domain"):
            raise ValueError(f"License changed for {record['id']}: {license_name}")
        if min(info["width"], info["height"]) < 1200:
            raise ValueError(f"Resolution changed for {record['id']}")
        output.append((record, info))
    return output


if __name__ == "__main__":
    checked = []
    for start in range(0, len(records), 20):
        checked.extend(batch_info(records[start:start + 20]))
        print(f"Rights checked {len(checked)}/{len(records)}", flush=True)
        time.sleep(1)
    for offset, (record, info) in enumerate(checked, 1):
        target = DEST / record["file"]
        if record.get("bundledCopy") == "Commons standard thumbnail (up to 1920 px)":
            continue
        url = info.get("thumburl", info["url"])
        try:
            payload = fetch(url)
        except RateLimited as error:
            print(f"Paused after {sum(item.get('bundledCopy', '').startswith('Commons') for item in records)} upgrades: {error}", flush=True)
            break
        if len(payload) < 20_000:
            raise ValueError(f"Unexpectedly small image for {record['id']}")
        temporary = target.with_suffix(target.suffix + ".partial")
        temporary.write_bytes(payload)
        temporary.replace(target)
        record["bundledCopy"] = "Commons standard thumbnail (up to 1920 px)"
        record["bundledWidth"] = info.get("thumbwidth", info["width"])
        record["bundledHeight"] = info.get("thumbheight", info["height"])
        records_path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
        if offset % 10 == 0 or offset == len(checked):
            print(f"Upgraded {offset}/{len(checked)}", flush=True)
        time.sleep(0.35)
