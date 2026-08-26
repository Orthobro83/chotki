#!/bin/bash
# Builds Chotki for the iOS Simulator, and says why each odd flag is there.
#
#   ./ios/build-app.sh            build
#   ./ios/build-app.sh run        build, boot the simulator, install, launch
#
set -euo pipefail
cd "$(dirname "$0")"

DEVICE="${CHOTKI_SIM_DEVICE:-iPhone 17 Pro}"

# The project is generated, never edited. project.yml is the source.
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen"; exit 1; }
xcodegen generate >/dev/null

# CODE_SIGNING_ALLOWED has to be passed here rather than set in project.yml.
#
# core ships the Psalter as a SwiftPM resource, which becomes its own bundle
# target inside the *package's* project — and that project does not inherit
# settings from ours. The bundle has no Info.plist, so codesign refuses it with
# "bundle format unrecognized" and the build dies on the one piece of shared
# content that is a file rather than a literal. On the command line the setting
# reaches every target, including that one.
xcodebuild -project Chotki.xcodeproj -scheme Chotki \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath build \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    build "$@" | grep -E "error:|warning:|BUILD" || true

APP="build/Build/Products/Debug-iphonesimulator/Chotki.app"
[ -d "$APP" ] || { echo "no app was built"; exit 1; }
echo "==> $APP"

if [ "${1:-}" = "run" ]; then
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    xcrun simctl install "$DEVICE" "$APP"
    xcrun simctl launch "$DEVICE" info.chotki.app
fi
