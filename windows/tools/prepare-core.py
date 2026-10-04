#!/usr/bin/env python3
"""Stage the canonical shared Swift core inside the Windows sync root."""
from pathlib import Path
import shutil

windows = Path(__file__).resolve().parents[1]
source = windows.parent / "core"
destination = windows / "shared-core"
if not (source / "Package.swift").is_file():
    raise SystemExit("Canonical core/Package.swift is missing.")
# Replace only our generated staging folder so removed core files cannot linger.
if destination.exists():
    shutil.rmtree(destination)
shutil.copytree(source, destination, ignore=shutil.ignore_patterns(
    ".build", ".swiftpm", ".DS_Store", "__pycache__"
))
print("Prepared windows/shared-core from canonical core/.")
