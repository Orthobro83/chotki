#!/bin/bash
# Installs Chotki into /Applications and starts it from there.
#
# Why this matters: the development bundle lives on an external drive, and a
# login item pointing at an unmounted volume simply fails to start. For daily
# use the app belongs on the internal disk; the repo copy is for development.
set -euo pipefail

cd "$(dirname "$0")"

DEST="/Applications/Chotki.app"

echo "==> stopping any running copy"
pkill -f "Chotki.app/Contents/MacOS/Chotki" 2>/dev/null || true

echo "==> building release"
./build-app.sh release >/dev/null

echo "==> installing to $DEST"
rm -rf "$DEST"
cp -R dist/Chotki.app "$DEST"

echo "==> verifying signature at the new location"
codesign --verify --verbose=1 "$DEST" 2>&1 | sed 's/^/    /'

echo "==> launching from /Applications"
open "$DEST"

cat <<'NOTE'

Installed.

The app re-registers its login item from wherever it is actually running, so
opening at login now points at /Applications rather than the external drive.
If a stale entry lingers, System Settings › General › Login Items will show it.
NOTE
