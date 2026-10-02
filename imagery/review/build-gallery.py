"""Prepare the local, offline candidate gallery from its reviewed manifest."""

import json
from pathlib import Path

root = Path(__file__).resolve().parent
items = json.loads((root / "manifest.json").read_text())
ids = [item["id"] for item in items]
if len(ids) != len(set(ids)):
    raise ValueError("Candidate IDs must be unique")
for item in items:
    if item["license"] not in ("CC0", "Public domain"):
        raise ValueError(f"Unreviewed rights: {item['id']}")
    for key in ("preview", "crop"):
        if not (root / item[key]).is_file():
            raise FileNotFoundError(root / item[key])
(root / "candidate-data.js").write_text(
    "window.CHOTKI_CANDIDATES = " + json.dumps(items, ensure_ascii=False, separators=(",", ":")) + ";\n"
)
print(f"Prepared gallery data for {len(items)} candidates")
