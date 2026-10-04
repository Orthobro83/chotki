#!/usr/bin/env python3
"""Stage public source/content fixtures read by the existing core test suite."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

windows = Path(__file__).resolve().parents[1]
root = windows.parent
files = {root / "checklist.md"}
for folder in ("macos/Sources", "ios/Chotki", "android/app/src/main"):
    files.update(p for p in (root / folder).rglob("*")
                 if p.is_file() and p.suffix in {".swift", ".kt", ".xml"})
for folder in ("android/core/src/main/resources/content", "core/Sources/ChotkiCore/Resources"):
    files.update(p for p in (root / folder).rglob("*") if p.is_file())
with ZipFile(windows / "test-fixtures.zip", "w", ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, str(path.relative_to(root)))
print(f"Prepared {len(files)} public test fixture files.")
