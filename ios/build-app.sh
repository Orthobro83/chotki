#!/bin/bash
# Builds Chotki for the iOS Simulator, and says why each odd flag is there.
#
#   ./ios/build-app.sh            build
#   ./ios/build-app.sh run        build, boot the simulator, install, launch
#
set -euo pipefail
cd "$(dirname "$0")"

DEVICE="${CHOTKI_SIM_DEVICE:-iPhone 17 Pro}"

# The development team, if there is one. Gitignored, because it is Ryan's and
# because a generated project would lose anything set in Xcode's interface.
# Without it the simulator still works; only device builds need it.
[ -f team.env ] && . ./team.env
export CHOTKI_TEAM="${CHOTKI_TEAM:-}"

#   ./ios/build-app.sh device   builds and installs on a connected iPhone
if [ "${1:-}" = "device" ]; then ACTION=device; shift; fi

#   ./ios/build-app.sh test   runs the suite instead of just building
if [ "${1:-}" = "test" ]; then ACTION=test; shift; fi

# The project is generated, never edited. project.yml is the source.
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen"; exit 1; }
xcodegen generate >/dev/null

if [ "${ACTION:-}" = "device" ]; then
    if [ -z "$CHOTKI_TEAM" ]; then
        echo "No development team. Sign Xcode into an Apple ID, then put your"
        echo "team id in ios/team.env as:  CHOTKI_TEAM=XXXXXXXXXX"
        echo "Find it in Xcode › Settings › Accounts, or with:"
        echo "  xcrun xcodebuild -showBuildSettings 2>/dev/null | grep DEVELOPMENT_TEAM"
        exit 1
    fi
    # -allowProvisioningUpdates lets Xcode register the device and mint the
    # profile itself, which is what a free Personal Team needs and what would
    # otherwise be a trip through the interface.
    xcodebuild -project Chotki.xcodeproj -scheme Chotki \
        -destination "generic/platform=iOS" \
        -derivedDataPath build -allowProvisioningUpdates \
        CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES \
        DEVELOPMENT_TEAM="$CHOTKI_TEAM" \
        build | grep -E "error:|BUILD" || true

    APP="build/Build/Products/Debug-iphoneos/Chotki.app"
    [ -d "$APP" ] || { echo "no app was built for the device"; exit 1; }
    echo "==> $APP"
    TARGET="${CHOTKI_DEVICE:-$(xcrun devicectl list devices 2>/dev/null \
        | awk '/connected/ {print $(NF-1); exit}')}"
    [ -n "$TARGET" ] || { echo "no connected device"; exit 1; }
    xcrun devicectl device install app --device "$TARGET" "$APP"
    exit 0
fi

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
    "${ACTION:-build}" | grep -E "error:|✘|BUILD|TEST" || true

[ "${ACTION:-build}" = "test" ] && exit 0

APP="build/Build/Products/Debug-iphonesimulator/Chotki.app"
[ -d "$APP" ] || { echo "no app was built"; exit 1; }
echo "==> $APP"

if [ "${1:-}" = "run" ]; then
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    xcrun simctl install "$DEVICE" "$APP"
    xcrun simctl launch "$DEVICE" info.chotki.app
fi
