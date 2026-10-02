"""Append visually reviewed Commons leads to the candidate gallery.

This adds downsized review previews only. It never changes the app's rotation.
Input records must already have a local preview and hand-chosen focal point.
"""

import argparse
import hashlib
import html
import json
import re
import shutil
from pathlib import Path
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('staged_json', type=Path)
parser.add_argument('--exclude', default='', help='comma-separated lead numbers to omit')
parser.add_argument('--batch', required=True)
args = parser.parse_args()

root = Path(__file__).resolve().parent
manifest_path = root / 'manifest.json'
manifest = json.loads(manifest_path.read_text())
known_pages = {item['source'] for item in manifest}
known_ids = {item['id'] for item in manifest}
excluded = {int(number) for number in args.exclude.split(',') if number.strip()}
staged = json.loads(args.staged_json.read_text())
added = []

for lead in staged:
    if lead['number'] in excluded: continue
    if lead['page'] in known_pages: continue
    if lead['license'] not in ('CC0', 'Public domain'):
        raise ValueError(f"Unreviewed license: {lead['title']}")
    if urlparse(lead['page']).hostname != 'commons.wikimedia.org':
        raise ValueError(f"Unexpected source page: {lead['page']}")
    if min(lead['width'], lead['height']) < 1200:
        raise ValueError(f"Preview too small: {lead['title']}")
    preview = Path(lead['preview'])
    if not preview.is_file():
        raise FileNotFoundError(preview)
    candidate_id = 'commons-' + hashlib.sha1(lead['title'].encode()).hexdigest()[:12]
    if candidate_id in known_ids:
        raise ValueError(f'Duplicate candidate ID: {candidate_id}')
    suffix = preview.suffix.lower()
    if suffix not in ('.jpg', '.jpeg', '.png'):
        raise ValueError(f'Unexpected preview type: {preview}')
    local_preview = 'previews/' + candidate_id + suffix
    shutil.copyfile(preview, root / local_preview)
    artist = html.unescape(re.sub(r'<[^>]+>', '', lead['artist'])).strip()
    item = {
        'id': candidate_id,
        'label': lead['label'],
        'source': lead['page'],
        'sourceTitle': lead['title'],
        'creator': artist,
        'license': lead['license'],
        'width': lead['width'], 'height': lead['height'],
        'focusX': lead['focusX'], 'focusY': lead['focusY'],
        'preview': local_preview,
        'crop': 'crops/' + candidate_id + '.jpg',
        'reviewBatch': args.batch,
    }
    manifest.append(item)
    added.append(item)
    known_pages.add(item['source'])
    known_ids.add(item['id'])

manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
(root / f'batch-{args.batch}.json').write_text(json.dumps(added, ensure_ascii=False, indent=2) + '\n')
print(f'Added {len(added)} review candidates; gallery now has {len(manifest)}')
