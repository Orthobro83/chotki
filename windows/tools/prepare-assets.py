#!/usr/bin/env python3
"""Stage the existing Mac artwork, public review fixture, and Windows fonts."""
from pathlib import Path
import hashlib
import shutil
import zipfile
import json
import re

windows = Path(__file__).resolve().parents[1]
assets = windows / 'Sources/ChotkiWindows/Assets'
assets.mkdir(parents=True, exist_ok=True)
source = windows.parent / 'macos/Sources/Chotki/Resources'
shutil.copytree(source / 'sayings', assets / 'sayings', dirs_exist_ok=True)
shutil.copytree(windows / 'Fonts', assets / 'fonts', dirs_exist_ok=True)
shutil.copytree(source / 'Preview', assets / 'Preview', dirs_exist_ok=True)
# Preserve the first 42 hand-reviewed Mac landmarks as well as approved metadata.
focus_source=(windows.parent/'macos/Sources/Chotki/SayingPanFocus.swift').read_text()
legacy=[dict(number=int(n),focusX=float(x),focusY=float(y)) for n,x,y in re.findall(r'(\d+): CGPoint\(x: ([0-9.]+), y: ([0-9.]+)\)',focus_source)]
(assets/'sayings/legacy-focus.json').write_text(json.dumps(legacy))
names = (assets / 'sayings/order.txt').read_text().splitlines()
assert len(names) == 365 and all((assets / name).is_file() for name in names)
files = sorted(p for p in assets.rglob('*') if p.is_file() and p.name != 'catalog.sha256')
digest = hashlib.sha256()
for file in files:
    digest.update(str(file.relative_to(assets)).encode())
    digest.update(hashlib.sha256(file.read_bytes()).digest())
stamp = digest.hexdigest()
old = (assets / 'catalog.sha256').read_text().strip() if (assets / 'catalog.sha256').exists() else ''
if stamp != old or not (windows / 'assets.zip').exists():
    (assets / 'catalog.sha256').write_text(stamp + '\n')
    with zipfile.ZipFile(windows / 'assets.zip', 'w', zipfile.ZIP_STORED) as archive:
        for file in files + [assets / 'catalog.sha256']:
            archive.write(file, 'Assets/' + str(file.relative_to(assets)))
print('Prepared 365 unchanged rotation images, their metadata/licenses, public calendar fixture and XCharter fonts.')
