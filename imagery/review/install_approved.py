"""Install the user-approved review images into the Mac daily rotation.

The candidate previews are locally available, rights-checked copies. Their
source dimensions, rights, creator, and focal coordinates remain in the audit
file so each one can later be replaced by a larger copy without changing order.
"""

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "imagery/review"
DEST = ROOT / "macos/Sources/Chotki/Resources/sayings"
manifest = {item["id"]: item for item in json.loads((REVIEW / "manifest.json").read_text())}
approval = json.loads((REVIEW / "approved.json").read_text())
approved = [manifest[item_id] for item_id in approval["approved"]]
assert len(approved) == 323

order_path = DEST / "order.txt"
original_order = order_path.read_text().splitlines()[:42]
assert len(original_order) == 42

records = []
old_records_path = DEST / "approved-sources.json"
previous = {record["id"]: record for record in json.loads(old_records_path.read_text())} if old_records_path.exists() else {}
for number, item in enumerate(approved, 43):
    preview = REVIEW / item["preview"]
    if not preview.is_file():
        raise FileNotFoundError(preview)
    suffix = preview.suffix.lower()
    assert suffix in (".jpg", ".png")
    filename = f"{number:03}{suffix}"
    prior = previous.get(item["id"])
    if not (prior and prior.get("file") == filename and (DEST / filename).is_file()):
        shutil.copyfile(preview, DEST / filename)
    record = {
        "number": number, "id": item["id"], "file": filename,
        "label": item["label"], "source": item["source"],
        "creator": item["creator"], "license": item["license"],
        "sourceWidth": item["width"], "sourceHeight": item["height"],
        "focusX": item["focusX"], "focusY": item["focusY"],
        "bundledCopy": "review preview (up to 960 px)",
    }
    if prior and prior.get("file") == filename:
        for key in ("bundledCopy", "bundledWidth", "bundledHeight"):
            if key in prior:
                record[key] = prior[key]
    records.append(record)

expected = {record["file"] for record in records}
for path in DEST.iterdir():
    if path.name[:3].isdigit() and int(path.name[:3]) >= 43 and path.name not in expected:
        path.unlink()
order_path.write_text("\n".join(original_order + ["sayings/" + record["file"] for record in records]) + "\n")
(DEST / "approved-sources.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
print(f"Installed {len(records)} approved images; daily rotation now has {len(original_order) + len(records)} images")
